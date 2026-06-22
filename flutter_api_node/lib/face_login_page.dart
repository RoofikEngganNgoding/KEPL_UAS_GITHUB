import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'api_service.dart';
import 'app_theme.dart';

class FaceLoginPage extends StatefulWidget {
  const FaceLoginPage({super.key});

  @override
  State<FaceLoginPage> createState() => _FaceLoginPageState();
}

class _FaceLoginPageState extends State<FaceLoginPage>
    with WidgetsBindingObserver {
  final _apiService = ApiService();

  CameraController? _cameraController;
  Timer? _countdownTimer;
  int _countdown = 3;
  int _attempt = 0;
  bool _initializing = true;
  bool _processing = false;
  bool _canRetry = false;
  String _status = 'Menyiapkan kamera depan...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _countdownTimer?.cancel();
      _cameraController?.dispose();
      _cameraController = null;
    } else if (state == AppLifecycleState.resumed &&
        _cameraController == null) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (mounted) {
      setState(() {
        _initializing = true;
        _canRetry = false;
        _status = 'Memeriksa layanan pengenalan wajah...';
      });
    }

    final health = await _apiService.checkFaceHealth();
    if (!health.online) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _canRetry = true;
        _status = health.message;
      });
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('NO_CAMERA', 'Kamera tidak tersedia.');
      }

      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      await _cameraController?.dispose();
      final controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _cameraController = controller;
      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);

      if (!mounted) return;
      setState(() {
        _initializing = false;
        _status = 'Posisikan wajah di dalam bingkai.';
      });
      _startCountdown();
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _canRetry = true;
        _status = error.code == 'CameraAccessDenied'
            ? 'Izin kamera ditolak. Aktifkan izin kamera di pengaturan.'
            : error.description ?? 'Kamera belum dapat dibuka.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _canRetry = true;
        _status = 'Kamera depan belum dapat dibuka.';
      });
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _countdown = 3;
      _canRetry = false;
      _processing = false;
      _status = 'Tatap kamera dan jangan bergerak.';
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_countdown <= 1) {
        timer.cancel();
        setState(() => _countdown = 0);
        _captureAndRecognize();
      } else {
        setState(() => _countdown--);
      }
    });
  }
  Future<void> _captureAndRecognize() async {
  final controller = _cameraController;

  if (controller == null ||
      !controller.value.isInitialized ||
      controller.value.isTakingPicture ||
      _processing) {
    return;
  }

  setState(() {
    _processing = true;
    _attempt++;
    _status = 'Mengambil gambar otomatis...';
  });

  try {
    print("Ambil foto...");

    final image = await controller.takePicture();

    print("Foto berhasil diambil");
    print(image.path);

    if (!mounted) return;

    setState(() {
      _status = 'Mengenali wajah...';
    });

    print("Kirim ke API...");

    final recognition = await _apiService.recognizeFace(image);

    print("Response diterima");
    print("Success : ${recognition.success}");
    print("Message : ${recognition.message}");

    if (!mounted) return;

    if (!recognition.success || recognition.data == null) {
      _handleFailedAttempt(recognition.message);
      return;
    }

    setState(() {
      _status =
          'Wajah ${recognition.data!.label} dikenali. Masuk ke akun...';
    });

    final login = await _apiService.loginWithFaceLabel(
      recognition.data!.label,
    );

    print("Login wajah : ${login.success}");
    print("Pesan login : ${login.message}");

    if (!mounted) return;

    if (!login.success) {
      _handleFailedAttempt(login.message);
      return;
    }

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/dashboard',
      (route) => false,
    );
  } catch (e) {
    print("====================");
    print("ERROR FACE LOGIN");
    print(e);
    print("====================");

    if (!mounted) return;

    _handleFailedAttempt(e.toString());
  }
}
  
  void _handleFailedAttempt(String message) {
    if (!mounted) return;

    if (_attempt < 3) {
      setState(() {
        _processing = false;
        _status = '$message Mencoba kembali...';
      });
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted) _startCountdown();
      });
      return;
    }

    setState(() {
      _processing = false;
      _canRetry = true;
      _status = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;
    final cameraReady =
        controller != null && controller.value.isInitialized && !_initializing;

    return Scaffold(
      backgroundColor: const Color(0xFF071E18),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text(
          'Login Wajah Otomatis',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (cameraReady)
                            CameraPreview(controller)
                          else
                            Container(
                              color: const Color(0xFF12362C),
                              child: Center(
                                child: _initializing
                                    ? const CircularProgressIndicator(
                                        color: Colors.white,
                                      )
                                    : const Icon(
                                        Icons.videocam_off_outlined,
                                        color: Colors.white70,
                                        size: 52,
                                      ),
                              ),
                            ),
                          const _FaceGuideOverlay(),
                          if (cameraReady && !_processing && _countdown > 0)
                            Center(
                              child: Container(
                                width: 74,
                                height: 74,
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(135),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '$_countdown',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 34,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (_processing)
                            Container(
                              color: Colors.black.withAlpha(95),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _status,
                  key: ValueKey(_status),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (_canRetry)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _initializeCamera,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Coba Lagi'),
                  ),
                )
              else
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.camera_alt_outlined,
                      color: AppTheme.softGreen,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Foto diambil otomatis, tanpa tombol shutter',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaceGuideOverlay extends StatelessWidget {
  const _FaceGuideOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: CustomPaint(painter: _FaceGuidePainter()));
  }
}

class _FaceGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = Colors.black.withAlpha(70);
    final guide = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.44),
      width: size.width * 0.68,
      height: size.height * 0.58,
    );
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(guide);
    canvas.drawPath(path, overlayPaint);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = AppTheme.softGreen;
    canvas.drawOval(guide, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
