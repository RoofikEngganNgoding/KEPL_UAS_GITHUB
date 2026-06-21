# KEPL UAS

## Teknologi yang Digunakan

* Flutter
* Node.js + Express
* MySQL
* Face Recognition (Python + Dlib)
* NLP Chatbot (FastAPI + Transformers)
* JWT Authentication

---

## Struktur Project

```text
flutter_api_node/   -> Aplikasi Flutter
bank_sampah_api/    -> Backend Node.js
face-api/           -> Service Face Recognition
nlp-api/            -> Service NLP Chatbot
```

---

# 1. Persiapan Backend Node.js

Masuk ke folder backend:

```bash
cd bank_sampah_api
```

Install dependency:

```bash
npm install
```

Jalankan server:

```bash
node app.js
```

Server berjalan pada:

```text
http://localhost:3000
```

---

# 2. Persiapan Face Recognition

Masuk ke folder:

```bash
cd face-api
```

## Membuat Environment Anaconda

```bash
conda create -n faceenv python=3.10
conda activate faceenv
```

## Install Library

Install dlib:

```bash
conda install -c conda-forge dlib
```

Install library lainnya:

```bash
pip install opencv-python
pip install numpy
pip install scipy
pip install scikit-learn
pip install flask
pip install joblib
pip install python-jose
```

Atau sekaligus:

```bash
pip install opencv-python numpy scipy scikit-learn flask joblib python-jose
```

## Training Dataset

Jalankan:

```bash
python train.py
```

File yang akan dihasilkan:

```text
knn_model.pkl
label_encoder.pkl
face_encodings.npy
```

## Menjalankan Face Recognition API

```bash
python run.py
```

Server berjalan pada:

```text
http://localhost:5000
```

---

# 3. Persiapan NLP Chatbot

Masuk ke folder:

```bash
cd nlp-api
```

## Membuat Environment Anaconda

```bash
conda create -n nlp_kepl python=3.10
conda activate nlp_kepl
```

## Install Library

```bash
pip install fastapi
pip install uvicorn
pip install transformers
pip install torch
pip install sentence-transformers
pip install fuzzywuzzy
pip install python-Levenshtein
```

Atau sekaligus:

```bash
pip install fastapi uvicorn transformers torch sentence-transformers fuzzywuzzy python-Levenshtein
```

## Menjalankan NLP API

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Swagger Documentation:

```text
http://127.0.0.1:8000/docs
```

---

# 4. Menjalankan Flutter

Masuk ke folder Flutter:

```bash
cd flutter_api_node
```

Install dependency:

```bash
flutter pub get
```

Jalankan aplikasi:

```bash
flutter run
```

---

# Urutan Menjalankan Project

1. Jalankan MySQL / XAMPP
2. Jalankan Backend Node.js

```bash
node app.js
```

3. Jalankan Face Recognition API

```bash
conda activate faceenv
python run.py
```

4. Jalankan NLP API

```bash
conda activate nlp_kepl
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

5. Jalankan Flutter

```bash
flutter run
```

---

# Fitur Aplikasi

* Login Email & Password (JWT)
* Login Face Recognition
* CRUD Data Sampah
* Upload Gambar Sampah
* Multi User
* NLP Chatbot
* Dashboard Berdasarkan User Login
* Integrasi Flutter + Node.js + Face Recognition + NLP

```
```
