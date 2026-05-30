import cv2 
import dlib 
import numpy as np 
from scipy.spatial import distance 
import os 
import time 
from sklearn.neighbors import KNeighborsClassifier 
from sklearn.preprocessing import LabelEncoder 
 
# ====================== KONFIGURASI ====================== 
 
SHAPE_PREDICTOR = "shape_predictor_68_face_landmarks.dat" 
FACE_RECOG_MODEL = "dlib_face_recognition_resnet_model_v1.dat" 
 
# Inisialisasi dlib 
detector = dlib.get_frontal_face_detector() 
predictor = dlib.shape_predictor(SHAPE_PREDICTOR) 
face_rec_model = dlib.face_recognition_model_v1(FACE_RECOG_MODEL) 
 
# Parameter Blink Detection 
EAR_THRESHOLD = 0.22 
BLINK_CONSEC_FRAMES = 3 
RECORDED_DURATION = 2  # detik 
 
# ====================== FUNGSI ====================== 
 
def eye_aspect_ratio(eye): 
    A = distance.euclidean(eye[1], eye[5]) 
    B = distance.euclidean(eye[2], eye[4]) 
    C = distance.euclidean(eye[0], eye[3]) 
 
    return (A + B) / (2.0 * C) 
 
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
 
                    print(f" ✓ {person_name} - {img_file}") 
                    break  # Ambil satu wajah per gambar 
 
    if len(encodings) == 0: 
        print("Tidak ada data training yang valid!") 
        exit() 
 
    print( 
        f"\nTotal {len(encodings)} face encodings " 
        f"dari {len(set(names))} orang telah dimuat.\n" 
    ) 
 
    return np.array(encodings), np.array(names) 
 
# ====================== MAIN PROGRAM ====================== 
 
# Load training data 
X_train, y_train = load_training_data("training_faces") 
 
# Encode labels 
le = LabelEncoder() 
y_train_encoded = le.fit_transform(y_train) 
 
# Train KNN Classifier 
knn = KNeighborsClassifier( 
    n_neighbors=3, 
    weights='distance', 
    metric='euclidean' 
) 
knn.fit(X_train, y_train_encoded) 
 
# Inisialisasi Webcam 
cap = cv2.VideoCapture(0) 
 
if not cap.isOpened(): 
    print("Tidak dapat membuka webcam") 
    exit() 
 
blink_counter = 0 
blink_detected = False 
recorded_time = 0 
 
print("Sistem siap. Tekan 'q' untuk keluar.\n") 
 
while True: 
    ret, frame = cap.read() 
 
    if not ret: 
        break 
 
    frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB) 
    faces = detector(frame_rgb) 
 
    for face in faces: 
        # Face encoding 
        encoding = get_face_encoding(frame_rgb, face) 
 
        # Prediksi dengan KNN 
        encoding_2d = encoding.reshape(1, -1) 
        pred_encoded = knn.predict(encoding_2d)[0] 
        pred_name = le.inverse_transform([pred_encoded])[0] 
 
        # Hitung confidence 
        # Semakin kecil jarak, semakin tinggi confidence 
        distances, _ = knn.kneighbors(encoding_2d, n_neighbors=3) 
        confidence = 1 / (1 + distances[0][0]) 
 
        # Threshold confidence 
        label = pred_name if confidence > 0.4 else "Unknown" 
 
        # Gambar bounding box 
        x1, y1, x2, y2 = face.left(), face.top(), face.right(), face.bottom() 
        color = (0, 255, 0) if label != "Unknown" else (0, 0, 255) 
 
        cv2.rectangle(frame, (x1, y1), (x2, y2), color, 2) 
 
        # Tampilkan nama 
        cv2.putText( 
            frame, 
            f"{label}", 
            (x1, y1 - 10), 
            cv2.FONT_HERSHEY_SIMPLEX, 
            0.9, 
            color, 
            2 
        ) 
 
        # Blink Detection hanya untuk orang yang dikenal 
        if label != "Unknown": 
            shape = predictor(frame_rgb, face) 
 
            shape_np = np.array([ 
                (shape.part(i).x, shape.part(i).y) 
                for i in range(68) 
            ]) 
 
            left_eye = shape_np[36:42] 
            right_eye = shape_np[42:48] 
 
            left_ear = eye_aspect_ratio(left_eye) 
            right_ear = eye_aspect_ratio(right_eye) 
            ear = (left_ear + right_ear) / 2.0 
 
            if ear < EAR_THRESHOLD: 
                blink_counter += 1 
 
                if blink_counter >= BLINK_CONSEC_FRAMES and not blink_detected: 
                    blink_detected = True 
                    recorded_time = time.time() 
                    print(f"✓ Attendance recorded for {label}") 
 
            else: 
                blink_counter = 0 
 
            # Tampilkan pesan "Recorded" 
            if blink_detected and (time.time() - recorded_time) < RECORDED_DURATION: 
                cv2.putText( 
                    frame, 
                    "Recorded Attendance", 
                    (x1, y2 + 30), 
                    cv2.FONT_HERSHEY_SIMPLEX, 
                    0.8, 
                    (0, 0, 255), 
                    2 
                ) 
            else: 
                blink_detected = False 
 
    cv2.imshow("Face Recognition + Blink Attendance (KNN)", frame) 
 
    if cv2.waitKey(1) & 0xFF == ord('q'): 
        break 
 
cap.release() 
cv2.destroyAllWindows() 