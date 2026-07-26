import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class ApiException implements Exception {
  final int status;
  final String code;
  final String message;
  ApiException(this.status, this.code, this.message);
  @override
  String toString() => 'ApiException($status, $code): $message';
}

/// Thin REST client for the Millimore backend. Holds the JWT in memory.
/// All calls follow docs/BACKEND_CONTRACT.md.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  String? _token;
  String? get token => _token;
  void setToken(String? t) => _token = t;
  void clear() => _token = null;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Uri _uri(String path) => Uri.parse('$kApiBaseUrl$path');

  Future<dynamic> get(String path) async {
    final r = await http.get(_uri(path), headers: _headers).timeout(const Duration(seconds: 20));
    return _handle(r);
  }

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) async {
    final r = await http
        .post(_uri(path), headers: _headers, body: jsonEncode(body ?? {}))
        .timeout(const Duration(seconds: 20));
    return _handle(r);
  }

  Future<dynamic> patch(String path, [Map<String, dynamic>? body]) async {
    final r = await http
        .patch(_uri(path), headers: _headers, body: jsonEncode(body ?? {}))
        .timeout(const Duration(seconds: 20));
    return _handle(r);
  }

  Future<dynamic> delete(String path) async {
    final r = await http.delete(_uri(path), headers: _headers).timeout(const Duration(seconds: 20));
    return _handle(r);
  }

  dynamic _handle(http.Response r) {
    final ok = r.statusCode >= 200 && r.statusCode < 300;
    dynamic body;
    if (r.body.isNotEmpty) {
      try {
        body = jsonDecode(r.body);
      } catch (_) {
        body = null;
      }
    }
    if (ok) return body;
    final err = (body is Map && body['error'] is Map) ? body['error'] as Map : const {};
    throw ApiException(
      r.statusCode,
      (err['code'] ?? 'error').toString(),
      (err['message'] ?? 'Request failed (${r.statusCode})').toString(),
    );
  }
}
