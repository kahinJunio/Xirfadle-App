import 'package:flutter/material.dart';

import '../../app/config/app_theme.dart';

/// Mirrors the backend service-request state machine.
enum RequestStatus {
  pendingAdminReview('PendingAdminReview'),
  confirmedByAdmin('ConfirmedByAdmin'),
  assigned('Assigned'),
  acceptedByProvider('AcceptedByProvider'),
  rejectedByProvider('RejectedByProvider'),
  inProgress('InProgress'),
  completed('Completed'),
  cancelled('Cancelled');

  const RequestStatus(this.wireValue);

  /// Exact string exchanged with the API.
  final String wireValue;

  static RequestStatus fromWire(String? value) {
    if (value == null) return RequestStatus.pendingAdminReview;
    final normalised = value.replaceAll('_', '').toLowerCase();
    return RequestStatus.values.firstWhere(
      (s) => s.wireValue.toLowerCase() == normalised,
      orElse: () => RequestStatus.pendingAdminReview,
    );
  }

  /// Label shown to the customer in the status tracker.
  String get customerLabel => switch (this) {
        RequestStatus.pendingAdminReview => 'Admin Reviewing',
        RequestStatus.confirmedByAdmin ||
        RequestStatus.assigned =>
          'Matching Provider',
        RequestStatus.acceptedByProvider => 'Provider Assigned & Confirmed',
        RequestStatus.rejectedByProvider => 'Re-matching Provider',
        RequestStatus.inProgress => 'Work In Progress',
        RequestStatus.completed => 'Completed — Tap to Rate',
        RequestStatus.cancelled => 'Cancelled',
      };

  /// Label shown to the provider on dispatch and job cards.
  String get providerLabel => switch (this) {
        RequestStatus.pendingAdminReview => 'Awaiting Admin',
        RequestStatus.confirmedByAdmin => 'Confirmed by Admin',
        RequestStatus.assigned => 'Awaiting Your Response',
        RequestStatus.acceptedByProvider => 'Accepted',
        RequestStatus.rejectedByProvider => 'Rejected',
        RequestStatus.inProgress => 'In Progress',
        RequestStatus.completed => 'Completed',
        RequestStatus.cancelled => 'Cancelled',
      };

  Color get color => switch (this) {
        RequestStatus.pendingAdminReview => AppTheme.statusPending,
        RequestStatus.confirmedByAdmin ||
        RequestStatus.assigned =>
          AppTheme.statusMatching,
        RequestStatus.acceptedByProvider ||
        RequestStatus.inProgress =>
          AppTheme.statusActive,
        RequestStatus.completed => AppTheme.statusDone,
        RequestStatus.rejectedByProvider ||
        RequestStatus.cancelled =>
          AppTheme.statusRejected,
      };

  IconData get icon => switch (this) {
        RequestStatus.pendingAdminReview => Icons.hourglass_top_rounded,
        RequestStatus.confirmedByAdmin ||
        RequestStatus.assigned =>
          Icons.person_search_rounded,
        RequestStatus.acceptedByProvider => Icons.verified_rounded,
        RequestStatus.inProgress => Icons.handyman_rounded,
        RequestStatus.completed => Icons.task_alt_rounded,
        RequestStatus.rejectedByProvider => Icons.replay_rounded,
        RequestStatus.cancelled => Icons.cancel_rounded,
      };

  /// The customer may leave a review only once the job is finished.
  bool get isRatable => this == RequestStatus.completed;

  /// A dispatch the provider still has to accept or reject.
  bool get awaitsProviderResponse =>
      this == RequestStatus.assigned || this == RequestStatus.confirmedByAdmin;

  /// A job the provider is currently working on.
  bool get isActiveForProvider =>
      this == RequestStatus.acceptedByProvider || this == RequestStatus.inProgress;

  bool get isTerminal =>
      this == RequestStatus.completed || this == RequestStatus.cancelled;
}
