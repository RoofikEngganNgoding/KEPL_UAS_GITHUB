# Bank Sampah Digital

Aplikasi Flutter untuk login akun/login wajah, CRUD data sampah, dan chatbot NLP.

## Menjalankan layanan

Jalankan dari root repository menggunakan PowerShell:

```powershell
.\start_services.ps1
```

Layanan yang digunakan:

- API dan database: `http://192.168.1.15:3000`
- Face recognition: `http://192.168.1.15:5000`
- Chatbot NLP melalui proxy API: `http://192.168.1.15:3000/nlp`

Chatbot memakai model `microsoft/DialoGPT-medium`. Status di aplikasi berubah
menjadi **Terhubung** hanya setelah endpoint `/health` memastikan model selesai
dimuat. Status diperiksa ulang setiap lima detik dan dapat diperbarui langsung
dengan menarik halaman chatbot ke bawah.

Chatbot boleh tetap dijalankan hanya pada localhost. API Node akan menemukan
service NLP yang valid pada port `8001` atau `8000`, kemudian meneruskannya ke
ponsel:

```powershell
cd nlp-api
C:\Users\daven\anaconda3\python.exe -m uvicorn main:app --host 127.0.0.1 --port 8001
```

Jika port `8000` sudah digunakan aplikasi lain, gunakan `8001`. Status di
Flutter berasal dari `http://192.168.1.15:3000/nlp/health`, sehingga health
check dan pengiriman pesan selalu melewati jalur yang sama.

## Menjalankan aplikasi

```powershell
cd flutter_api_node
flutter pub get
flutter run
```

Jika alamat IP komputer berubah:

```powershell
flutter run --dart-define=API_HOST=ALAMAT_IP
```

## Fitur aktif

- Login email dan password.
- Login wajah dengan kamera depan dan pengambilan foto otomatis.
- Tambah, baca, ubah, dan hapus data sampah.
- Upload foto sampah.
- Chatbot berbasis model NLP.
- Health check nyata untuk API/database, face recognition, dan chatbot.
