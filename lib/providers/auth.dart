import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/token_store.dart';
import '../models/models.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(tokens: ref.watch(tokenStoreProvider));
  // When a refresh finally fails, every screen must fall back to the login
  // route at once rather than each discovering it through its own 401.
  client.onSessionLost = () => ref.read(authProvider.notifier).forceSignOut();
  return client;
});

/// Where the app is in its sign-in lifecycle.
enum AuthStage {
  /// Reading the stored tokens; show a splash, decide nothing yet.
  restoring,
  signedOut,

  /// Signed in but the application has not been approved — most of the API
  /// answers 403, so the app shows the "under review" screen instead.
  pendingApproval,
  signedIn,
}

class AuthState {
  const AuthState({required this.stage, this.partner, this.error});

  final AuthStage stage;
  final Partner? partner;
  final String? error;

  bool get isBusy => stage == AuthStage.restoring;

  AuthState copyWith({AuthStage? stage, Partner? partner, String? error}) =>
      AuthState(
        stage: stage ?? this.stage,
        partner: partner ?? this.partner,
        error: error,
      );
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

class AuthNotifier extends Notifier<AuthState> {
  late final ApiClient _api;
  late final TokenStore _tokens;

  @override
  AuthState build() {
    // Dependencies are captured here, during build, and the async work below
    // uses the captured objects. Riverpod 3 forbids touching `ref` from work
    // that outlives build, and starting `restore()` from a microtask here would
    // do exactly that — the splash screen kicks it off instead.
    _api = ref.read(apiClientProvider);
    _tokens = ref.read(tokenStoreProvider);
    return const AuthState(stage: AuthStage.restoring);
  }

  /// Reads the stored session and confirms it is still good.
  ///
  /// The stored tokens alone are not proof of anything: the partner may have
  /// been approved (or rejected) since the app was last open, so `/me` decides
  /// which screen to land on.
  Future<void> restore() async {
    await _tokens.load();
    if (!_tokens.hasSession) {
      state = const AuthState(stage: AuthStage.signedOut);
      return;
    }

    try {
      _applyPartner(await _loadPartner());
    } on ApiException catch (e) {
      // 403 means the account is not a partner at all; the guard refuses it.
      if (e.isUnauthorised || e.isForbidden) {
        await _tokens.clear();
        state = AuthState(stage: AuthStage.signedOut, error: e.isForbidden ? e.message : null);
      } else {
        // A network failure is not a signed-out state — keep the session and
        // let the screen offer a retry.
        state = AuthState(stage: AuthStage.signedOut, error: e.message);
      }
    }
  }

  Future<bool> signIn(String email, String password) async {
    state = const AuthState(stage: AuthStage.restoring);
    try {
      await _saveSession(await _api.partnerLogin(email.trim(), password));
      _applyPartner(await _loadPartner());
      return true;
    } on ApiException catch (e) {
      state = AuthState(stage: AuthStage.signedOut, error: e.message);
      return false;
    }
  }

  /// Registration creates a `pending` application, so success lands on the
  /// "under review" screen rather than the dashboard.
  Future<bool> register(Map<String, dynamic> body) async {
    state = const AuthState(stage: AuthStage.restoring);
    try {
      await _saveSession(await _api.partnerRegister(body));
      _applyPartner(await _loadPartner());
      return true;
    } on ApiException catch (e) {
      state = AuthState(stage: AuthStage.signedOut, error: e.message);
      return false;
    }
  }

  Future<void> signOut() async {
    await _api.logout();
    state = const AuthState(stage: AuthStage.signedOut);
  }

  /// Called by the API client when a refresh fails — no round trip to make.
  void forceSignOut() {
    if (state.stage == AuthStage.signedOut) return;
    state = const AuthState(
      stage: AuthStage.signedOut,
      error: 'ເຊສຊັນໝົດອາຍຸ · Session expired, please sign in again',
    );
  }

  /// Re-reads the profile, so the "under review" screen can find out it has
  /// been approved without a sign-out.
  Future<void> refreshPartner() async {
    try {
      _applyPartner(await _loadPartner());
    } on ApiException {
      // Leave the current stage alone: a failed poll is not a status change.
    }
  }

  /// The partner profile.
  ///
  /// `/auth/me` returns the account — one shape for guests, partners and staff
  /// alike — while `/partner/me` returns the business: approval status, both
  /// commission rates, the bank accounts. This app needs the business, and the
  /// endpoint is readable before approval, which is what the "under review"
  /// screen polls.
  Future<Partner> _loadPartner() async {
    final me = await _api.get<dynamic>('/partner/me');
    return Partner.fromJson(Map<String, dynamic>.from(me as Map));
  }

  void _applyPartner(Partner partner) {
    state = AuthState(
      stage: partner.isVerified ? AuthStage.signedIn : AuthStage.pendingApproval,
      partner: partner,
    );
  }

  Future<void> _saveSession(Map<String, dynamic> response) => _tokens.save(
        access: response['accessToken'] as String,
        refresh: response['refreshToken'] as String,
      );
}
