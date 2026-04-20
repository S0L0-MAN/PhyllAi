import json
import os
import sys
from datetime import datetime, timezone

import cv2
import numpy as np
import torch
from PIL import Image
from pytorch_grad_cam import GradCAM
from pytorch_grad_cam.utils.image import show_cam_on_image
from pytorch_grad_cam.utils.model_targets import ClassifierOutputTarget
from torchvision import models, transforms

try:
    import ollama
except ImportError:
    ollama = None


if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")

os.environ.setdefault("USER_AGENT", "PhyllAI/1.0")


DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.path.join(
    SCRIPT_DIR,
    "models",
    "best_mobilenet_apple_background_randomized.pth",
)
CLASS_NAMES = ["Apple Scab", "Black Rot", "Cedar Rust", "Healthy"]
DISABLE_VLM_RAG = os.environ.get("PHYLLAI_DISABLE_VLM_RAG", "0").strip().lower() in {
    "1",
    "true",
    "yes",
    "on",
}
VLM_MODEL_NAME = os.environ.get("PHYLLAI_VLM_MODEL", "qwen2.5vl:3b")
VLM_FALLBACK_MODELS = [
    VLM_MODEL_NAME,
    "moondream:latest",
]

preprocess = transforms.Compose(
    [
        transforms.Resize((224, 224)),
        transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
    ]
)

_MODEL = None
_RETRIEVER = None


def load_phyllai_model():
    global _MODEL

    if _MODEL is not None:
        return _MODEL

    model = models.mobilenet_v2(weights=None)
    model.classifier[1] = torch.nn.Linear(model.last_channel, len(CLASS_NAMES))
    model.load_state_dict(
        torch.load(MODEL_PATH, map_location=DEVICE, weights_only=True)
    )
    model.to(DEVICE).eval()
    _MODEL = model
    return model


def get_retriever():
    global _RETRIEVER

    if _RETRIEVER is None:
        from rag_parser import DiagnosticRetriever

        _RETRIEVER = DiagnosticRetriever()

    return _RETRIEVER


def save_json(path, payload):
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2, ensure_ascii=False)


def save_text(path, text):
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(text)


def extract_json(text):
    # Remove markdown code blocks if present
    text = text.replace("```json", "").replace("```", "").strip()
    
    start = text.find("{")
    end = text.rfind("}") + 1
    if start == -1 or end <= start:
        return None

    try:
        return json.loads(text[start:end])
    except json.JSONDecodeError:
        return None


def optimize_image_for_vlm(image_path):
    temp_dir = os.path.join(os.path.dirname(image_path), ".vlm_cache")
    os.makedirs(temp_dir, exist_ok=True)
    optimized_path = os.path.join(
        temp_dir,
        f"{os.path.splitext(os.path.basename(image_path))[0]}_optimized.png",
    )

    with Image.open(image_path) as image:
        image.convert("RGB").resize((384, 384)).save(optimized_path)

    return optimized_path


def cleanup_temp_files(paths):
    for path in paths:
        try:
            if path and os.path.exists(path):
                os.remove(path)
                parent = os.path.dirname(path)
                if (
                    parent
                    and os.path.basename(parent) == ".vlm_cache"
                    and os.path.isdir(parent)
                    and not os.listdir(parent)
                ):
                    os.rmdir(parent)
        except OSError:
            pass


def run_vlm_json(prompt, image_paths, fallback_payload):
    if ollama is None:
        payload = dict(fallback_payload)
        payload["notes"] = (
            payload.get("notes", "")
            + " VLM unavailable because the 'ollama' Python package is not installed."
        ).strip()
        return payload

    optimized = [optimize_image_for_vlm(path) for path in image_paths if os.path.exists(path)]

    try:
        response = None
        last_error = None
        for model_name in dict.fromkeys(VLM_FALLBACK_MODELS):
            try:
                response = ollama.generate(
                    model=model_name,
                    prompt=prompt,
                    images=optimized,
                    stream=False,
                    format="json",  # Force Ollama to return JSON
                    options={"temperature": 0.1, "num_predict": 500},
                )
                break
            except Exception as error:
                last_error = error

        if response is None:
            raise last_error or RuntimeError("No VLM response was generated.")

        parsed = extract_json(response.get("response", ""))
        if parsed is None:
            fallback_payload = dict(fallback_payload)
            fallback_payload["notes"] = response.get("response", "").strip() or fallback_payload.get("notes", "")
            return fallback_payload
        return parsed
    except Exception as error:
        payload = dict(fallback_payload)
        payload["notes"] = f"{payload.get('notes', '').strip()} VLM error: {error}".strip()
        return payload
    finally:
        cleanup_temp_files(optimized)


