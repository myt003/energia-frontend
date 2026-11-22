import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ApiSyncState { connecting, synced, error }

class ApiSyncSnapshot {
  const ApiSyncSnapshot({required this.state, this.lastSyncedAt, this.message});

  final ApiSyncState state;
  final DateTime? lastSyncedAt;
  final String? message;
}

class EnergiaApiException implements Exception {
  const EnergiaApiException(this.message, {this.statusCode, this.payload});

  final String message;
  final int? statusCode;
  final Object? payload;

  @override
  String toString() => message;
}

class ApiUploadFile {
  const ApiUploadFile({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;
}

abstract interface class ApiTokenStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> remove(String key);
}

class SharedPreferencesApiTokenStore implements ApiTokenStore {
  SharedPreferencesApiTokenStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read(String key) => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) {
    return _preferences.setString(key, value);
  }

  @override
  Future<void> remove(String key) => _preferences.remove(key);
}

class InMemoryApiTokenStore implements ApiTokenStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }
}

class EnergiaApiClient {
  EnergiaApiClient({
    required String baseUrl,
    required this.username,
    required this.password,
    http.Client? httpClient,
    ApiTokenStore? tokenStore,
  }) : baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
       _httpClient = httpClient ?? http.Client(),
       _tokenStore = tokenStore ?? SharedPreferencesApiTokenStore();

  String get _accessTokenKey => 'energia.api.$username.access_token.v2';
  String get _refreshTokenKey => 'energia.api.$username.refresh_token.v2';

  final String baseUrl;
  final String username;
  final String password;
  final http.Client _httpClient;
  final ApiTokenStore _tokenStore;
  final syncStatus = ValueNotifier<ApiSyncSnapshot>(
    const ApiSyncSnapshot(state: ApiSyncState.connecting),
  );
  Future<String>? _authenticationInFlight;

  Future<Map<String, Object?>> getJson(String path) async {
    final response = await _authorizedRequest('GET', path);
    return _decodeMap(response);
  }

  Future<void> authenticate() async {
    syncStatus.value = const ApiSyncSnapshot(state: ApiSyncState.connecting);
    try {
      await _authenticate(force: true);
      _markSynced();
    } catch (error) {
      _markError(error);
      rethrow;
    }
  }

  /// Clears the cached tokens for this account so the next sign-in can be a
  /// different user or workspace role. Local offline queues remain untouched.
  Future<void> logout() async {
    _authenticationInFlight = null;
    await Future.wait([
      _tokenStore.remove(_accessTokenKey),
      _tokenStore.remove(_refreshTokenKey),
    ]);
    syncStatus.value = const ApiSyncSnapshot(state: ApiSyncState.connecting);
  }

  Future<List<Object?>> getJsonList(String path) async {
    final response = await _authorizedRequest('GET', path);
    final decoded = _decode(response);
    if (decoded is! List) {
      throw const EnergiaApiException('Expected a list from the Energia API');
    }
    return decoded.cast<Object?>();
  }

  Future<Map<String, Object?>> putJson(
    String path,
    Map<String, Object?> body,
  ) async {
    final response = await _authorizedRequest('PUT', path, body: body);
    return _decodeMap(response);
  }

  Future<Map<String, Object?>> postJson(
    String path,
    Map<String, Object?> body,
  ) async {
    final response = await _authorizedRequest('POST', path, body: body);
    return _decodeMap(response);
  }

  Future<Map<String, Object?>> patchJson(
    String path,
    Map<String, Object?> body,
  ) async {
    final response = await _authorizedRequest('PATCH', path, body: body);
    return _decodeMap(response);
  }

  Future<void> deleteJson(String path) async {
    await _authorizedRequest('DELETE', path);
  }

  Future<Uint8List> getBytes(String path) async {
    final response = await _authorizedRequest('GET', path);
    return response.bodyBytes;
  }

  Future<List<Object?>> putJsonList(
    String path,
    Map<String, Object?> body,
  ) async {
    final response = await _authorizedRequest('PUT', path, body: body);
    final decoded = _decode(response);
    if (decoded is! List) {
      throw const EnergiaApiException('Expected a list from the Energia API');
    }
    return decoded.cast<Object?>();
  }

  Future<Map<String, Object?>> postMultipart(
    String path, {
    required Map<String, String> fields,
    required String fileField,
    required String filePath,
  }) async {
    return postMultipartFiles(
      path,
      fields: fields,
      fileField: fileField,
      filePaths: [filePath],
    );
  }

  Future<Map<String, Object?>> postMultipartFiles(
    String path, {
    required Map<String, String> fields,
    required String fileField,
    required List<String> filePaths,
  }) async {
    syncStatus.value = const ApiSyncSnapshot(state: ApiSyncState.connecting);
    try {
      var token = await _accessToken();
      var response = await _sendMultipart(
        path,
        fields: fields,
        fileField: fileField,
        filePaths: filePaths,
        token: token,
      );
      if (response.statusCode == 401) {
        token = await _authenticate(force: true);
        response = await _sendMultipart(
          path,
          fields: fields,
          fileField: fileField,
          filePaths: filePaths,
          token: token,
        );
      }
      _ensureSuccess(response);
      _markSynced();
      return _decodeMap(response);
    } catch (error) {
      _markError(error);
      rethrow;
    }
  }

  Future<Map<String, Object?>> postMultipartBytes(
    String path, {
    required Map<String, String> fields,
    required String fileField,
    required List<ApiUploadFile> files,
  }) async {
    syncStatus.value = const ApiSyncSnapshot(state: ApiSyncState.connecting);
    try {
      var token = await _accessToken();
      var response = await _sendMultipartBytes(
        path,
        fields: fields,
        fileField: fileField,
        files: files,
        token: token,
      );
      if (response.statusCode == 401) {
        token = await _authenticate(force: true);
        response = await _sendMultipartBytes(
          path,
          fields: fields,
          fileField: fileField,
          files: files,
          token: token,
        );
      }
      _ensureSuccess(response);
      _markSynced();
      return _decodeMap(response);
    } catch (error) {
      _markError(error);
      rethrow;
    }
  }

