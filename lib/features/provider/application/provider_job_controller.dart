import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/request_status.dart';
import '../../../core/models/service_request.dart';
import '../../../core/network/api_exception.dart';
import '../data/provider_repository.dart';

/// Every job dispatched to the signed-in provider.
final dispatchedRequestsProvider = FutureProvider<List<ServiceRequest>>(
  (ref) => ref.watch(providerRepositoryProvider).fetchDispatchedRequests(),
);

/// Dispatches still awaiting an accept/reject decision.
final pendingDispatchesProvider = Provider<List<ServiceRequest>>((ref) {
  final requests = ref.watch(dispatchedRequestsProvider).valueOrNull ?? const [];
  return requests.where((r) => r.status.awaitsProviderResponse).toList();
});

/// Jobs the provider has accepted and not yet finished.
final activeJobsProvider = Provider<List<ServiceRequest>>((ref) {
  final requests = ref.watch(dispatchedRequestsProvider).valueOrNull ?? const [];
  return requests.where((r) => r.status.isActiveForProvider).toList();
});

final completedJobsProvider = Provider<List<ServiceRequest>>((ref) {
  final requests = ref.watch(dispatchedRequestsProvider).valueOrNull ?? const [];
  return requests
      .where((r) => r.status == RequestStatus.completed)
      .toList();
});

final providerRequestDetailProvider =
    FutureProvider.family<ServiceRequest, String>((ref, id) async {
  // Reuse the already-loaded feed when possible to avoid a redundant round trip.
  final cached = ref.watch(dispatchedRequestsProvider).valueOrNull;
  final match = cached?.where((r) => r.id == id).firstOrNull;
  if (match != null) return match;
  return ref.watch(providerRepositoryProvider).fetchRequest(id);
});

/// Duty toggle. Optimistic, and rolls back when the API rejects the change.
class AvailabilityController extends StateNotifier<AsyncValue<bool>> {
  AvailabilityController(this._ref) : super(const AsyncValue.data(false));

  final Ref _ref;

  /// Seeds the toggle from whatever the profile/feed already knows.
  void seed(bool value) {
    if (state.valueOrNull != value && !state.isLoading) {
      state = AsyncValue.data(value);
    }
  }

  Future<String?> toggle(bool value) async {
    final previous = state.valueOrNull ?? false;
    state = AsyncValue.data(value);
    try {
      final confirmed =
          await _ref.read(providerRepositoryProvider).setAvailability(value);
      state = AsyncValue.data(confirmed);
      return null;
    } on ApiException catch (error) {
      state = AsyncValue.data(previous);
      return error.message;
    }
  }
}

final availabilityControllerProvider =
    StateNotifierProvider<AvailabilityController, AsyncValue<bool>>(
        AvailabilityController.new);

/// Tracks which job is mid-action so individual cards can show a spinner.
class JobActionController extends StateNotifier<String?> {
  JobActionController(this._ref) : super(null);

  final Ref _ref;

  bool isBusy(String id) => state == id;

  Future<String?> accept(String id) =>
      _run(id, (repo) => repo.respondToRequest(id: id, accept: true));

  Future<String?> reject(String id, String reason) => _run(
        id,
        (repo) => repo.respondToRequest(
            id: id, accept: false, rejectionReason: reason),
      );

  Future<String?> start(String id) => _run(id, (repo) => repo.startJob(id));

  Future<String?> complete(String id) =>
      _run(id, (repo) => repo.completeJob(id));

  /// Returns null on success, or an error message to surface.
  Future<String?> _run(
    String id,
    Future<ServiceRequest> Function(ProviderRepository repo) action,
  ) async {
    if (state != null) return 'Another action is still in progress.';
    state = id;
    try {
      await action(_ref.read(providerRepositoryProvider));
      _ref.invalidate(dispatchedRequestsProvider);
      // Wait for the refreshed feed so the UI never flashes stale status.
      await _ref.read(dispatchedRequestsProvider.future);
      return null;
    } on ApiException catch (error) {
      return error.message;
    } finally {
      state = null;
    }
  }
}

final jobActionControllerProvider =
    StateNotifierProvider<JobActionController, String?>(
        JobActionController.new);