def run_vlm_text(prompt, image_paths, fallback_text):
    if ollama is None:
        return fallback_text

    optimized = [optimize_image_for_vlm(path) for path in image_paths if os.path.exists(path)]

    try:
        response = None
        last_error = None
        for model_name in dict.fromkeys(VLM_FALLBACK_MODELS):
            try:
                response = ollama.generate(
                    model=model_name,
                    prompt=prompt,
                    images=optimized,
                    stream=False,
                    options={"temperature": 0.2, "num_predict": 700},
                )
                break
            except Exception as error:
                last_error = error

        if response is None:
            raise last_error or RuntimeError("No VLM response was generated.")

        return response.get("response", "").strip() or fallback_text
    except Exception as error:
        return f"{fallback_text}\n\nVLM error: {error}"
    finally:
        cleanup_temp_files(optimized)


def classify_and_explain(input_path, scan_folder_path):
    model = load_phyllai_model()
    original_image = Image.open(input_path).convert("RGB")
    input_tensor = preprocess(original_image).unsqueeze(0).to(DEVICE)
    image_np = np.array(original_image.resize((224, 224))) / 255.0

    with torch.no_grad():
        output = model(input_tensor)
        probabilities = torch.nn.functional.softmax(output[0], dim=0)

    top_probabilities, top_indices = torch.topk(probabilities, k=min(3, len(CLASS_NAMES)))
    predicted_index = top_indices[0].item()
    disease_name = CLASS_NAMES[predicted_index]
    confidence = top_probabilities[0].item()

    mobilenet_output = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "model_name": "MobileNetV2",
        "device": DEVICE,
        "top_prediction": disease_name,
        "confidence": confidence,
        "top_k_predictions": [
            {
                "label": CLASS_NAMES[index.item()],
                "confidence": probability.item(),
            }
            for probability, index in zip(top_probabilities, top_indices)
        ],
        "logits": [float(value) for value in output[0].detach().cpu().tolist()],
    }
    save_json(os.path.join(scan_folder_path, "mobilenet_output.json"), mobilenet_output)

    cam = GradCAM(model=model, target_layers=[model.features[-1]])
    targets = [ClassifierOutputTarget(predicted_index)]
    grayscale_cam = cam(input_tensor=input_tensor, targets=targets)[0]

    grad_cam_result = show_cam_on_image(image_np, grayscale_cam, use_rgb=True)
    cv2.imwrite(
        os.path.join(scan_folder_path, "grad_cam.png"),
        cv2.cvtColor(grad_cam_result, cv2.COLOR_RGB2BGR),
    )

    heatmap_colored = cv2.applyColorMap(
        (grayscale_cam * 255).astype(np.uint8),
        cv2.COLORMAP_JET,
    )
    cv2.imwrite(os.path.join(scan_folder_path, "heatmap.png"), heatmap_colored)

    return mobilenet_output


