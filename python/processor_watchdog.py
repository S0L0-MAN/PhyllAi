import sys
import os
import torch
import numpy as np
import cv2
import json
from PIL import Image
from torchvision import models, transforms
from pytorch_grad_cam import GradCAM
from pytorch_grad_cam.utils.model_targets import ClassifierOutputTarget
from pytorch_grad_cam.utils.image import show_cam_on_image

# -------------------------------
# Setup & Model Loading
# -------------------------------
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
MODEL_PATH = r"C:\Users\mails\Desktop\CropDiseaseDetection\best_mobilenet_apple_background_randomized.pth"
CLASS_NAMES = ['Apple Scab', 'Black Rot', 'Cedar Rust', 'Healthy']

def load_phyllai_model():
    num_classes = 4
    model = models.mobilenet_v2(weights=None)
    model.classifier[1] = torch.nn.Linear(model.last_channel, num_classes)
    model.load_state_dict(torch.load(MODEL_PATH, map_location=DEVICE))
    model.to(DEVICE)
    model.eval()
    return model

# Global model instance to avoid reloading every time (if running as a service)
# For now, we load inside the function for the script call
model = load_phyllai_model()

# Image Transforms
preprocess = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
])

def process_scan(scan_id):
    base_dir = r'C:\Users\mails\Desktop\PhyllAI\phyllai\scans'
    folder_path = os.path.join(base_dir, scan_id)
    input_path = os.path.join(folder_path, "input.jpg")

    if not os.path.exists(input_path):
        print(f"❌ Error: {input_path} not found")
        return

    # 1. Load and Preprocess
    orig_img = Image.open(input_path).convert('RGB')
    input_tensor = preprocess(orig_img).unsqueeze(0).to(DEVICE)
    
    # Prep for visualization (numpy array 0-1)
    img_np = np.array(orig_img.resize((224, 224))) / 255.0

    # 2. Inference
    with torch.no_grad():
        output = model(input_tensor)
        probabilities = torch.nn.functional.softmax(output[0], dim=0)
        conf, class_idx = torch.max(probabilities, 0)
        
    disease_name = CLASS_NAMES[class_idx.item()]
    confidence_score = conf.item()

    # 3. Grad-CAM (Heatmap)
    target_layers = [model.features[-1]]
    cam = GradCAM(model=model, target_layers=target_layers)
    targets = [ClassifierOutputTarget(class_idx.item())]
    
    grayscale_cam = cam(input_tensor=input_tensor, targets=targets)[0]
    grad_cam_result = show_cam_on_image(img_np, grayscale_cam, use_rgb=True)
    
    # 4. Save Explainability Maps
    # Convert RGB to BGR for OpenCV saving
    cv2.imwrite(os.path.join(folder_path, "grad_cam.png"), cv2.cvtColor(grad_cam_result, cv2.COLOR_RGB2BGR))
    
    # We'll save the raw heatmap as well for your Integrated Gradients slot
    heatmap_colored = cv2.applyColorMap((grayscale_cam * 255).astype(np.uint8), cv2.COLORMAP_JET)
    cv2.imwrite(os.path.join(folder_path, "heatmap.png"), heatmap_colored)

    # 5. Save Report JSON
    report_data = {
        "disease_name": disease_name,
        "scientific_name": "Alternaria solani" if "Blight" in disease_name else "N/A",
        "confidence": confidence_score,
        "severity": "Moderate" if confidence_score > 0.8 else "Early Stage",
        "recommendation": "Maintain pruning and monitor humidity levels."
    }

    with open(os.path.join(folder_path, "report.json"), "w") as f:
        json.dump(report_data, f, indent=4)

    print(f"✅ AI Processed: {disease_name} ({confidence_score:.2%})")

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--hello":
        sid = sys.argv[2] if len(sys.argv) > 2 else "None"
        process_scan(sid)