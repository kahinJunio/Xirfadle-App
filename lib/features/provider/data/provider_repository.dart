import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/api_config.dart';
import '../../../core/models/json_utils.dart';
import '../../../core/models/request_status.dart';
import '../../../core/models/service_request.dart';
import '../../../core/network/dio_client.dart';

class ProviderRepository {
  ProviderRepository(this._api);

  final ApiClient _api;

  /// Every job dispatched to this provider, in any state.
  Future<List<ServiceRequest>> fetchDispatchedRequests() async {
    final response = await _api.get<dynamic>(ApiConfig.providerRequests);
    final requests =
        asObjectList(response).map(ServiceRequest.fromJson).toList();
    requests.sort((a, b) => (b.createdAt ?? DateTime(1970))
        .compareTo(a.createdAt ?? DateTime(1970)));
    return requests;
  }

  Future<ServiceRequest> fetchRequest(String id) async {
    final response =
        await _api.get<dynamic>('${ApiConfig.providerRequests}/$id');
    return ServiceRequest.fromJson(asObject(response));
  }

  /// Flips the duty toggle so admins know whether to dispatch.
  Future<bool> setAvailability(bool isAvailable) async {
    final response = await _api.patch<dynamic>(
      ApiConfig.availability,
      data: {'isAvailable': isAvailable},
    );
    final json = asObject(response);
    return json.isEmpty
        ? isAvailable
        : asBool(json, ['isAvailable', 'available'], fallback: isAvailable);
  }

  Future<ServiceRequest> respondToRequest({
    required String id,
    required bool accept,
    String? rejectionReason,
  }) async {
    final response = await _api.patch<dynamic>(
      ApiConfig.respondToRequest(id),
      data: {
        'status': accept
            ? RequestStatus.acceptedByProvider.wireValue
            : RequestStatus.rejectedByProvider.wireValue,
        if (!accept && rejectionReason != null)
          'rejectionReason': rejectionReason,
      },
    );
    return _requestOrRefetch(response, id);
  }

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
