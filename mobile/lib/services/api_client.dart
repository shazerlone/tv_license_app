import 'dart:convert';
import 'package:flutter/foundation.dart';
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

  /// Invoked when the server rejects the token (401). The app wires this to
  /// sign the user out and return to login. Called at most once per burst.
  void Function()? onUnauthorized;
  bool _handling401 = false;

  /// True when the last request failed to reach the server (network/timeout).
  /// The app shows an offline banner while this is true; cleared on any success.
  final ValueNotifier<bool> offline = ValueNotifier<bool>(false);
  void _online() {
    if (offline.value) offline.value = false;
  }

  void _markOffline() {
    if (!offline.value) offline.value = true;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Uri _uri(String path) => Uri.parse('$kApiBaseUrl$path');

  /// The Render free tier sleeps after ~15 min of inactivity and takes
  /// 20–40s to cold-start. We retry transient network/timeout errors a few
  /// times with backoff so the first request after idle doesn't look like a
  /// failure. HTTP error statuses (4xx/5xx) are NOT retried — those are real.
  Future<http.Response> _send(Future<http.Response> Function() attempt) async {
    const timeout = Duration(seconds: 30);
    const backoff = [Duration(seconds: 2), Duration(seconds: 4), Duration(seconds: 8)];
    Object? lastError;
    for (var i = 0; i <= backoff.length; i++) {
      try {
        final r = await attempt().timeout(timeout);
        _online(); // reached the server
        return r;
      } on ApiException {
        rethrow; // real HTTP error — don't retry
      } catch (e) {
        lastError = e; // timeout / socket / connection — transient
        if (i < backoff.length) await Future.delayed(backoff[i]);
      }
    }
    _markOffline();
    throw lastError ?? Exception('Request failed');
  }

  Future<dynamic> get(String path) async {
    final r = await _send(() => http.get(_uri(path), headers: _headers));
    return _handle(r);
  }

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) async {
    final r = await _send(
        () => http.post(_uri(path), headers: _headers, body: jsonEncode(body ?? {})));
    return _handle(r);
  }

  Future<dynamic> patch(String path, [Map<String, dynamic>? body]) async {
    final r = await _send(
        () => http.patch(_uri(path), headers: _headers, body: jsonEncode(body ?? {})));
    return _handle(r);
  }

  Future<dynamic> delete(String path) async {
    final r = await _send(() => http.delete(_uri(path), headers: _headers));
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
    if (r.statusCode == 401 && _token != null) {
      _token = null;
      if (!_handling401) {
        _handling401 = true;
        onUnauthorized?.call();
        Future.delayed(const Duration(seconds: 2), () => _handling401 = false);
      }
    }
    // Parse our contract shape `{ error: { code, message } }` first, then fall
    // back to NestJS/Express shapes `{ statusCode, message, error }` so we never
    // surface raw router text like "Cannot POST /v1/…".
    String code = 'error';
    String message = 'Request failed (${r.statusCode})';
    if (body is Map && body['error'] is Map) {
      final err = body['error'] as Map;
      code = (err['code'] ?? code).toString();
      message = (err['message'] ?? message).toString();
    } else if (body is Map && body['message'] != null) {
      final m = body['message'];
      message = m is List ? m.join(', ') : m.toString();
      if (body['error'] is String) code = (body['error'] as String).toLowerCase().replaceAll(' ', '_');
    }
    // A 404 on a route the backend doesn't expose yet — show something human.
    if (r.statusCode == 404 && message.startsWith('Cannot ')) {
      code = 'not_available';
      message = "This feature isn't available yet.";
    }
    throw ApiException(r.statusCode, code, message);
  }
}
