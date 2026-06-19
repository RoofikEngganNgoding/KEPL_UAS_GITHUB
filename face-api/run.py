import os
from pathlib import Path

import cv2
import numpy as np
from flask import Flask, jsonify, request
from flask_cors import CORS

BASE_DIR = Path(__file__).resolve().parent
TRAINING_DIR = BASE_DIR / "training_faces"
app = Flask(__name__)
CORS(app)

face_detector = cv2.CascadeClassifier(
    cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
)
recognizer = cv2.face.LBPHFaceRecognizer_create()

label_to_name = {}
model_ready = False
training_summary = {
    "people": 0,
    "faces": 0,
}


def detect_largest_face(gray_image):
    faces = face_detector.detectMultiScale(
        gray_image,
        scaleFactor=1.1,
        minNeighbors=5,
        minSize=(90, 90),
    )
    if len(faces) == 0:
        return None
    return max(faces, key=lambda rect: rect[2] * rect[3])


def crop_face(gray_image, rectangle):
    x, y, width, height = rectangle
    face = gray_image[y:y + height, x:x + width]
    return cv2.resize(face, (200, 200))


def train_model():
    global model_ready, label_to_name, training_summary

    face_samples = []
    labels = []
    label_to_name = {}

    if not TRAINING_DIR.exists():
        model_ready = False
        return

    people = sorted(
        directory
        for directory in TRAINING_DIR.iterdir()
        if directory.is_dir()
    )

    for label, person_directory in enumerate(people):
        person_name = person_directory.name.lower()
        label_to_name[label] = person_name

        for image_path in person_directory.iterdir():
            if image_path.suffix.lower() not in {".jpg", ".jpeg", ".png"}:
                continue

            image = cv2.imread(str(image_path))
            if image is None:
                continue

            gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
            rectangle = detect_largest_face(gray)
            if rectangle is None:
                continue

            face_samples.append(crop_face(gray, rectangle))
            labels.append(label)

    if not face_samples:
        model_ready = False
        training_summary = {"people": len(people), "faces": 0}
        return

    recognizer.train(face_samples, np.array(labels))
    model_ready = True
    training_summary = {
        "people": len(label_to_name),
        "faces": len(face_samples),
    }


@app.get("/")
def home():
    return "Face Recognition API Running"


@app.get("/health")
def health():
    status_code = 200 if model_ready else 503
    return jsonify({
        "status": "ok" if model_ready else "not_ready",
        "service": "face-recognition-api",
        "model_loaded": model_ready,
        "training": training_summary,
        "registered_faces": list(label_to_name.values()),
    }), status_code


@app.post("/recognize-face")
def recognize_face():
    if not model_ready:
        return jsonify({
            "status": "fail",
            "message": "Model wajah belum siap",
        }), 503

    if "image" not in request.files:
        return jsonify({
            "status": "fail",
            "message": "File image tidak ditemukan",
        }), 422

    image_bytes = np.frombuffer(request.files["image"].read(), np.uint8)
    image = cv2.imdecode(image_bytes, cv2.IMREAD_COLOR)
    if image is None:
        return jsonify({
            "status": "fail",
            "message": "Format gambar tidak dapat dibaca",
        }), 422

    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    rectangle = detect_largest_face(gray)
    if rectangle is None:
        return jsonify({
            "status": "fail",
            "message": "Tidak ada wajah terdeteksi",
            "faces": [],
        }), 400

    face = crop_face(gray, rectangle)
    predicted_label, distance = recognizer.predict(face)
    recognized_name = label_to_name.get(predicted_label, "unknown")

    # LBPH menghasilkan jarak: semakin kecil berarti semakin mirip.
    confidence = max(0.0, min(1.0, 1.0 - (float(distance) / 100.0)))
    if distance > 75:
        return jsonify({
            "status": "fail",
            "message": "Wajah tidak dikenali",
            "faces": [{
                "label": "Unknown",
                "confidence": confidence,
                "distance": float(distance),
            }],
        }), 401

    return jsonify({
        "status": "success",
        "face_label": recognized_name,
        "faces": [{
            "label": recognized_name,
            "confidence": confidence,
            "distance": float(distance),
        }],
    })


train_model()

if __name__ == "__main__":
    app.run(
        debug=False,
        host="0.0.0.0",
        port=int(os.getenv("FACE_PORT", "5000")),
    )