def generate_vlm_features(scan_folder_path, mobilenet_output):
    input_path = os.path.join(scan_folder_path, "input.jpg")
    grad_cam_path = os.path.join(scan_folder_path, "grad_cam.png")
    heatmap_path = os.path.join(scan_folder_path, "heatmap.png")
    image_paths = [input_path, grad_cam_path, heatmap_path]

    fallback = {
        "lesion_color": "unknown",
        "lesion_shape": "unknown",
        "distribution": "unknown",
        "texture": "unknown",
        "severity": "medium" if mobilenet_output["confidence"] > 0.5 else "low",
        "notes": "Fallback features generated without VLM inspection.",
    }

    prompt = f"""
You are a plant-disease vision specialist.

You are given:
- the original leaf image
- a MobileNet Grad-CAM overlay
- a raw heatmap
- MobileNet predictions: {json.dumps(mobilenet_output["top_k_predictions"], ensure_ascii=False)}

Extract ONLY visible image-grounded features. Select ONE option for each field based on the image.

Allowed values:
- lesion_color: brown, yellow, black, green, unknown
- lesion_shape: circular, angular, irregular, spotted, unknown
- distribution: scattered, clustered, marginal, uniform, unknown
- texture: dry, water-soaked, necrotic, powdery, unknown
- severity: low, medium, high

Return STRICT JSON in this exact structure without copying the allowed values list:
{{
  "lesion_color": "",
  "lesion_shape": "",
  "distribution": "",
  "texture": "",
  "severity": "",
  "notes": "2-3 sentence technical summary grounded in what is visible"
}}

Rules:
- Choose ONLY ONE value per field.
- Do NOT include multiple options.
- No explanations, only JSON.
"""

    features = run_vlm_json(prompt, image_paths, fallback)
    save_json(os.path.join(scan_folder_path, "vlm_features.json"), features)
    return features


def build_rag_query(mobilenet_output, vlm_features):
    return f"""
Disease candidate: {mobilenet_output["top_prediction"]}
Confidence: {mobilenet_output["confidence"]:.4f}
Alternative predictions: {json.dumps(mobilenet_output["top_k_predictions"], ensure_ascii=False)}

Observed features:
- Lesion color: {vlm_features.get("lesion_color", "unknown")}
- Lesion shape: {vlm_features.get("lesion_shape", "unknown")}
- Distribution: {vlm_features.get("distribution", "unknown")}
- Texture: {vlm_features.get("texture", "unknown")}
- Severity: {vlm_features.get("severity", "unknown")}
- Notes: {vlm_features.get("notes", "")}

Retrieve specialized agronomy guidance to verify the disease pattern, explain distinguishing symptoms, and suggest practical next actions.
""".strip()


def retrieve_rag_context(scan_folder_path, rag_query):
    try:
        retriever = get_retriever()
        context, sources = retriever.get_context(rag_query)
        sources = sorted(list(sources))
    except Exception as error:
        context = f"RAG retrieval unavailable: {error}"
        sources = []

    save_text(os.path.join(scan_folder_path, "rag_query.txt"), rag_query)
    save_text(os.path.join(scan_folder_path, "rag_context.txt"), context)
    save_json(
        os.path.join(scan_folder_path, "rag_sources.json"),
        {"sources": sources},
    )

    return {"query": rag_query, "context": context, "sources": sources}


def generate_feature_reasoning(scan_folder_path, mobilenet_output, vlm_features, rag_bundle):
    input_path = os.path.join(scan_folder_path, "input.jpg")
    grad_cam_path = os.path.join(scan_folder_path, "grad_cam.png")
    heatmap_path = os.path.join(scan_folder_path, "heatmap.png")
    image_paths = [input_path, grad_cam_path, heatmap_path]

    fallback = {
        "summary": (
            f"{mobilenet_output['top_prediction']} is the leading diagnosis based on the saved "
            f"MobileNet output and the extracted visual features."
        ),
        "reasoning_quality": "fallback",
        "supporting_evidence": [
            f"Top prediction confidence: {mobilenet_output['confidence']:.2%}",
            f"Visible feature summary: {vlm_features.get('notes', 'No notes')}",
        ],
        "recommendation": "Inspect neighboring leaves, monitor spread, and compare with orchard-specific disease guidance.",
        "follow_up_questions": [
            "Are similar spots appearing on fruit or nearby leaves?",
            "Has there been recent humid or rainy weather?",
        ],
    }

    specialized_prompt = f"""
You are performing feature reasoning for a plant-disease diagnosis.

Use these inputs:
1. MobileNet output:
{json.dumps(mobilenet_output, indent=2, ensure_ascii=False)}

2. Extracted visible features:
{json.dumps(vlm_features, indent=2, ensure_ascii=False)}

3. Retrieved agronomy context:
{rag_bundle["context"][:5000]}

Return STRICT JSON in this exact structure without copying the placeholder text:
{{
  "summary": "",
  "reasoning_quality": "",
  "supporting_evidence": [],
  "recommendation": "",
  "follow_up_questions": []
}}

Rules:
- Fill in the actual summary based on the evidence.
- "reasoning_quality" must be "high", "medium", or "fallback".
- Do NOT return the placeholder text.
- No explanations, only JSON.
"""

    reasoning = run_vlm_json(specialized_prompt, image_paths, fallback)
    save_text(
        os.path.join(scan_folder_path, "specialized_reasoning_prompt.txt"),
        specialized_prompt,
    )
    save_json(os.path.join(scan_folder_path, "feature_reasoning.json"), reasoning)
    return reasoning


