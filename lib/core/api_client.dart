import 'dart:async';

import 'package:dio/dio.dart';

import 'config.dart';
import 'token_store.dart';

/// An error carrying the message the API meant for the user.
///
/// The backend answers in Lao and English (`ບໍ່ພົບການຈອງ · Booking not found`),
/// so showing `error.message` is showing something the partner can act on —
/// far better than a generic "something went wrong".
class ApiException implements Exception {
  ApiException(this.statusCode, this.message, {this.body});

  final int? statusCode;
  final String message;
  final Object? body;

  bool get isUnauthorised => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;

  @override
  String toString() => message;
}

/// Called when the session is gone for good, so the app can drop to /login.
typedef SessionLostCallback = void Function();

/// The HTTP layer.
///
/// Mirrors `webadmin/src/lib/api.ts` on purpose: access tokens live 15 minutes,
/// so a working session will meet 401s during normal use. Rather than throwing
/// the partner back to the login screen mid-task, a 401 triggers one refresh
/// and the original request is replayed.
///
/// **The single-flight refresh is not an optimisation.** The backend rotates
/// refresh tokens and treats a reused one as a stolen credential — it revokes
/// every session for that partner. A screen that fires five requests at once
/// and lets each start its own refresh would hand the backend four reused
/// tokens and log the user out of everything. All concurrent 401s therefore
/// await the same Future.
class ApiClient {
  ApiClient({required this.tokens, Dio? dio, String? baseUrl})
      : _dio = dio ?? Dio() {
    _dio.options = _dio.options.copyWith(
      baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      contentType: Headers.jsonContentType,
      // Statuses are inspected here rather than thrown by Dio, so a 401 can be
      // retried and everything else turned into an ApiException with its
      // message intact.
      validateStatus: (_) => true,
    );
  }

  final TokenStore tokens;
  final Dio _dio;

  SessionLostCallback? onSessionLost;

  Future<bool>? _refreshInFlight;

  Dio get raw => _dio;

  Future<T> get<T>(String path, {Map<String, dynamic>? query}) =>
      _send<T>('GET', path, query: query);

  Future<T> post<T>(String path, {Object? body, Map<String, dynamic>? query}) =>
      _send<T>('POST', path, body: body, query: query);

  Future<T> patch<T>(String path, {Object? body}) =>
      _send<T>('PATCH', path, body: body);

  Future<T> delete<T>(String path) => _send<T>('DELETE', path);

  /// Multipart upload for property and room photos. The API expects the file
  /// under the field name `file`.
  Future<T> upload<T>(String path, {required MultipartFile file}) =>
      _send<T>('POST', path, body: FormData.fromMap({'file': file}));

