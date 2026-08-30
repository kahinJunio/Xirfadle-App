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

final providerSearchProvider =
    FutureProvider<List<ServiceProvider>>((ref) async {
  final query = ref.watch(providerQueryProvider);
  // Location is optional: a null value simply drops the proximity ranking.
  final location = ref.watch(deviceLocationProvider).valueOrNull;

  return ref.watch(customerRepositoryProvider).fetchProviders(
        categoryId: query.categoryId,
        search: query.search,
        latitude: location?.latitude,
        longitude: location?.longitude,
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