def build_report(scan_folder_path, mobilenet_output, vlm_features, rag_bundle, reasoning):
    confidence = mobilenet_output["confidence"]
    report = {
        "status": "completed",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "disease_name": mobilenet_output["top_prediction"],
        "confidence": confidence,
        "severity": "High" if confidence >= 0.8 else "Moderate" if confidence >= 0.5 else "Low",
        "recommendation": reasoning.get(
            "recommendation",
            "Inspect additional leaves and compare symptoms against the retrieved guidance.",
        ),
        "mobilenet_output": mobilenet_output,
        "vlm_features": vlm_features,
        "rag": {
            "query": rag_bundle["query"],
            "sources": rag_bundle["sources"],
        },
        "feature_reasoning": reasoning,
        "artifacts": {
            "input_image": "input.jpg",
            "grad_cam": "grad_cam.png",
            "heatmap": "heatmap.png",
            "mobilenet_output": "mobilenet_output.json",
            "vlm_features": "vlm_features.json",
            "rag_context": "rag_context.txt",
            "feature_reasoning": "feature_reasoning.json",
        },
    }
    save_json(os.path.join(scan_folder_path, "report.json"), report)


def process_scan(scan_folder_path):
    input_path = os.path.join(scan_folder_path, "input.jpg")
    if not os.path.exists(input_path):
        raise FileNotFoundError(f"Input image not found at {input_path}")

    mobilenet_output = classify_and_explain(input_path, scan_folder_path)
    if DISABLE_VLM_RAG:
        vlm_features = {
            "lesion_color": "unknown",
            "lesion_shape": "unknown",
            "distribution": "unknown",
            "texture": "unknown",
            "severity": "unknown",
            "notes": "VLM/RAG disabled by settings; only MobileNet + Grad-CAM were executed.",
        }
        save_json(os.path.join(scan_folder_path, "vlm_features.json"), vlm_features)

        rag_bundle = {"query": "", "context": "", "sources": []}
        save_text(os.path.join(scan_folder_path, "rag_query.txt"), "")
        save_text(os.path.join(scan_folder_path, "rag_context.txt"), "")
        save_json(os.path.join(scan_folder_path, "rag_sources.json"), {"sources": []})

        reasoning = {
            "summary": (
                f"{mobilenet_output['top_prediction']} is the leading diagnosis based on the saved "
                f"MobileNet output and the Grad-CAM attribution maps."
            ),
            "reasoning_quality": "disabled",
            "supporting_evidence": [
                f"Top prediction confidence: {mobilenet_output['confidence']:.2%}",
                "VLM/RAG disabled in settings.",
            ],
            "recommendation": "Inspect neighboring leaves, monitor spread, and compare with orchard-specific guidance.",
            "follow_up_questions": [
                "Are similar spots appearing on fruit or nearby leaves?",
                "Has there been recent humid or rainy weather?",
            ],
        }
        save_json(os.path.join(scan_folder_path, "feature_reasoning.json"), reasoning)
    else:
        vlm_features = generate_vlm_features(scan_folder_path, mobilenet_output)
        rag_query = build_rag_query(mobilenet_output, vlm_features)
        rag_bundle = retrieve_rag_context(scan_folder_path, rag_query)
        reasoning = generate_feature_reasoning(
            scan_folder_path,
            mobilenet_output,
            vlm_features,
            rag_bundle,
        )
    build_report(scan_folder_path, mobilenet_output, vlm_features, rag_bundle, reasoning)

    print("COMPLETED")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit("Usage: python xai_engine.py <scan_folder_path>")

    process_scan(sys.argv[1])
