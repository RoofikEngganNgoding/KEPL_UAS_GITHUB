import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {

  final String baseUrl = "http://192.168.1.14:3000";
  final String baseUrlNlp = "http://192.168.1.14:8000";
  final String baseUrlFace = "http://192.168.1.14:5000";

  // ================= CHATBOT =================

  Future<String> askChatbot(String message) async {

    try {

      final response = await http.post(
        Uri.parse('$baseUrlNlp/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': message}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'];
      } else {
        return "Maaf, server sedang sibuk";
      }
    } catch (e) {
      return "Gagal terhubung ke chatbot";
    }
  }

  // ================= LOGIN =================

  Future<String?> login(
    String email,
    String password,
  ) async {

    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password
      }),
    );

    print(response.statusCode);
    print(response.body);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['token'];
      final userId = data['user_id'];
      final prefs =
          await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      await prefs.setInt('user_id', userId);
      return token;
    }
    return null;
  }

  // ================= GET SAMPAH =================

  Future<List> fetchSampah() async {

    final prefs =
        await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final response = await http.get(
      Uri.parse('$baseUrl/sampah'),
      headers: {
        'Authorization': 'Bearer $token'
      },
    );

    print(response.statusCode);
    print(response.body);
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      // jika response berbentuk:
      // { success: true, data: [...] }
      if (data is Map &&
          data.containsKey('data')) {
        return data['data'];
      }
      // jika response langsung list
      if (data is List) {
        return data;
      }
    }
    return [];
  }

  // ================= DELETE SAMPAH =================

  Future<void> deleteSampah(int id) async {

    final prefs =
        await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    await http.delete(
      Uri.parse('$baseUrl/sampah/$id'),
      headers: {
        'Authorization': 'Bearer $token'
      },
    );
  }

  // ================= SAVE SAMPAH =================

  Future<bool> saveSampah(
    String nama,
    File? image, {
    int? id,
  }) async {
    final prefs =
        await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    var request = http.MultipartRequest(
      id == null ? 'POST' : 'PUT',
      Uri.parse(
        id == null
          ? '$baseUrl/sampah'
          : '$baseUrl/sampah/$id',
      ),
    );

    request.headers['Authorization'] =
        'Bearer $token';
    request.fields['nama_sampah'] = nama;
    if (image != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'pic',
          image.path,
          contentType:
              MediaType('image', 'jpeg'),
        ),
      );
    }
    var streamedResponse =
        await request.send();
    var response =
        await http.Response.fromStream(
          streamedResponse,
        );
    print(response.statusCode);
    print(response.body);
    return response.statusCode == 201
        || response.statusCode == 200;
  }
}