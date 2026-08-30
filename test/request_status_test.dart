import 'package:flutter_test/flutter_test.dart';
import 'package:xirfadle_app/core/models/request_status.dart';

void main() {
  group('RequestStatus.fromWire', () {
    test('parses the exact backend values', () {
      expect(RequestStatus.fromWire('PendingAdminReview'),
          RequestStatus.pendingAdminReview);
      expect(RequestStatus.fromWire('ConfirmedByAdmin'),
          RequestStatus.confirmedByAdmin);
      expect(RequestStatus.fromWire('AcceptedByProvider'),
          RequestStatus.acceptedByProvider);
      expect(RequestStatus.fromWire('RejectedByProvider'),
          RequestStatus.rejectedByProvider);
      expect(RequestStatus.fromWire('Completed'), RequestStatus.completed);
    });

    test('tolerates casing and snake_case variants', () {
      expect(RequestStatus.fromWire('pendingadminreview'),
          RequestStatus.pendingAdminReview);
      expect(RequestStatus.fromWire('IN_PROGRESS'), RequestStatus.inProgress);
    });

    test('falls back to PendingAdminReview for unknown or null values', () {
      expect(RequestStatus.fromWire(null), RequestStatus.pendingAdminReview);
      expect(RequestStatus.fromWire('SomethingNew'),
          RequestStatus.pendingAdminReview);
    });
  });

  group('customer labels match the spec', () {
    test('each state maps to the documented badge text', () {
      expect(RequestStatus.pendingAdminReview.customerLabel, 'Admin Reviewing');
      expect(
          RequestStatus.confirmedByAdmin.customerLabel, 'Matching Provider');
      expect(RequestStatus.assigned.customerLabel, 'Matching Provider');
      expect(RequestStatus.acceptedByProvider.customerLabel,
          'Provider Assigned & Confirmed');
      expect(RequestStatus.completed.customerLabel, 'Completed — Tap to Rate');
    });
  });

  group('state predicates', () {
    test('only a completed job is ratable', () {
      for (final status in RequestStatus.values) {
        expect(status.isRatable, status == RequestStatus.completed,
            reason: '$status');
      }
    });

    test('a dispatch awaits a response until accepted or rejected', () {
      expect(RequestStatus.assigned.awaitsProviderResponse, isTrue);
      expect(RequestStatus.confirmedByAdmin.awaitsProviderResponse, isTrue);
      expect(RequestStatus.acceptedByProvider.awaitsProviderResponse, isFalse);
      expect(RequestStatus.rejectedByProvider.awaitsProviderResponse, isFalse);
    });

    test('accepted and in-progress jobs are active for the provider', () {
      expect(RequestStatus.acceptedByProvider.isActiveForProvider, isTrue);
      expect(RequestStatus.inProgress.isActiveForProvider, isTrue);
      expect(RequestStatus.completed.isActiveForProvider, isFalse);
    });

    test('completed and cancelled are the terminal states', () {
      expect(RequestStatus.completed.isTerminal, isTrue);
      expect(RequestStatus.cancelled.isTerminal, isTrue);
      expect(RequestStatus.inProgress.isTerminal, isFalse);
    });
  });
}
