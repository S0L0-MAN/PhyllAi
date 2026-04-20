import ollama
import os
import json
from PIL import Image

# ---------------- CONFIG ----------------
MODEL_NAME = "qwen2.5vl:3b"
IMAGE_SIZE = (384, 384)


# ---------------- IMAGE PREPROCESSING ----------------
def process_image_for_vlm(image_path):
    temp_path = "vlm_input_optimized.png"

    with Image.open(image_path) as img:
        img = img.convert("RGB").resize(IMAGE_SIZE)
        img.save(temp_path)

    return temp_path


# ---------------- JSON EXTRACTOR ----------------
def extract_json(text):
    try:
        start = text.find("{")
        end = text.rfind("}") + 1
        return json.loads(text[start:end])
    except:
        return None


# ---------------- VLM ANALYSIS ----------------
def generate_vlm_analysis(image_path, model_prediction):
    optimized_path = process_image_for_vlm(image_path)

    prompt = (
    f"You are an agricultural plant disease expert.\n\n"
    f"Disease prediction: {model_prediction}\n\n"
    "Analyze the leaf image and extract ONLY visible symptoms.\n\n"

    "Allowed values:\n"
    "- lesion_color: brown, yellow, black, green\n"
    "- lesion_shape: circular, angular, irregular, spotted\n"
    "- distribution: scattered, clustered, marginal, uniform\n"
    "- texture: dry, water-soaked, necrotic, powdery\n"
    "- severity: low, medium, high\n\n"

    "Return STRICT JSON in this exact structure:\n"
    "{\n"
    "\"lesion_color\": \"\",\n"
    "\"lesion_shape\": \"\",\n"
    "\"distribution\": \"\",\n"
    "\"texture\": \"\",\n"
    "\"severity\": \"\",\n"
    "\"notes\": \"\"\n"
    "}\n\n"

    "Rules:\n"
    "- Choose ONLY ONE value per field\n"
    "- Do NOT include multiple options\n"
    "- Do NOT copy the allowed values list\n"
    "- No explanations, only JSON\n"
)

    try:
        print(f"[INFO] Running VLM: {MODEL_NAME}")

        response = ollama.generate(
            model=MODEL_NAME,
            prompt=prompt,
            images=[optimized_path],
            stream=False,
            options={
                "temperature": 0.1,
                "num_predict": 200
            }
        )

        raw_output = response['response']

        # 🔍 DEBUG OUTPUT
        print("\n[RAW VLM OUTPUT]")
        print(repr(raw_output))

        # Cleanup
        if os.path.exists(optimized_path):
            os.remove(optimized_path)

        # 🚨 Handle empty output
        if not raw_output.strip():
            print("[ERROR] Empty response from VLM")
            return {
                "lesion_color": "unknown",
                "lesion_shape": "unknown",
                "distribution": "unknown",
                "texture": "unknown",
                "severity": "unknown",
                "notes": "Empty VLM response"
            }

        # ✅ Extract JSON
        structured_output = extract_json(raw_output)

        if structured_output is None:
            print("[WARNING] JSON extraction failed, using fallback")
            structured_output = {
                "lesion_color": "unknown",
                "lesion_shape": "unknown",
                "distribution": "unknown",
                "texture": "unknown",
                "severity": "unknown",
                "notes": raw_output
            }

        return structured_output

    except Exception as e:
        return {
            "error": f"VLM Error: {e}"
        }


# ---------------- RAG QUERY BUILDER ----------------
def prepare_rag_query(vlm_data, primary_diagnosis):

    if "error" in vlm_data:
        return f"Error in VLM stage: {vlm_data['error']}"

    rag_query = f"""
--- RAG QUERY ---

Disease: {primary_diagnosis}

Observed Symptoms:
- Lesion Color: {vlm_data['lesion_color']}
- Lesion Shape: {vlm_data['lesion_shape']}
- Distribution: {vlm_data['distribution']}
- Texture: {vlm_data['texture']}
- Severity: {vlm_data['severity']}

Additional Notes:
{vlm_data['notes']}

TASK:
Retrieve precise treatment protocols matching these symptoms.
Prioritize:
1. Organic treatments
2. Early-stage intervention methods
3. Region-agnostic solutions

------------------
"""

    return rag_query


# ---------------- MAIN PIPELINE ----------------
if __name__ == "__main__":

    input_leaf = r'C:\Users\mails\Desktop\CropDiseaseDetection\xai_outputs\xai_1.png'
    prediction = "Tomato Late Blight"

    # STEP 1: VLM
    vlm_output = generate_vlm_analysis(input_leaf, prediction)

    print("\n[VLM STRUCTURED OUTPUT]")
    print(json.dumps(vlm_output, indent=2))

    # STEP 2: RAG QUERY
    final_query = prepare_rag_query(vlm_output, prediction)

    print("\n[FINAL RAG QUERY]")
    print(final_query)

    # STEP 3: SAVE
    with open("rag_query.txt", "w") as f:
        f.write(final_query)

    print("\n[INFO] RAG query saved to rag_query.txt")