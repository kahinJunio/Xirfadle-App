import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/provider_profile.dart';
import '../../auth/application/auth_controller.dart';
import '../data/provider_profile_repository.dart';

class ProviderProfileState {
  const ProviderProfileState({
    required this.profile,
    this.isSaving = false,
    this.errorMessage,
  });

  final ProviderProfile profile;
  final bool isSaving;
  final String? errorMessage;

  ProviderProfileState copyWith({
    ProviderProfile? profile,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) =>
      ProviderProfileState(
        profile: profile ?? this.profile,
        isSaving: isSaving ?? this.isSaving,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );
}

class ProviderProfileController extends StateNotifier<ProviderProfileState> {
  ProviderProfileController(this._repo, String userId)
      : super(ProviderProfileState(profile: _repo.load(userId)));

  final ProviderProfileRepository _repo;

  /// Persists the edited profile. Returns true on success; on failure the
  /// message is left on [state] for the screen to show.
  Future<bool> save(ProviderProfile updated) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final saved = await _repo.save(updated);
      state = state.copyWith(profile: saved, isSaving: false);
      return true;
    } catch (_) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Could not save your profile. Please try again.',
      );
      return false;
    }
  }
}

/// Scoped to the signed-in provider. Rebuilds if the account changes.
final providerProfileControllerProvider = StateNotifierProvider<
    ProviderProfileController, ProviderProfileState>((ref) {
  final repo = ref.watch(providerProfileRepositoryProvider);
  final userId = ref.watch(currentUserProvider)?.id ?? 'anonymous';
  return ProviderProfileController(repo, userId);
});
