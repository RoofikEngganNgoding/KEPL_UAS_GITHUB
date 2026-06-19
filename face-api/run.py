import dlib
import cv2
import numpy as np
import joblib
import datetime

from flask import Flask, request, jsonify
from jose import JWTError, jwt

# ====================== KONFIGURASI ======================

SHAPE_PREDICTOR = "shape_predictor_68_face_landmarks.dat"
FACE_RECOG_MODEL = "dlib_face_recognition_resnet_model_v1.dat"

SECRET_KEY = "your_secret_key"

# ====================== DLIB ======================

detector = dlib.get_frontal_face_detector()

predictor = dlib.shape_predictor(
    SHAPE_PREDICTOR
)

face_rec_model = dlib.face_recognition_model_v1(
    FACE_RECOG_MODEL
)

# ====================== LOAD MODEL ======================

knn = joblib.load("knn_model.pkl")

le = joblib.load("label_encoder.pkl")

X_train = np.load("face_encodings.npy")

# ====================== FLASK ======================

app = Flask(__name__)

# ====================== USER DATABASE ======================

user_map = {
    "daveo": 2,
    "juliarti": 3,
    "angga": 4
}

# ====================== FUNCTIONS ======================

def get_face_encoding(image, face):

    shape = predictor(image, face)

    return np.array(
        face_rec_model.compute_face_descriptor(
            image,
            shape
        )
    )


def generate_token(user_id):

    payload = {
        "user_id": user_id,
        "exp": datetime.datetime.utcnow()
               + datetime.timedelta(hours=1)
    }

    token = jwt.encode(
        payload,
        SECRET_KEY,
        algorithm="HS256"
    )

    return token


def verify_token(token):

    try:

        payload = jwt.decode(
            token,
            SECRET_KEY,
            algorithms=["HS256"]
        )

        return payload["user_id"]

    except JWTError:

        return None


# ====================== HOME ======================

@app.route("/")
def home():

    return "Face Recognition API Running"

@app.route("/health")
def health():

    return jsonify({
        "status": "ready",
        "service": "face-recognition",
        "model_loaded": True
    }), 200


# ====================== LOGIN ======================

@app.route("/login", methods=["POST"])
def login():

    user_id = "123"

    if user_id:

        token = generate_token(user_id)

        return jsonify({
            "status": "success",
            "token": token
        })

    else:

        return jsonify({
            "status": "fail",
            "message": "Invalid credentials"
        }), 401


# ================= FACE RECOGNITION =================

@app.route("/recognize-face", methods=["POST"])
def recognize_face():

    try:

        # ================= AMBIL GAMBAR =================

        file = request.files["image"]

        img_array = np.asarray(
            bytearray(file.read()),
            dtype=np.uint8
        )

        image = cv2.imdecode(
            img_array,
            cv2.IMREAD_COLOR
        )

        rgb = cv2.cvtColor(
            image,
            cv2.COLOR_BGR2RGB
        )

        faces = detector(rgb)

        # ================= TIDAK ADA WAJAH =================

        if len(faces) == 0:

            return jsonify({
                "status": "fail",
                "message": "Tidak ada wajah terdeteksi",
                "faces": []
            }), 400

        results = []

        # ================= LOOP WAJAH =================

        for face in faces:

            encoding = get_face_encoding(
                rgb,
                face
            )

            encoding_2d = encoding.reshape(1, -1)

            # prediksi KNN

            pred_encoded = knn.predict(
                encoding_2d
            )[0]

            pred_name = le.inverse_transform(
                [pred_encoded]
            )[0]

            # confidence

            distances, _ = knn.kneighbors(
                encoding_2d,
                n_neighbors=3
            )

            confidence = 1 / (1 + distances[0][0])

            print("Prediksi :", pred_name)
            print("Distance :", distances[0][0])
            print("Confidence :", confidence)

            # threshold

            label = (
                pred_name
                if confidence > 0.6
                else "Unknown"
            )

            results.append({
                "label": label,
                "confidence": float(confidence)
            })

        # ================= HASIL TERBAIK =================

        best_result = results[0]

        # ================= UNKNOWN FACE =================

        if best_result["label"] == "Unknown":

            print("Wajah tidak dikenali")

            return jsonify({
                "status": "fail",
                "message": "Wajah tidak dikenali",
                "faces": results
            }), 401

        # ================= USER LOGIN =================

        recognized_name = best_result["label"].strip()

        print("Asli :", repr(recognized_name))
        print("Lower :", repr(recognized_name.lower()))

        user_id = user_map.get(
            recognized_name.lower(),
            0
        )

        print("Wajah dikenali :", recognized_name)
        print("User ID :", user_id)

        # ================= RETURN SUCCESS =================

        return jsonify({
            "status": "success",
            "face_label": recognized_name,
            "user_id": user_id,
            "faces": results
        })

    except Exception as e:

        print(e)

        return jsonify({
            "status": "fail",
            "message": str(e)
        }), 500


# ====================== RUN ======================

if __name__ == "__main__":

    app.run(
        debug=True,
        host="0.0.0.0",
        port=5000
    )