import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/api_config.dart';
import '../../../core/models/json_utils.dart';
import '../../../core/models/service_request.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';

class ProviderRepository {
  ProviderRepository(this._api);

  final ApiClient _api;

  /// Every job dispatched to this provider, in any state.
  Future<List<ServiceRequest>> fetchDispatchedRequests() async {
    final response = await _api.get<dynamic>(ApiConfig.assignedRequests);
    final requests =
        asObjectList(response).map(ServiceRequest.fromJson).toList();
    requests.sort((a, b) => (b.createdAt ?? DateTime(1970))
        .compareTo(a.createdAt ?? DateTime(1970)));
    return requests;
  }

  /// There is no by-id read on the API; the job is picked out of the
  /// assigned feed.
  Future<ServiceRequest> fetchRequest(String id) async {
    final match =
        (await fetchDispatchedRequests()).where((r) => r.id == id).firstOrNull;
    if (match == null) {
      throw const ApiException('That job is no longer assigned to you.',
          statusCode: 404);
    }
    return match;
  }

  /// No duty-toggle route exists yet, so the switch stays local to the app.
  Future<bool> setAvailability(bool isAvailable) async => isAvailable;

  Future<ServiceRequest> respondToRequest({
    required String id,
    required bool accept,
    String? rejectionReason,
  }) async {
    final response = await _api.patch<dynamic>(
      ApiConfig.respondToRequest(id),
      // The API reads only `accept`; it has no field for a rejection reason
      // yet, so [rejectionReason] is not sent.
      data: {'accept': accept},
    );
    return _requestOrRefetch(response, id);
  }

  /// Moves an accepted job to in progress, which unlocks "Mark complete".
  Future<ServiceRequest> startJob(String id) async {
    final response = await _api.patch<dynamic>(ApiConfig.startRequest(id));
    return _requestOrRefetch(response, id);
  }

  Future<ServiceRequest> completeJob(String id) async {
    final response = await _api.patch<dynamic>(ApiConfig.completeRequest(id));
    return _requestOrRefetch(response, id);
  }

  /// Some endpoints answer 204 with no body; fall back to a fresh read.
  Future<ServiceRequest> _requestOrRefetch(Object? response, String id) async {
    final json = asObject(response);
    if (json.isEmpty) return fetchRequest(id);
    return ServiceRequest.fromJson(json);
  }
}

final providerRepositoryProvider = Provider<ProviderRepository>(
  (ref) => ProviderRepository(ref.watch(apiClientProvider)),
);
