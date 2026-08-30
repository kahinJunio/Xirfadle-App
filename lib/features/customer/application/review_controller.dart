import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/customer_repository.dart';
import 'customer_providers.dart';

class ReviewState {
  const ReviewState({
    this.rating = 5,
    this.comment = '',
    this.isSubmitting = false,
    this.errorMessage,
  });

  final int rating;
  final String comment;
  final bool isSubmitting;
  final String? errorMessage;

  ReviewState copyWith({
    int? rating,
    String? comment,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
  }) =>
      ReviewState(
        rating: rating ?? this.rating,
        comment: comment ?? this.comment,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );
}

class ReviewController extends StateNotifier<ReviewState> {
  ReviewController(this._ref) : super(const ReviewState());

  final Ref _ref;

  void setRating(int rating) =>
      state = state.copyWith(rating: rating, clearError: true);

  void setComment(String comment) => state = state.copyWith(comment: comment);

  Future<bool> submit(String requestId) async {
    if (state.isSubmitting) return false;
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _ref.read(customerRepositoryProvider).submitReview(
            requestId: requestId,
            rating: state.rating,
            comment: state.comment,
          );
      _ref.invalidate(myRequestsProvider);
      state = state.copyWith(isSubmitting: false);
      return true;
    } on ApiException catch (error) {
      state = state.copyWith(isSubmitting: false, errorMessage: error.message);
      return false;
    }
  }
}

final reviewControllerProvider =
    StateNotifierProvider.autoDispose<ReviewController, ReviewState>(
        ReviewController.new);
