import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_user.dart';
import '../../../core/models/user_role.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/session_gate.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../data/auth_repository.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.isSubmitting = false,
    this.errorMessage,
    this.sessionExpired = false,
  });

  final AuthStatus status;
  final AppUser? user;
  final bool isSubmitting;
  final String? errorMessage;

  /// Set when the refresh flow failed, so the login screen can explain why the
  /// user was bounced out.
  final bool sessionExpired;

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;
  bool get isResolving => status == AuthStatus.unknown;

  AuthState copyWith({
    AuthStatus? status,
    AppUser? user,
    bool? isSubmitting,
    String? errorMessage,
    bool? sessionExpired,
    bool clearUser = false,
    bool clearError = false,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: clearUser ? null : (user ?? this.user),
        isSubmitting: isSubmitting ?? this.isSubmitting,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        sessionExpired: sessionExpired ?? this.sessionExpired,
      );
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._ref) : super(const AuthState()) {
    _expirySubscription =
        _ref.read(sessionGateProvider).onExpired.listen((_) => _onExpired());
    unawaited(restore());
  }

  final Ref _ref;
  late final StreamSubscription<void> _expirySubscription;

  AuthRepository get _repo => _ref.read(authRepositoryProvider);
  AppPreferences get _prefs => _ref.read(appPreferencesProvider);

  /// Cold-start session restore.
  Future<void> restore() async {
    try {
      final session = await _repo.restoreSession();
      if (session == null) {
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }
      state = AuthState(
        status: AuthStatus.authenticated,
        user: _applyStoredRole(session.user),
      );
      unawaited(_topUpProfile());
    } on ApiException {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> login({
    required String phoneNumber,
    required String password,
  }) =>
      _submit(() => _repo.login(phoneNumber: phoneNumber, password: password));

  Future<bool> register({
    required String fullName,
    required String phoneNumber,
    required String password,
    required UserRole role,
    String? categoryId,
  }) =>
      _submit(() => _repo.register(
            fullName: fullName,
            phoneNumber: phoneNumber,
            password: password,
            role: role.wireValue,
            categoryId: categoryId,
          ));

  Future<bool> _submit(Future<AuthSession> Function() action) async {
    state = state.copyWith(
        isSubmitting: true, clearError: true, sessionExpired: false);
    try {
      final session = await action();
      await _prefs.setLastPhone(session.user.phoneNumber);
      await _prefs.setActiveRole(session.user.activeRole.wireValue);
      state = AuthState(
        status: AuthStatus.authenticated,
        user: session.user,
      );
      unawaited(_topUpProfile());
      return true;
    } on ApiException catch (error) {
      state = state.copyWith(isSubmitting: false, errorMessage: error.message);
      return false;
    }
  }

  /// Flips a dual-role account between the customer and provider dashboards.
  Future<void> switchRole(UserRole role) async {
    final user = state.user;
    if (user == null || !user.roles.contains(role)) return;
    await _prefs.setActiveRole(role.wireValue);
    state = state.copyWith(user: user.copyWith(activeRole: role));
  }

  Future<void> signOut() async {
    await _repo.signOut();
    await _prefs.setActiveRole(null);
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void clearError() => state = state.copyWith(clearError: true);

  Future<void> _onExpired() async {
    if (state.status == AuthStatus.unauthenticated) return;
    await _repo.signOut();
    state = const AuthState(
        status: AuthStatus.unauthenticated, sessionExpired: true);
  }

  Future<void> _topUpProfile() async {
    final current = state.user;
    if (current == null) return;
    final refreshed = await _repo.fetchProfile(current);
    if (!mounted || state.user == null) return;
    state = state.copyWith(user: _applyStoredRole(refreshed));
  }

  /// Honours the dashboard the user last chose on a dual-role account.
  AppUser _applyStoredRole(AppUser user) {
    final stored = UserRole.tryParse(_prefs.activeRole);
    if (stored != null && user.roles.contains(stored)) {
      return user.copyWith(activeRole: stored);
    }
    return user;
  }

  @override
  void dispose() {
    _expirySubscription.cancel();
    super.dispose();
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>(AuthController.new);

/// Convenience selector used by the router and dashboards.
final currentUserProvider =
    Provider<AppUser?>((ref) => ref.watch(authControllerProvider).user);
