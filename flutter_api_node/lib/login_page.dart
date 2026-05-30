import 'package:flutter/material.dart';
import 'api_service.dart';

// ================= FACE RECOGNITION =================
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
// ====================================================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  // ================= FACE RECOGNITION =================
  File? imageFile;
  final picker = ImagePicker();
  bool loadingFace = false;
  // ====================================================
  // ================= LOGIN EMAIL =================
  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final token = await ApiService().login(
        emailController.text.trim(),
        passwordController.text,
      );

      setState(() => _isLoading = false);

      if (token != null) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Email atau Password salah!"),

              backgroundColor: Colors.redAccent,

              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  // ====================================================

  // ================= FACE RECOGNITION =================

  Future loginWithFace() async {
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked == null) return;
    setState(() {
      imageFile = File(picked.path);
      loadingFace = true;
    });

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse("${ApiService().baseUrlFace}/recognize-face"), // api
      );
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile!.path),
      );
      var response = await request.send();

      var responseData = await response.stream.bytesToString();

      var data = jsonDecode(responseData);

      print(data);

      if (data["status"] == "success") {
        final faceLoginResponse = await http.post(
          Uri.parse('${ApiService().baseUrl}/face-login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'user_id': data['user_id']}),
        );

        final loginData = jsonDecode(faceLoginResponse.body);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', loginData['token']);
        await prefs.setInt('user_id', loginData['user_id']);

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
      }
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Gagal connect Face API")));
    }
    setState(() {
      loadingFace = false;
    });
  }

  // ====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,

        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2E7D32), Color(0xFF81C784)],
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 80),
            // ================= HEADER =================
            const Icon(Icons.recycling, size: 80, color: Colors.white),
            const SizedBox(height: 10),
            const Text(
              "BANK SAMPAH",
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),

            const Text(
              "Kelola sampah jadi berkah",

              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),

            const SizedBox(height: 40),

            // ==========================================
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 40,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                ),

                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Selamat Datang",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),
                        const Text(
                          "Silakan login untuk melanjutkan",
                          style: TextStyle(color: Colors.grey),
                        ),

                        const SizedBox(height: 30),

                        // ================= EMAIL =================
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: "Email",
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          validator: (value) => value!.isEmpty
                              ? "Email tidak boleh kosong"
                              : null,
                        ),

                        const SizedBox(height: 20),

                        // ================= PASSWORD =================
                        TextFormField(
                          controller: passwordController,
                          obscureText: !_isPasswordVisible,
                          decoration: InputDecoration(
                            labelText: "Password",
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () => setState(
                                () => _isPasswordVisible = !_isPasswordVisible,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          validator: (value) => value!.isEmpty
                              ? "Password tidak boleh kosong"
                              : null,
                        ),

                        const SizedBox(height: 40),
                        // ================= LOGIN BUTTON =================
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: 5,
                            ),

                            onPressed: _isLoading ? null : _handleLogin,
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text(
                                    "MASUK",

                                    style: TextStyle(
                                      color: Colors.white,

                                      fontSize: 18,

                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 20),
                        // ================= FACE LOGIN =================
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            onPressed: loadingFace ? null : loginWithFace,
                            icon: const Icon(Icons.face, color: Colors.white),
                            label: loadingFace
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text(
                                    "LOGIN DENGAN WAJAH",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        // ==============================================
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
