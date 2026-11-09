import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/service_category.dart';
import '../../../core/models/service_provider.dart';
import '../../../core/models/service_request.dart';
import '../../../core/utils/location_service.dart';
import '../data/customer_repository.dart';

/// Service category grid on `/customer/home`.
final categoriesProvider = FutureProvider<List<ServiceCategory>>(
  (ref) => ref.watch(customerRepositoryProvider).fetchCategories(),
);

/// Filters driving the provider list.
class ProviderQuery {
  const ProviderQuery({this.categoryId, this.search = ''});

  final String? categoryId;
  final String search;

  ProviderQuery copyWith({
    String? categoryId,
    String? search,
    bool clearCategory = false,
  }) =>
      ProviderQuery(
        categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
        search: search ?? this.search,
      );

  @override
  bool operator ==(Object other) =>
      other is ProviderQuery &&
      other.categoryId == categoryId &&
      other.search == search;

  @override
  int get hashCode => Object.hash(categoryId, search);
}

final providerQueryProvider =
    StateProvider<ProviderQuery>((ref) => const ProviderQuery());

/// The provider feed from the backend, ranked by availability/proximity/rating
/// and filtered only by the selected category. Text search is applied on top
/// of this locally (see [providerSearchProvider]) so results update instantly
/// as the user types, without a network round-trip per keystroke — and without
/// depending on the backend supporting a `search` query parameter.
final providerFeedProvider =
    FutureProvider<List<ServiceProvider>>((ref) async {
  // Only the category (and location) drive the fetch; the search text does not,
  // so typing never refetches.
  final categoryId = ref.watch(providerQueryProvider.select((q) => q.categoryId));
  // Location is optional: a null value simply drops the proximity ranking.
  final location = ref.watch(deviceLocationProvider).valueOrNull;

  return ref.watch(customerRepositoryProvider).fetchProviders(
        categoryId: categoryId,
        latitude: location?.latitude,
        longitude: location?.longitude,
      );
});

/// Splits the raw search text into lowercase tokens for an AND match.
List<String> _searchTokens(String raw) => raw
    .toLowerCase()
    .split(RegExp(r'\s+'))
    .where((t) => t.isNotEmpty)
    .toList();

/// Case-insensitive match across the fields a shopper expects to search:
/// name, trade, specialties, city and bio. Every token must appear somewhere
/// (Amazon-style AND), so "ali plumber" narrows to Ali *and* plumbing.
bool _matchesProvider(ServiceProvider p, List<String> tokens) {
  if (tokens.isEmpty) return true;
  final haystack = [
    p.fullName,
    p.categoryName ?? '',
    p.city ?? '',
    p.bio ?? '',
    p.specialties.join(' '),
  ].join(' ').toLowerCase();
  return tokens.every(haystack.contains);
}

/// The provider list after local text filtering. Mirrors the feed's
/// loading/error state so the UI keeps its spinner and retry affordances.
final providerSearchProvider =
    Provider<AsyncValue<List<ServiceProvider>>>((ref) {
  final feed = ref.watch(providerFeedProvider);
  final search = ref.watch(providerQueryProvider.select((q) => q.search));
  final tokens = _searchTokens(search);
  return feed.whenData(
    (list) => list.where((p) => _matchesProvider(p, tokens)).toList(),
  );
});

final providerDetailProvider =
    FutureProvider.family<ServiceProvider, String>((ref, id) async {
  return ref.watch(customerRepositoryProvider).fetchProvider(id);
});

final providerReviewsProvider =
    FutureProvider.family<List<ProviderReview>, String>((ref, id) async {
  try {
    return await ref.watch(customerRepositoryProvider).fetchProviderReviews(id);
  } catch (_) {
    // Reviews are a nice-to-have; never block the detail screen on them.
    return const <ProviderReview>[];
  }
});

/// The customer's own job feed, backing `/customer/my-requests`.
final myRequestsProvider = FutureProvider<List<ServiceRequest>>(
  (ref) => ref.watch(customerRepositoryProvider).fetchMyRequests(),
);

final customerRequestDetailProvider =
    FutureProvider.family<ServiceRequest, String>((ref, id) async {
  return ref.watch(customerRepositoryProvider).fetchRequest(id);
});
