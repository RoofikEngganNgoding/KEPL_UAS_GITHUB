import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiResult<T> {
  const ApiResult.success(this.data, {this.message = 'Berhasil'})
    : success = true,
      statusCode = 200,
      code = null;

  const ApiResult.failure(this.message, {this.statusCode, this.code, this.data})
    : success = false;

  final bool success;
  final T? data;
  final String message;
  final int? statusCode;
  final String? code;

  bool get unauthorized => statusCode == 401 || statusCode == 403;
}

class ServiceHealth {
  const ServiceHealth({
    required this.online,
    required this.message,
    this.checkedAt,
  });

  final bool online;
  final String message;
  final DateTime? checkedAt;
}

class FaceRecognitionResult {
  const FaceRecognitionResult({required this.label, required this.confidence});

  final String label;
  final double confidence;
}

class ApiService {
  static const String _host = String.fromEnvironment(
    'API_HOST',
    defaultValue: '192.168.1.15',
  );
  static const String _nlpPort = String.fromEnvironment(
    'NLP_PORT',
    defaultValue: '8001',
  );

  final String baseUrl = 'http://$_host:3000';
  final String baseUrlNlp = 'http://$_host:$_nlpPort';
  final String baseUrlFace = 'http://$_host:5000';

  static const Duration _shortTimeout = Duration(seconds: 2);
  static const Duration _requestTimeout = Duration(seconds: 15);

  Future<ServiceHealth> checkBackendHealth() async {
    return _checkHealth(
      Uri.parse('$baseUrl/health'),
      onlineMessage: 'Database terhubung',
      offlineMessage: 'API atau database tidak terhubung',
    );
  }

  Future<ServiceHealth> checkChatbotHealth() async {
    return _checkHealth(
      Uri.parse('$baseUrlNlp/health'),
      onlineMessage: 'Chatbot terhubung',
      offlineMessage: 'Chatbot tidak terhubung',
    );
  }

  Future<ServiceHealth> checkFaceHealth() async {
    return _checkHealth(
      Uri.parse('$baseUrlFace/health'),
      onlineMessage: 'Pengenalan wajah siap',
      offlineMessage: 'Layanan wajah tidak terhubung',
    );
  }

  Future<ServiceHealth> _checkHealth(
    Uri uri, {
    required String onlineMessage,
    required String offlineMessage,
  }) async {
    final checkedAt = DateTime.now();
    try {
      final response = await http.get(uri).timeout(_shortTimeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ServiceHealth(
          online: true,
          message: onlineMessage,
          checkedAt: checkedAt,
        );
      }
      return ServiceHealth(
        online: false,
        message: _readMessage(response, fallback: offlineMessage),
        checkedAt: checkedAt,
      );
    } on TimeoutException {
      return ServiceHealth(
        online: false,
        message: '$offlineMessage (timeout)',
        checkedAt: checkedAt,
      );
    } catch (_) {
      return ServiceHealth(
        online: false,
        message: offlineMessage,
        checkedAt: checkedAt,
      );
    }
  }