  Future<T> _send<T>(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool anonymous = false,
    bool isRetry = false,
  }) async {
    final Response<dynamic> response;
    try {
      response = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(
          method: method,
          headers: {
            if (!anonymous && tokens.accessToken != null)
              'Authorization': 'Bearer ${tokens.accessToken}',
          },
        ),
      );
    } on DioException catch (e) {
      // validateStatus swallows HTTP statuses, so anything Dio still throws is
      // a transport failure: no route to the host, DNS, TLS, or a timeout.
      throw ApiException(null, _transportMessage(e));
    }

    if (response.statusCode == 401 && !anonymous && !isRetry && tokens.hasSession) {
      final renewed = await _refreshOnce();
      if (renewed) {
        return _send<T>(method, path, body: body, query: query, isRetry: true);
      }
      await tokens.clear();
      onSessionLost?.call();
      throw ApiException(401, 'ເຊສຊັນໝົດອາຍຸ · Session expired, please sign in again');
    }

    if (response.statusCode == 401 && !anonymous) {
      await tokens.clear();
      onSessionLost?.call();
    }

    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw ApiException(status, _messageFrom(response.data, status), body: response.data);
    }

    return response.data as T;
  }

  /// One refresh at a time, shared by every caller that arrives while it runs.
  Future<bool> _refreshOnce() {
    return _refreshInFlight ??= _runRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<bool> _runRefresh() async {
    final refresh = tokens.refreshToken;
    if (refresh == null || refresh.isEmpty) return false;

    final Response<dynamic> response;
    try {
      response = await _dio.post<dynamic>(
        '/auth/refresh',
        data: {'refreshToken': refresh},
        options: Options(headers: const {}),
      );
    } on DioException {
      // The network is down, not the session. Report failure without wiping the
      // tokens — they may well still be good once there is a connection again.
      return false;
    }

    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) return false;

    final data = response.data;
    if (data is! Map || data['accessToken'] is! String || data['refreshToken'] is! String) {
      return false;
    }

    await tokens.save(
      access: data['accessToken'] as String,
      refresh: data['refreshToken'] as String,
    );
    return true;
  }

  // ── auth, which must not carry or renew a token ──────────────────────────

  /// Signs in.
  ///
  /// There is one login endpoint for the whole platform — guests, partners and
  /// staff all post here — so the role has to be checked afterwards. A guest's
  /// password is perfectly valid and would return real tokens; they simply open
  /// nothing in this app, and saying so is kinder than a screen of 403s.
  Future<Map<String, dynamic>> partnerLogin(String email, String password) async {
    final data = await _send<dynamic>(
      'POST',
      '/auth/login',
      body: {'email': email, 'password': password},
      anonymous: true,
    );
    final map = Map<String, dynamic>.from(data as Map);
    final role = (map['user'] as Map?)?['role'];
    if (role != 'PARTNER') {
      throw ApiException(
        403,
        'ບັນຊີນີ້ບໍ່ແມ່ນບັນຊີທີ່ພັກ · This account is not a property owner',
      );
    }
    return map;
  }

  Future<Map<String, dynamic>> partnerRegister(Map<String, dynamic> body) async {
    final data = await _send<dynamic>(
      'POST',
      '/auth/register/partner',
      body: body,
      anonymous: true,
    );
    return Map<String, dynamic>.from(data as Map);
  }

  /// Best effort: the caller clears local tokens regardless of the outcome, so
  /// a failed round trip must not leave the app stuck on a screen it cannot use.
  Future<void> logout() async {
    final refresh = tokens.refreshToken;
    if (refresh != null && refresh.isNotEmpty) {
      try {
        await _send<dynamic>(
          'POST',
          '/auth/logout',
          body: {'refreshToken': refresh},
          anonymous: true,
        );
      } catch (_) {
        // Nothing to do — the session is being abandoned either way.
      }
    }
    await tokens.clear();
  }
}

String _transportMessage(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return 'ເຊີບເວີຕອບຊ້າເກີນໄປ · The server took too long to respond';
    case DioExceptionType.connectionError:
    case DioExceptionType.unknown:
      return 'ຕິດຕໍ່ເຊີບເວີບໍ່ໄດ້ · Cannot reach the server (${AppConfig.apiBaseUrl})';
    case DioExceptionType.cancel:
      return 'ຄຳຂໍຖືກຍົກເລີກ · Request cancelled';
    case DioExceptionType.badCertificate:
      return 'ໃບຮັບຮອງ TLS ບໍ່ຖືກຕ້ອງ · Invalid TLS certificate';
    case DioExceptionType.badResponse:
      return 'ເຊີບເວີຕອບບໍ່ຖືກຮູບແບບ · Malformed response';
  }
}

/// Nest's exception filter sends `{ message }`, sometimes as a list when
/// class-validator rejected several fields at once.
String _messageFrom(Object? data, int status) {
  if (data is Map) {
    final message = data['message'];
    if (message is String && message.isNotEmpty) return message;
    if (message is List && message.isNotEmpty) return message.join(', ');
  }
  if (status == 0) return 'ຕິດຕໍ່ເຊີບເວີບໍ່ໄດ້ · Cannot reach the server';
  return 'ຄຳຂໍລົ້ມເຫຼວ ($status)';
}