  Future<http.Response> _authorizedRequest(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    syncStatus.value = const ApiSyncSnapshot(state: ApiSyncState.connecting);
    try {
      var token = await _accessToken();
      var response = await _send(method, path, body: body, token: token);
      if (response.statusCode == 401) {
        token = await _authenticate(force: true);
        response = await _send(method, path, body: body, token: token);
      }
      _ensureSuccess(response);
      _markSynced();
      return response;
    } catch (error) {
      _markError(error);
      rethrow;
    }
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
    required String token,
  }) {
    final uri = Uri.parse('$baseUrl/${path.replaceFirst(RegExp(r'^/+'), '')}');
    final headers = {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      if (body != null) 'Content-Type': 'application/json',
    };
    final encodedBody = body == null ? null : jsonEncode(body);
    final future = switch (method) {
      'GET' => _httpClient.get(uri, headers: headers),
      'PUT' => _httpClient.put(uri, headers: headers, body: encodedBody),
      'POST' => _httpClient.post(uri, headers: headers, body: encodedBody),
      'PATCH' => _httpClient.patch(uri, headers: headers, body: encodedBody),
      'DELETE' => _httpClient.delete(uri, headers: headers),
      _ => throw EnergiaApiException('Unsupported API method: $method'),
    };
    return future.timeout(const Duration(seconds: 25));
  }

  Future<http.Response> _sendMultipart(
    String path, {
    required Map<String, String> fields,
    required String fileField,
    required List<String> filePaths,
    required String token,
  }) async {
    final uri = Uri.parse('$baseUrl/${path.replaceFirst(RegExp(r'^/+'), '')}');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $token'
      ..fields.addAll(fields);
    for (final filePath in filePaths) {
      request.files.add(
        await http.MultipartFile.fromPath(
          fileField,
          filePath,
          contentType: _contentTypeForPath(filePath),
        ),
      );
    }
    final streamed = await _httpClient
        .send(request)
        .timeout(const Duration(seconds: 40));
    return http.Response.fromStream(streamed);
  }

  Future<http.Response> _sendMultipartBytes(
    String path, {
    required Map<String, String> fields,
    required String fileField,
    required List<ApiUploadFile> files,
    required String token,
  }) async {
    final uri = Uri.parse('$baseUrl/${path.replaceFirst(RegExp(r'^/+'), '')}');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $token'
      ..fields.addAll(fields);
    for (final file in files) {
      request.files.add(
        http.MultipartFile.fromBytes(
          fileField,
          file.bytes,
          filename: file.filename,
          contentType: _contentTypeForPath(file.filename),
        ),
      );
    }
    final streamed = await _httpClient
        .send(request)
        .timeout(const Duration(seconds: 60));
    return http.Response.fromStream(streamed);
  }

  Future<String> _accessToken() async {
    final token = await _tokenStore.read(_accessTokenKey);
    return token ?? _authenticate();
  }

  Future<String> _authenticate({bool force = false}) {
    if (!force && _authenticationInFlight != null) {
      return _authenticationInFlight!;
    }
    final future = _performAuthentication();
    _authenticationInFlight = future;
    return future.whenComplete(() => _authenticationInFlight = null);
  }

  Future<String> _performAuthentication() async {
    if (baseUrl.isEmpty) {
      throw const EnergiaApiException('ENERGIA_API_BASE_URL is not configured');
    }
    final uri = Uri.parse('$baseUrl/auth/token/');
    final response = await _httpClient
        .post(
          uri,
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'username': username, 'password': password}),
        )
        .timeout(const Duration(seconds: 25));
    _ensureSuccess(response);
    final data = _decodeMap(response);
    final access = data['access'];
    final refresh = data['refresh'];
    if (access is! String || refresh is! String) {
      throw const EnergiaApiException('Invalid authentication response');
    }
    await _tokenStore.write(_accessTokenKey, access);
    await _tokenStore.write(_refreshTokenKey, refresh);
    return access;
  }

  Object? _decode(http.Response response) {
    if (response.body.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw EnergiaApiException(
        'Energia API returned invalid JSON',
        statusCode: response.statusCode,
      );
    }
  }

  Map<String, Object?> _decodeMap(http.Response response) {
    final decoded = _decode(response);
    if (decoded is! Map) {
      throw EnergiaApiException(
        'Expected an object from the Energia API',
        statusCode: response.statusCode,
      );
    }
    return decoded.cast<String, Object?>();
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    Object? payload;
    try {
      payload = _decode(response);
    } catch (_) {
      payload = response.body;
    }
    throw EnergiaApiException(
      'Energia API request failed (${response.statusCode})',
      statusCode: response.statusCode,
      payload: payload,
    );
  }

  void _markSynced() {
    syncStatus.value = ApiSyncSnapshot(
      state: ApiSyncState.synced,
      lastSyncedAt: DateTime.now(),
    );
  }

  void _markError(Object error) {
    syncStatus.value = ApiSyncSnapshot(
      state: ApiSyncState.error,
      message: error.toString(),
    );
  }

  MediaType _contentTypeForPath(String path) {
    final extension = path.toLowerCase().split('.').last;
    return switch (extension) {
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      'mp4' => MediaType('video', 'mp4'),
      'mov' => MediaType('video', 'quicktime'),
      'webm' => MediaType('video', 'webm'),
      _ => MediaType('image', 'jpeg'),
    };
  }
}
