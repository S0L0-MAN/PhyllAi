import json
import os
import sys

from xai_engine import run_vlm_text


if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")


def load_json(path, default):
    if not os.path.exists(path):
        return default

    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def load_text(path):
    if not os.path.exists(path):
        return ""

    with open(path, "r", encoding="utf-8") as handle:
        return handle.read()


def build_fallback_answer(report, question):
    disease_name = report.get("disease_name", "the scanned sample")
    confidence = report.get("confidence", 0.0)
    recommendation = report.get("recommendation", "Review the report details.")
    return (
        f"Based on the saved scan, the leading diagnosis is {disease_name} "
        f"with {confidence:.1%} confidence.\n\n"
        f"Recommended action: {recommendation}\n\n"
        f"Your question was: {question}"
    )


def answer_question(scan_folder_path, question):
    report = load_json(os.path.join(scan_folder_path, "report.json"), {})
    mobilenet_output = load_json(
        os.path.join(scan_folder_path, "mobilenet_output.json"),
        {},
    )
    vlm_features = load_json(
        os.path.join(scan_folder_path, "vlm_features.json"),
        {},
    )
    feature_reasoning = load_json(
        os.path.join(scan_folder_path, "feature_reasoning.json"),
        {},
    )
    rag_context = load_text(os.path.join(scan_folder_path, "rag_context.txt"))

    prompt = f"""
You are the in-app PhyllAI chatbot. Answer the user's question using the saved artifacts for this single scan.
Stay grounded in the provided evidence and say when information is uncertain.

Saved diagnosis report:
{json.dumps(report, indent=2, ensure_ascii=False)}

MobileNet output:
{json.dumps(mobilenet_output, indent=2, ensure_ascii=False)}

Extracted VLM features:
{json.dumps(vlm_features, indent=2, ensure_ascii=False)}

Feature reasoning:
{json.dumps(feature_reasoning, indent=2, ensure_ascii=False)}

Retrieved RAG context:
{rag_context[:5000]}

User question:
{question}

Answer in plain language in under 180 words.
"""

    image_paths = [
        os.path.join(scan_folder_path, "input.jpg"),
        os.path.join(scan_folder_path, "grad_cam.png"),
        os.path.join(scan_folder_path, "heatmap.png"),
    ]

    fallback = build_fallback_answer(report, question)
    answer = run_vlm_text(prompt, image_paths, fallback)
    return {"answer": answer}


if __name__ == "__main__":
    if len(sys.argv) < 3:
        raise SystemExit("Usage: python chat_cli.py <scan_folder_path> <question>")

    scan_folder_path = sys.argv[1]
    question = " ".join(sys.argv[2:])
    print(json.dumps(answer_question(scan_folder_path, question), ensure_ascii=False))
