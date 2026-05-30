import dlib
import cv2 
import numpy as np 
from scipy.spatial import distance 
from flask import Flask, request, jsonify 
from sklearn.neighbors import KNeighborsClassifier 
from sklearn.preprocessing import LabelEncoder 
import joblib 
import numpy as np 
import os 
# ====================== KONFIGURASI ====================== 
SHAPE_PREDICTOR = "shape_predictor_68_face_landmarks.dat" 
FACE_RECOG_MODEL = "dlib_face_recognition_resnet_model_v1.dat" 
# Inisialisasi dlib 
detector = dlib.get_frontal_face_detector() 
predictor = dlib.shape_predictor(SHAPE_PREDICTOR) 
face_rec_model = dlib.face_recognition_model_v1(FACE_RECOG_MODEL) 
 
# ====================== FUNGSI ====================== 
def get_face_encoding(image, face): 
    shape = predictor(image, face) 
    return np.array(face_rec_model.compute_face_descriptor(image, shape)) 
 
# ====================== LOAD TRAINING DATA ====================== 
def load_training_data(training_folder="training_faces"): 
    encodings = [] 
    names = [] 
     
    if not os.path.exists(training_folder): 
        print(f"Folder '{training_folder}' tidak ditemukan!") 
        return np.array([]), np.array([]) 
 
    print("Memuat data training...") 
    for person_name in os.listdir(training_folder): 
        person_dir = os.path.join(training_folder, person_name) 
        if not os.path.isdir(person_dir): 
            continue 
             
        for img_file in os.listdir(person_dir): 
            if img_file.lower().endswith(('.jpg', '.jpeg', '.png')): 
                img_path = os.path.join(person_dir, img_file) 
                image = cv2.imread(img_path) 
                if image is None: 
                    continue 
                     
                rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB) 
                faces = detector(rgb) 
                 
                for face in faces: 
                    encoding = get_face_encoding(rgb, face) 
                    encodings.append(encoding) 
                    names.append(person_name) 
                    print(f"   ✓ {person_name} - {img_file}") 
                    break  # Ambil satu wajah per gambar 
     
    if len(encodings) == 0: 
        print("Tidak ada data training yang valid!") 
        exit() 
     
    print(f"\nTotal {len(encodings)} face encodings dari {len(set(names))} orang telah dimuat.\n") 
    return np.array(encodings), np.array(names) 
 
# ====================== FLASK API ====================== 
 
app = Flask(__name__) 
 
# Load training data 
X_train, y_train = load_training_data("training_faces") 
 
# Encode labels 
le = LabelEncoder() 
y_train_encoded = le.fit_transform(y_train) 
 
# Train KNN Classifier 
knn = KNeighborsClassifier(n_neighbors=3, weights='distance', metric='euclidean') 
knn.fit(X_train, y_train_encoded) 
 
# Simpan model KNN dan LabelEncoder ke file 
joblib.dump(knn, 'knn_model.pkl') 
joblib.dump(le, 'label_encoder.pkl') 
 
# Simpan face encodings ke file (jika perlu) 
np.save('face_encodings.npy', X_train) 

