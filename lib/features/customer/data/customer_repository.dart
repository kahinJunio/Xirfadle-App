import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/api_config.dart';
import '../../../core/models/json_utils.dart';
import '../../../core/models/service_category.dart';
import '../../../core/models/service_provider.dart';
import '../../../core/models/service_request.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';

class CustomerRepository {
  CustomerRepository(this._api);

  final ApiClient _api;

  Future<List<ServiceCategory>> fetchCategories() async {
    final response = await _api.get<dynamic>(ApiConfig.categories);
    return asObjectList(response).map(ServiceCategory.fromJson).toList();
  }

  /// Providers sorted by rating and proximity. Coordinates let the API rank by
  /// distance; the client re-sorts as a fallback.
  Future<List<ServiceProvider>> fetchProviders({
    String? categoryId,
    String? search,
    double? latitude,
    double? longitude,
  }) async {
    final response = await _api.get<dynamic>(
      ApiConfig.providers,
      query: {
        'categoryId': ?categoryId,
        if (search != null && search.isNotEmpty) 'search': search,
        'latitude': ?latitude,
        'longitude': ?longitude,
      },
    );

    final providers =
        asObjectList(response).map(ServiceProvider.fromJson).toList();

    providers.sort((a, b) {
      // Available providers first, then closest, then best rated.
      if (a.isAvailable != b.isAvailable) return a.isAvailable ? -1 : 1;
      final da = a.distanceKm, db = b.distanceKm;
      if (da != null && db != null && da != db) return da.compareTo(db);
      return b.rating.compareTo(a.rating);
    });
    return providers;
  }

  Future<ServiceProvider> fetchProvider(String id) async {
    final response = await _api.get<dynamic>(ApiConfig.providerDetail(id));
    return ServiceProvider.fromJson(asObject(response));
  }

  /// The API exposes no reviews route, so the detail screen renders whatever
  /// the provider payload already carries and nothing more.
  Future<List<ProviderReview>> fetchProviderReviews(String id) async =>
      const <ProviderReview>[];

  /// Submits a job; the backend initialises it to `PendingAdminReview`.
  Future<ServiceRequest> createRequest(CreateRequestPayload payload) async {
    final response =
        await _api.post<dynamic>(ApiConfig.requests, data: payload.toJson());
    return ServiceRequest.fromJson(asObject(response));
  }

  Future<List<ServiceRequest>> fetchMyRequests() async {
    final response = await _api.get<dynamic>(ApiConfig.myRequests);
    final requests =
        asObjectList(response).map(ServiceRequest.fromJson).toList();
    requests.sort((a, b) => (b.createdAt ?? DateTime(1970))
        .compareTo(a.createdAt ?? DateTime(1970)));
    return requests;
  }

  /// There is no by-id read on the API; the request is picked out of the
  /// customer's own feed.
  Future<ServiceRequest> fetchRequest(String id) async {
    final match =
        (await fetchMyRequests()).where((r) => r.id == id).firstOrNull;
    if (match == null) {
      throw const ApiException('That request is no longer available.',
          statusCode: 404);
    }
    return match;
  }

  Future<void> cancelRequest(String id) async {
    throw const ApiException(
        'Cancelling a request is not supported yet. Please contact support.');
  }

  Future<void> submitReview({
    required String requestId,
    required int rating,
    String? comment,
  }) async {
    throw const ApiException('Reviews are not available yet.');
  }
}

final customerRepositoryProvider = Provider<CustomerRepository>(
  (ref) => CustomerRepository(ref.watch(apiClientProvider)),
);
