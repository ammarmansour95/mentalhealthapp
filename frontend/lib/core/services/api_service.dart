import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8000/api';
  static String? _authToken;

  static Future<void> setToken(String? token) async {
    _authToken = token;
    final prefs = await SharedPreferences.getInstance();
    if (token != null) {
      await prefs.setString('auth_token', token);
    } else {
      await prefs.remove('auth_token');
    }
  }

  static Future<String?> getToken() async {
    if (_authToken != null) return _authToken;
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('auth_token');
    return _authToken;
  }

  static Future<Map<String, String>> _getHeaders() async {
    final token = await getToken();
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<dynamic> get(String endpoint, {Map<String, String>? queryParams}) async {
    final uri = Uri.parse('$baseUrl$endpoint').replace(queryParameters: queryParams);
    final headers = await _getHeaders();
    final response = await http.get(uri, headers: headers);
    return _processResponse(response);
  }

  static Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();
    final response = await http.post(uri, headers: headers, body: jsonEncode(body));
    return _processResponse(response);
  }

  static Future<dynamic> patch(String endpoint, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();
    final response = await http.patch(uri, headers: headers, body: jsonEncode(body));
    return _processResponse(response);
  }

  static Future<dynamic> patchMultipart(String endpoint, Map<String, String> fields, {String? filePath, String? fileField}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final token = await getToken();
    final request = http.MultipartRequest('PATCH', uri);

    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.fields.addAll(fields);

    if (filePath != null && fileField != null) {
      request.files.add(await http.MultipartFile.fromPath(fileField, filePath));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _processResponse(response);
  }

  static dynamic _processResponse(http.Response response) {
    final utf8Body = utf8.decode(response.bodyBytes);
    dynamic data;
    try {
      data = jsonDecode(utf8Body);
    } catch (_) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return utf8Body;
      }
      throw Exception('خطأ في الاتصال بالخادم (${response.statusCode})');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      final message = data is Map && data.containsKey('message')
          ? data['message']
          : (data is Map && data.containsKey('detail')
              ? data['detail']
              : 'Server returned error (${response.statusCode})');
      throw Exception(message);
    }
  }
}
