import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';

class SampahFormPage extends StatefulWidget {
  final Map? sampah; // Null jika insert, ada isi jika update
  SampahFormPage({this.sampah});

  @override
  _SampahFormPageState createState() => _SampahFormPageState();
}

class _SampahFormPageState extends State<SampahFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  File? _image;
  final ImagePicker _picker = ImagePicker(); // Inisialisasi library

  @override
  void initState() {
    super.initState();
    if (widget.sampah != null) _controller.text = widget.sampah!['nama_sampah'];
  }

  Future<void> _pickImage() async {
    try {
      // Membuka galeri untuk memilih gambar
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality:
            50, // Mengurangi kualitas agar ukuran file tidak terlalu besar
      );

      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path); // Menyimpan file ke variabel _image
        });
      }
    } catch (e) {
      // Menampilkan pesan jika terjadi error saat membuka galeri
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal mengambil gambar: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sampah == null ? "Entry Data" : "Edit Data"),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Informasi Sampah",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: "Nama Sampah",
                  border: OutlineInputBorder(),
                ),
                // VALIDASI: Cek field tidak boleh kosong
                validator: (value) =>
                    value == null || value.isEmpty ? "Nama harus diisi" : null,
              ),
              const SizedBox(height: 20),
              const Text(
                "Foto Sampah",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: _image != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.file(_image!, fit: BoxFit.cover),
                        )
                      : const Icon(
                          Icons.add_a_photo,
                          size: 50,
                          color: Colors.grey,
                        ),
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () async {
                    // VALIDASI: Jalankan validasi form
                    if (_formKey.currentState!.validate()) {
                      bool success = await ApiService().saveSampah(
                        _controller.text,
                        _image,
                        id: widget.sampah?['id'],
                      );
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Berhasil disimpan")),
                        );
                        await Future.delayed(const Duration(milliseconds: 500));
                        if (mounted) {
                          Navigator.pop(context, true);
                        }
                      }
                    }
                  },
                  child: const Text(
                    "SIMPAN DATA",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
