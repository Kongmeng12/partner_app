import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partner_app/core/api_client.dart';
import 'package:partner_app/core/token_store.dart';
import 'package:partner_app/providers/auth.dart';

/// Answers `/partner/me` and `/auth/login` with a chosen approval status.
class _AuthAdapter implements HttpClientAdapter {
  _AuthAdapter({this.status = 'verified', this.meStatusCode = 200});

  /// The `partner_status` `/partner/me` reports.
  final String status;

  /// What `/partner/me` answers with — 403 when the account is not a partner.
  final int meStatusCode;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // `/partner/me`: the business, which is what decides the stage.
    final partner = {
      'id': '7',
      'businessName': 'Vintage House Vientiane',
      'email': 'vintage@laostay.la',
      'ownerName': 'ນາງ ວັນນະສອນ',
      'contactPhone': '+856 20 5511 2233',
      'status': status,
      'commissionRate': 5,
      'walkinCommissionRate': 2.5,
      'propertyCount': 1,
      'bankAccounts': const <Object>[],
    };

    if (options.path == '/partner/me') {
      return _json(meStatusCode == 200 ? partner : {'message': 'ບໍ່ຜ່ານ'}, meStatusCode);
    }
    // One login endpoint for the whole platform, so the response carries the
    // account and its role rather than a partner.
    if (options.path == '/auth/login') {
      return _json({
        'accessToken': 'a',
        'refreshToken': 'r',
        'expiresIn': '15m',
        'user': {
          'id': '12',
          'email': 'vintage@laostay.la',
          'role': 'PARTNER',
          'adminRole': null,
          'fullName': 'ນາງ ວັນນະສອນ',
          'phone': '+856 20 5511 2233',
          'isVerified': true,
          'partnerId': '7',
          'partnerStatus': status,
        },
      }, 200);
    }
    return _json({'ok': true}, 200);
  }

  ResponseBody _json(Object body, int status) => ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
}

ProviderContainer _container(_AuthAdapter adapter, {bool withSession = true}) {
  final tokens = TokenStore(
    storage: InMemoryKeyValueStore(
      withSession
          ? {TokenStore.accessKey: 'a', TokenStore.refreshKey: 'r'}
          : null,
    ),
  );

  final container = ProviderContainer(
    overrides: [
      tokenStoreProvider.overrideWithValue(tokens),
      apiClientProvider.overrideWith((ref) {
        final dio = Dio()..httpClientAdapter = adapter;
        return ApiClient(tokens: tokens, dio: dio, baseUrl: 'http://test.local/api');
      }),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// The auth stage is what the router's redirect keys off, so these four cases
/// are the whole navigation contract:
///
///   restoring        → splash
///   signedOut        → /login
///   pendingApproval  → /pending
///   signedIn         → the app
void main() {
  test('a stored session for an approved partner ends up signed in', () async {
    final container = _container(_AuthAdapter());
    final notifier = container.read(authProvider.notifier);

    await notifier.restore();

    expect(container.read(authProvider).stage, AuthStage.signedIn);
    expect(container.read(authProvider).partner?.isVerified, isTrue);
  });

  test('an unapproved partner is held at the pending screen', () async {
    // Without this the app would show a dashboard made entirely of 403s: every
    // route that needs a verified partner refuses them.
    final container = _container(_AuthAdapter(status: 'pending'));
    final notifier = container.read(authProvider.notifier);

    await notifier.restore();

    expect(container.read(authProvider).stage, AuthStage.pendingApproval);
  });

  test('no stored session means signed out', () async {
    final container = _container(_AuthAdapter(), withSession: false);
    final notifier = container.read(authProvider.notifier);

    await notifier.restore();

    expect(container.read(authProvider).stage, AuthStage.signedOut);
  });

  test('a rejected application is signed out and told why', () async {
    final container = _container(_AuthAdapter(meStatusCode: 403));
    final notifier = container.read(authProvider.notifier);

    await notifier.restore();

    final state = container.read(authProvider);
    expect(state.stage, AuthStage.signedOut);
    expect(state.error, isNotNull);
    expect(container.read(tokenStoreProvider).hasSession, isFalse);
  });

  test('signing in stores the session and lands on the right stage', () async {
    final container = _container(_AuthAdapter(status: 'pending'), withSession: false);
    final notifier = container.read(authProvider.notifier);

    final ok = await notifier.signIn('vintage@laostay.la', 'Partner@2026');

    expect(ok, isTrue);
    expect(container.read(tokenStoreProvider).hasSession, isTrue);
    // Signing in does not mean approved.
    expect(container.read(authProvider).stage, AuthStage.pendingApproval);
  });
}
