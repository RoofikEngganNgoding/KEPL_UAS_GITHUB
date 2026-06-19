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
- Chatbot NLP: `http://192.168.1.15:8001`

Chatbot memakai model `microsoft/DialoGPT-medium`. Status di aplikasi berubah
menjadi **Terhubung** hanya setelah endpoint `/health` memastikan model selesai
dimuat. Status diperiksa ulang setiap lima detik dan dapat diperbarui langsung
dengan menarik halaman chatbot ke bawah.

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

Port chatbot juga dapat diganti:

```powershell
flutter run --dart-define=NLP_PORT=8001
```

## Fitur aktif

- Login email dan password.
- Login wajah dengan kamera depan dan pengambilan foto otomatis.
- Tambah, baca, ubah, dan hapus data sampah.
- Upload foto sampah.
- Chatbot berbasis model NLP.
- Health check nyata untuk API/database, face recognition, dan chatbot.
