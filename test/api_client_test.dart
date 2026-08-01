import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partner_app/core/api_client.dart';
import 'package:partner_app/core/token_store.dart';

/// A scripted server. Counts what was asked for, and answers 401 to anything
/// carrying the stale access token — which is what a real expiry looks like.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({
    this.refreshSucceeds = true,
    this.refreshDelay = Duration.zero,
    this.transportFails = false,
  });

  final bool refreshSucceeds;
  final bool transportFails;

  /// Holds the refresh open long enough for other requests to pile up behind it.
  final Duration refreshDelay;

  int refreshCalls = 0;
  int dataCalls = 0;
  final List<String> seenAuthHeaders = [];

  static const staleToken = 'stale-access';

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (transportFails) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'no route to host',
      );
    }

    if (options.path == '/auth/refresh') {
      refreshCalls++;
      if (refreshDelay > Duration.zero) await Future<void>.delayed(refreshDelay);
      if (!refreshSucceeds) return _json({'message': 'Session revoked'}, 401);
      return _json({
        'accessToken': 'fresh-access',
        'refreshToken': 'fresh-refresh',
        'expiresIn': '15m',
      }, 200);
    }

    dataCalls++;
    final auth = options.headers['Authorization']?.toString() ?? '';
    seenAuthHeaders.add(auth);

    // No token at all, or an expired one, is a 401 — as the real API answers.
    if (auth.isEmpty || auth.contains(staleToken)) {
      return _json({'message': 'Unauthorized'}, 401);
    }
    if (options.path == '/partner/forbidden') {
      return _json({'message': 'ສິດບໍ່ພຽງພໍ · Admin access required'}, 403);
    }
    return _json({'ok': true, 'path': options.path}, 200);
  }

  ResponseBody _json(Object body, int status) => ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
}

Future<ApiClient> _client(_FakeAdapter adapter, {bool withSession = true}) async {
  final tokens = TokenStore(
    storage: InMemoryKeyValueStore(
      withSession
          ? {
              TokenStore.accessKey: _FakeAdapter.staleToken,
              TokenStore.refreshKey: 'valid-refresh',
            }
          : null,
    ),
  );
  await tokens.load();

  final dio = Dio()..httpClientAdapter = adapter;
  return ApiClient(tokens: tokens, dio: dio, baseUrl: 'http://test.local/api');
}

void main() {
  test('a 401 triggers one refresh and replays the original request', () async {
    final adapter = _FakeAdapter();
    final api = await _client(adapter);

    final result = await api.get<Map<String, dynamic>>('/partner/dashboard');

    expect(result['ok'], isTrue);
    expect(adapter.refreshCalls, 1);
    // Once with the stale token, once with the fresh one.
    expect(adapter.dataCalls, 2);
    expect(adapter.seenAuthHeaders.first, contains('stale-access'));
    expect(adapter.seenAuthHeaders.last, contains('fresh-access'));
  });

  test('concurrent 401s share a single refresh', () async {
    // This is the one that matters. The backend rotates refresh tokens and
    // treats a reused one as theft — it revokes every session for that partner.
    // Five screens refreshing in parallel would present four reused tokens and
    // log the user out of everything.
    final adapter = _FakeAdapter(refreshDelay: const Duration(milliseconds: 60));
    final api = await _client(adapter);

    final results = await Future.wait([
      api.get<Map<String, dynamic>>('/partner/dashboard'),
      api.get<Map<String, dynamic>>('/partner/bookings'),
      api.get<Map<String, dynamic>>('/partner/payouts'),
      api.get<Map<String, dynamic>>('/partner/reviews'),
      api.get<Map<String, dynamic>>('/partner/me'),
    ]);

    expect(results.every((r) => r['ok'] == true), isTrue);
    expect(adapter.refreshCalls, 1, reason: 'the five callers must await one refresh');
  });

  test('a failed refresh clears the session and reports it once', () async {
    final adapter = _FakeAdapter(refreshSucceeds: false);
    final api = await _client(adapter);

    var sessionLost = 0;
    api.onSessionLost = () => sessionLost++;

    await expectLater(
      api.get<Map<String, dynamic>>('/partner/dashboard'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
    );

    expect(sessionLost, 1);
    expect(api.tokens.hasSession, isFalse, reason: 'dead tokens must not be kept');
  });

  test('a healthy token needs no refresh', () async {
    final adapter = _FakeAdapter();
    final api = await _client(adapter);
    await api.tokens.save(access: 'good-access', refresh: 'valid-refresh');

    final result = await api.get<Map<String, dynamic>>('/partner/me');

    expect(result['ok'], isTrue);
    expect(adapter.refreshCalls, 0);
    expect(adapter.dataCalls, 1);
  });

  test('a non-401 error carries the message the API sent', () async {
    final adapter = _FakeAdapter();
    final api = await _client(adapter);
    await api.tokens.save(access: 'good-access', refresh: 'valid-refresh');

    await expectLater(
      api.get<Map<String, dynamic>>('/partner/forbidden'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'status', 403)
            // The API answers in Lao and English; showing that beats a generic
            // "something went wrong".
            .having((e) => e.message, 'message', contains('ສິດບໍ່ພຽງພໍ')),
      ),
    );
  });

  test('with no stored session a 401 is not retried', () async {
    final adapter = _FakeAdapter();
    final api = await _client(adapter, withSession: false);

    await expectLater(
      api.get<Map<String, dynamic>>('/partner/dashboard'),
      throwsA(isA<ApiException>()),
    );
    expect(adapter.refreshCalls, 0);
  });

  test('a transport failure is reported as unreachable, not as a bad session', () async {
    final adapter = _FakeAdapter(transportFails: true);
    final api = await _client(adapter);

    var sessionLost = 0;
    api.onSessionLost = () => sessionLost++;

    await expectLater(
      api.get<Map<String, dynamic>>('/partner/dashboard'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'status', isNull)
            .having((e) => e.message, 'message', contains('ຕິດຕໍ່ເຊີບເວີບໍ່ໄດ້')),
      ),
    );

    // A dead network is not a dead session — the tokens are probably fine.
    expect(sessionLost, 0);
    expect(api.tokens.hasSession, isTrue);
  });
}