  Future<ApiResult<String>> askChatbotResult(String message) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrlNlp/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'message': message}),
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final data = _decodeMap(response.body);
        final answer = data?['response']?.toString().trim();
        if (answer != null && answer.isNotEmpty) {
          return ApiResult.success(answer);
        }
      }

      return ApiResult.failure(
        _readMessage(response, fallback: 'Chatbot belum dapat menjawab.'),
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      return const ApiResult.failure(
        'Chatbot terlalu lama merespons. Silakan coba lagi.',
        code: 'TIMEOUT',
      );
    } catch (_) {
      return const ApiResult.failure(
        'Tidak dapat terhubung ke layanan chatbot.',
        code: 'CONNECTION_FAILED',
      );
    }
  }

  Future<String> askChatbot(String message) async {
    final result = await askChatbotResult(message);
    return result.data ?? result.message;
  }

  Future<ApiResult<String>> loginResult(String email, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(_requestTimeout);

      if (response.statusCode != 200) {
        return ApiResult.failure(
          _readMessage(response, fallback: 'Email atau password belum sesuai.'),
          statusCode: response.statusCode,
        );
      }

      final data = _decodeMap(response.body);
      final token = data?['token']?.toString();
      if (token == null || token.isEmpty) {
        return const ApiResult.failure('Respons login tidak lengkap.');
      }

      await _saveSession(data!, token);
      return ApiResult.success(token);
    } on TimeoutException {
      return const ApiResult.failure(
        'API login tidak merespons. Periksa server.',
        code: 'TIMEOUT',
      );
    } catch (_) {
      return const ApiResult.failure(
        'Tidak dapat terhubung ke API Bank Sampah.',
        code: 'CONNECTION_FAILED',
      );
    }
  }

  Future<String?> login(String email, String password) async {
    final result = await loginResult(email, password);
    return result.success ? result.data : null;
  }

  Future<ApiResult<FaceRecognitionResult>> recognizeFace(XFile image) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrlFace/recognize-face'),
      );
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          await image.readAsBytes(),
          filename: image.name,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      final streamed = await request.send().timeout(_requestTimeout);
      final response = await http.Response.fromStream(streamed);
      final data = _decodeMap(response.body);

      if (response.statusCode != 200 || data?['status'] != 'success') {
        return ApiResult.failure(
          data?['message']?.toString() ?? 'Wajah belum dikenali.',
          statusCode: response.statusCode,
        );
      }

      final label = data?['face_label']?.toString() ?? 'Pengguna';
      final faces = data?['faces'];
      double confidence = 0;
      if (faces is List && faces.isNotEmpty && faces.first is Map) {
        confidence =
            double.tryParse(
              (faces.first as Map)['confidence']?.toString() ?? '',
            ) ??
            0;
      }

      return ApiResult.success(
        FaceRecognitionResult(label: label, confidence: confidence),
      );
    } on TimeoutException {
      return const ApiResult.failure(
        'Pengenalan wajah terlalu lama merespons.',
        code: 'TIMEOUT',
      );
    } catch (_) {
      return const ApiResult.failure(
        'Tidak dapat terhubung ke layanan pengenalan wajah.',
        code: 'CONNECTION_FAILED',
      );
    }
  }

  Future<ApiResult<String>> loginWithFaceLabel(String faceLabel) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/face-login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'face_label': faceLabel}),
          )
          .timeout(_requestTimeout);

      if (response.statusCode != 200) {
        return ApiResult.failure(
          _readMessage(response, fallback: 'Login wajah belum berhasil.'),
          statusCode: response.statusCode,
        );
      }

      final data = _decodeMap(response.body);
      final token = data?['token']?.toString();
      if (token == null || token.isEmpty) {
        return const ApiResult.failure('Respons login wajah tidak lengkap.');
      }

      await _saveSession(data!, token);
      return ApiResult.success(token);
    } catch (_) {
      return const ApiResult.failure(
        'Tidak dapat menghubungkan wajah dengan akun.',
      );
    }
  }

  Future<ApiResult<List<Map<String, dynamic>>>> fetchSampahResult() async {
    final token = await _token();
    if (token == null) {
      return const ApiResult.failure(
        'Sesi login tidak ditemukan.',
        statusCode: 401,
      );
    }

    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/sampah'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(_requestTimeout);

      if (response.statusCode != 200) {
        return ApiResult.failure(
          _readMessage(response, fallback: 'Data sampah belum dapat dimuat.'),
          statusCode: response.statusCode,
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['data'] is List) {
        return ApiResult.success(_mapRows(decoded['data'] as List));
      }
      if (decoded is List) return ApiResult.success(_mapRows(decoded));
      return const ApiResult.success([]);
    } on TimeoutException {
      return const ApiResult.failure(
        'API Bank Sampah terlalu lama merespons.',
        code: 'TIMEOUT',
      );
    } catch (_) {
      return const ApiResult.failure(
        'Tidak dapat terhubung ke API Bank Sampah.',
        code: 'CONNECTION_FAILED',
      );
    }
  }

  Future<List<Map<String, dynamic>>?> fetchSampah() async {
    final result = await fetchSampahResult();
    return result.success ? result.data : null;
  }

  Future<ApiResult<void>> deleteSampahResult(int id) async {
    final token = await _token();
    if (token == null) {
      return const ApiResult.failure(
        'Sesi login tidak ditemukan.',
        statusCode: 401,
      );
    }

    try {
      final response = await http
          .delete(
            Uri.parse('$baseUrl/sampah/$id'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        return ApiResult<void>.success(null, message: 'Data berhasil dihapus.');
      }
      return ApiResult.failure(
        _readMessage(response, fallback: 'Data belum berhasil dihapus.'),
        statusCode: response.statusCode,
      );
    } catch (_) {
      return const ApiResult.failure(
        'Tidak dapat terhubung ke API saat menghapus data.',
      );
    }
  }

  Future<bool> deleteSampah(int id) async {
    return (await deleteSampahResult(id)).success;
  }

  Future<ApiResult<void>> saveSampahResult(
    String nama,
    XFile? image, {
    int? id,
  }) async {
    final token = await _token();
    if (token == null) {
      return const ApiResult.failure(
        'Sesi login tidak ditemukan.',
        statusCode: 401,
      );
    }

    try {
      final request = http.MultipartRequest(
        id == null ? 'POST' : 'PUT',
        Uri.parse(id == null ? '$baseUrl/sampah' : '$baseUrl/sampah/$id'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['nama_sampah'] = nama;

      if (image != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'pic',
            await image.readAsBytes(),
            filename: image.name,
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      }

      final streamed = await request.send().timeout(_requestTimeout);
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResult<void>.success(
          null,
          message: id == null
              ? 'Data sampah berhasil ditambahkan.'
              : 'Data sampah berhasil diperbarui.',
        );
      }

      return ApiResult.failure(
        _readMessage(response, fallback: 'Data belum berhasil disimpan.'),
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      return const ApiResult.failure(
        'Proses simpan terlalu lama. Periksa koneksi API.',
        code: 'TIMEOUT',
      );
    } catch (_) {
      return const ApiResult.failure(
        'Tidak dapat terhubung ke API saat menyimpan data.',
        code: 'CONNECTION_FAILED',
      );
    }
  }

  Future<bool> saveSampah(String nama, XFile? image, {int? id}) async {
    return (await saveSampahResult(nama, image, id: id)).success;
  }

  String? imageUrlFor(Map<String, dynamic> item) {
    final directUrl = item['pic_url']?.toString();
    if (directUrl != null && directUrl.isNotEmpty) return directUrl;

    final fileName = item['pic']?.toString();
    if (fileName == null || fileName.isEmpty) return null;
    return '$baseUrl/uploads/$fileName';
  }

  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _saveSession(Map<String, dynamic> data, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    final userId = int.tryParse(data['user_id']?.toString() ?? '');
    if (userId != null) await prefs.setInt('user_id', userId);
    if (data['email'] != null) {
      await prefs.setString('email', data['email'].toString());
    }
    if (data['nama'] != null) {
      await prefs.setString('nama', data['nama'].toString());
    }
  }

  Map<String, dynamic>? _decodeMap(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
    return null;
  }

  String _readMessage(http.Response response, {required String fallback}) {
    final data = _decodeMap(response.body);
    final message = data?['message'];
    if (message != null) return message.toString();

    final detail = data?['detail'];
    if (detail is Map) {
      final nested = detail['message'] ?? detail['error'] ?? detail['status'];
      if (nested != null) return nested.toString();
    }
    if (detail is String && detail.isNotEmpty) return detail;
    return fallback;
  }

  List<Map<String, dynamic>> _mapRows(List rows) {
    return rows
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
