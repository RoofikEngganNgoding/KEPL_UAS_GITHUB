import 'package:flutter/material.dart';

import 'app_theme.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _addressController = TextEditingController();
  bool _hidePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _submitRegister() {
    if (!_formKey.currentState!.validate()) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Data sudah siap. Silakan hubungi admin untuk aktivasi.'),
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label harus diisi';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Akun')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: AppTheme.cardDecoration(
                    color: AppTheme.lightGreen,
                  ),
                  child: const Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        child: Icon(Icons.person_add_alt_1),
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Buat akun untuk mulai menukar sampah menjadi saldo.',
                          style: TextStyle(
                            color: AppTheme.darkText,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nama lengkap',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (value) => _required(value, 'Nama lengkap'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneController,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Nomor HP',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (value) => _required(value, 'Nomor HP'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailController,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) => _required(value, 'Email'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _hidePassword,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() => _hidePassword = !_hidePassword);
                      },
                      icon: Icon(
                        _hidePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                  validator: (value) => _required(value, 'Password'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirmController,
                  obscureText: _hidePassword,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Konfirmasi password',
                    prefixIcon: Icon(Icons.lock_reset_outlined),
                  ),
                  validator: (value) {
                    final requiredMessage = _required(
                      value,
                      'Konfirmasi password',
                    );
                    if (requiredMessage != null) return requiredMessage;
                    if (value != _passwordController.text) {
                      return 'Password belum sama';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _addressController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Alamat',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  validator: (value) => _required(value, 'Alamat'),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _submitRegister,
                  child: const Text('Daftar'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Sudah punya akun'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
