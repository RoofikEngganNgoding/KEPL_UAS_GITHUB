import 'package:flutter/material.dart';

import 'api_service.dart';
import 'app_theme.dart';
import 'face_login_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  bool get _busy => _isLoading;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate() || _busy) return;

    setState(() => _isLoading = true);
    final result = await ApiService().loginResult(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      _openDashboard();
      return;
    }

    _showMessage(result.message, isError: true);
  }

  Future<void> _loginWithFace() async {
    if (_busy) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FaceLoginPage()),
    );
  }

  void _openDashboard() {
    Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.error : AppTheme.primaryDark,
      ),
    );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Email harus diisi';
    if (!email.contains('@') || !email.contains('.')) {
      return 'Format email belum benar';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _BrandHeader(),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: AppTheme.cardDecoration(),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selamat datang kembali',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Masuk untuk mengelola data sampah yang tersimpan di akunmu.',
                            style: TextStyle(
                              color: AppTheme.greyText,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Email',
                            style: TextStyle(
                              color: AppTheme.darkText,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            enabled: !_busy,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              hintText: 'nama@email.com',
                              prefixIcon: Icon(Icons.alternate_email_rounded),
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.never,
                            ),
                            validator: _validateEmail,
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Password',
                            style: TextStyle(
                              color: AppTheme.darkText,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            enabled: !_busy,
                            obscureText: !_isPasswordVisible,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => _handleLogin(),
                            decoration: InputDecoration(
                              hintText: 'Masukkan password',
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                              ),
                              suffixIcon: IconButton(
                                tooltip: _isPasswordVisible
                                    ? 'Sembunyikan password'
                                    : 'Tampilkan password',
                                onPressed: _busy
                                    ? null
                                    : () => setState(
                                        () => _isPasswordVisible =
                                            !_isPasswordVisible,
                                      ),
                                icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.never,
                            ),
                            validator: (value) => value == null || value.isEmpty
                                ? 'Password harus diisi'
                                : null,
                          ),
                          const SizedBox(height: 22),
                          ElevatedButton(
                            onPressed: _busy ? null : _handleLogin,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: _isLoading
                                  ? const SizedBox(
                                      key: ValueKey('login-loading'),
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Masuk ke Akun',
                                      key: ValueKey('login-text'),
                                    ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Row(
                              children: [
                                Expanded(child: Divider()),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    'ATAU MASUK CEPAT',
                                    style: TextStyle(
                                      color: AppTheme.greyText,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider()),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _loginWithFace,
                            icon: const Icon(Icons.face_rounded),
                            label: const Text('Pindai Wajah Otomatis'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _SecurityNote(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            gradient: AppTheme.heroGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withAlpha(55),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: const Icon(
            Icons.recycling_rounded,
            color: Colors.white,
            size: 42,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Bank Sampah Digital',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Kelola sampah dengan lebih rapi dan transparan',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.greyText, height: 1.45),
        ),
      ],
    );
  }
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration(
        color: AppTheme.lightGreen,
        bordered: true,
      ),
      child: const Row(
        children: [
          Icon(Icons.verified_user_outlined, color: AppTheme.primary),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Login wajah menggunakan kamera depan dan hanya dipakai untuk proses verifikasi akun.',
              style: TextStyle(
                color: AppTheme.primaryDark,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
