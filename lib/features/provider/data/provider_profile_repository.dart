import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/provider_profile.dart';
import '../../../core/storage/secure_storage_service.dart';

/// Reads and writes the provider's professional profile.
///
/// The backend has no provider-profile route yet, so this persists to the
/// device. [save] is the single seam to replace when one ships: swap the
/// preferences write for a `PATCH /provider/profile` and nothing else in the
/// feature has to change.
class ProviderProfileRepository {
  ProviderProfileRepository(this._prefs);

  final AppPreferences _prefs;

  ProviderProfile load(String userId) {
    final stored = _prefs.providerProfile(userId);
    if (stored == null || stored.isEmpty) {
      return ProviderProfile.empty(userId);
    }
    return ProviderProfile.decode(stored, fallbackId: userId);
  }

  Future<ProviderProfile> save(ProviderProfile profile) async {
    // TODO(api): when the backend exposes it, send this with
    //   PATCH /provider/profile and return the server's echo instead.
    await _prefs.setProviderProfile(profile.userId, profile.encode());
    return profile;
  }
}

final providerProfileRepositoryProvider = Provider<ProviderProfileRepository>(
  (ref) => ProviderProfileRepository(ref.watch(appPreferencesProvider)),
);
