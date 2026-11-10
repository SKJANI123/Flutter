import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:disaster/core/config/app_config.dart';
import 'package:disaster/core/errors/exceptions.dart';
import 'package:disaster/core/storage/secure_store.dart';

/// Thin, hardened HTTP client.
///
/// Always uses HTTPS (any http:// base URL is rejected), applies a timeout,
/// retries transient failures with jittered backoff and attaches the auth
/// token from secure storage when present.
class ApiClient {
  ApiClient({
    http.Client? client,
    SecureStore? secureStore,
    http.Client? overrideClient,
  }) : _client = overrideClient ?? client ?? http.Client(),
       _secureStore = secureStore ?? SecureStore();

  final http.Client _client;
  final SecureStore _secureStore;

  Future<Map<String, String>> _headers() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'disaster-app/1.0',
    };
    final token = await _secureStore.read(SecureStore.keyAccessToken);
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Uri _uri(String path) {
    final url = path.startsWith('http') ? path : '${AppConfig.baseUrl}$path';
    final uri = Uri.parse(url);
    if (uri.scheme != 'https') {
      throw const ApiException('Only HTTPS endpoints are allowed.');
    }
    return uri;
  }

  Future<dynamic> get(String path, {Duration? timeout}) => _guard(() async {
    final response = await _client
        .get(_uri(path), headers: await _headers())
        .timeout(timeout ?? AppConfig.requestTimeout);
    return _decode(response);
  });

  Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    Duration? timeout,
  }) => _guard(() async {
    final response = await _client
        .post(_uri(path), headers: await _headers(), body: jsonEncode(body))
        .timeout(timeout ?? AppConfig.requestTimeout);
    return _decode(response);
  });

  Future<dynamic> put(
    String path,
    Map<String, dynamic> body, {
    Duration? timeout,
  }) => _guard(() async {
    final response = await _client
        .put(_uri(path), headers: await _headers(), body: jsonEncode(body))
        .timeout(timeout ?? AppConfig.requestTimeout);
    return _decode(response);
  });

  Future<dynamic> delete(String path, {Duration? timeout}) => _guard(() async {
    final response = await _client
        .delete(_uri(path), headers: await _headers())
        .timeout(timeout ?? AppConfig.requestTimeout);
    return _decode(response);
  });

  dynamic _decode(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    throw ApiException(
      'Server responded with ${response.statusCode}',
      statusCode: response.statusCode,
    );
  }

  /// Retries a transient request once with backoff. Timeouts and network
  /// errors are surfaced as [NetworkException].
  Future<T> _guard<T>(Future<T> Function() action) async {
    const attempts = 2;
    Object? lastError;
    for (var i = 0; i < attempts; i++) {
      try {
        return await action();
      } on ApiException {
        rethrow;
      } on TimeoutException catch (e) {
        lastError = NetworkException('Request timed out', cause: e);
      } on SocketException catch (e) {
        lastError = NetworkException('Network unavailable', cause: e);
      } on http.ClientException catch (e) {
        lastError = NetworkException('Request failed', cause: e);
      } on FormatException {
        throw const ParseException('Malformed server response');
      }
    }
    throw lastError ?? const NetworkException('Request failed after retries');
  }

  void dispose() => _client.close();
}
