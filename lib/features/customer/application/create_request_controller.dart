import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/models/service_category.dart';
import '../../../core/models/service_request.dart';
import '../../../core/network/api_exception.dart';
import '../data/customer_repository.dart';
import 'customer_providers.dart';

class CreateRequestState {
  const CreateRequestState({
    this.category,
    this.description = '',
    this.address = '',
    this.preferredTime,
    this.pin,
    this.preferredProviderId,
    this.isSubmitting = false,
    this.errorMessage,
    this.submitted,
  });

  final ServiceCategory? category;
  final String description;
  final String address;
  final String? preferredTime;
  final LatLng? pin;
  final String? preferredProviderId;
  final bool isSubmitting;
  final String? errorMessage;

  /// Set once the API accepts the job, driving the confirmation screen.
  final ServiceRequest? submitted;

  bool get canSubmit =>
      category != null &&
      description.trim().length >= 10 &&
      address.trim().length >= 4 &&
      !isSubmitting;

  CreateRequestState copyWith({
    ServiceCategory? category,
    String? description,
    String? address,
    String? preferredTime,
    LatLng? pin,
    String? preferredProviderId,
    bool? isSubmitting,
    String? errorMessage,
    ServiceRequest? submitted,
    bool clearError = false,
  }) =>
      CreateRequestState(
        category: category ?? this.category,
        description: description ?? this.description,
        address: address ?? this.address,
        preferredTime: preferredTime ?? this.preferredTime,
        pin: pin ?? this.pin,
        preferredProviderId: preferredProviderId ?? this.preferredProviderId,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        submitted: submitted ?? this.submitted,
      );
}

class CreateRequestController extends StateNotifier<CreateRequestState> {
  CreateRequestController(this._ref) : super(const CreateRequestState());

  final Ref _ref;

  void selectCategory(ServiceCategory category) =>
      state = state.copyWith(category: category, clearError: true);

  void setDescription(String value) =>
      state = state.copyWith(description: value, clearError: true);

  void setPreferredTime(String? value) =>
      state = state.copyWith(preferredTime: value);

  void setPreferredProvider(String? id) =>
      state = state.copyWith(preferredProviderId: id);

  void setAddress(String address, {LatLng? pin}) =>
      state = state.copyWith(address: address, pin: pin, clearError: true);

  void reset() => state = const CreateRequestState();

  Future<bool> submit() async {
    if (!state.canSubmit) return false;
    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final created =
          await _ref.read(customerRepositoryProvider).createRequest(
                CreateRequestPayload(
                  categoryId: state.category!.id,
                  description: state.description.trim(),
                  address: state.address.trim(),
                  preferredTime: state.preferredTime,
                  latitude: state.pin?.latitude,
                  longitude: state.pin?.longitude,
                  preferredProviderId: state.preferredProviderId,
                ),
              );

      // The new job must show up immediately in the tracker.
      _ref.invalidate(myRequestsProvider);
      state = state.copyWith(isSubmitting: false, submitted: created);
      return true;
    } on ApiException catch (error) {
      state = state.copyWith(isSubmitting: false, errorMessage: error.message);
      return false;
    }
  }
}

final createRequestControllerProvider = StateNotifierProvider.autoDispose<
    CreateRequestController, CreateRequestState>(CreateRequestController.new);
