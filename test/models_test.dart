import 'package:flutter_test/flutter_test.dart';
import 'package:xirfadle_app/core/models/app_user.dart';
import 'package:xirfadle_app/core/models/json_utils.dart';
import 'package:xirfadle_app/core/models/request_status.dart';
import 'package:xirfadle_app/core/models/service_provider.dart';
import 'package:xirfadle_app/core/models/service_request.dart';
import 'package:xirfadle_app/core/models/user_role.dart';

void main() {
  group('ServiceRequest.fromJson', () {
    test('reads a camelCase payload', () {
      final request = ServiceRequest.fromJson({
        'id': 'a1b2c3d4',
        'status': 'AcceptedByProvider',
        'categoryName': 'Plumbing',
        'description': 'Leaking sink',
        'address': 'Hodan district',
        'agreedPrice': 25.5,
        'currency': 'USD',
        'providerName': 'Ayaan',
        'createdAt': '2026-08-01T10:30:00Z',
      });

      expect(request.status, RequestStatus.acceptedByProvider);
      expect(request.categoryName, 'Plumbing');
      expect(request.agreedPrice, 25.5);
      expect(request.priceLabel, 'USD 25.50');
      expect(request.createdAt, isNotNull);
    });

    test('reads the PascalCase payload ASP.NET Core can emit', () {
      final request = ServiceRequest.fromJson({
        'Id': 'x9',
        'Status': 'PendingAdminReview',
        'CategoryName': 'Electrical',
        'Description': 'No power in the kitchen',
        'Address': 'Wadajir',
      });

      expect(request.id, 'x9');
      expect(request.status, RequestStatus.pendingAdminReview);
      expect(request.categoryName, 'Electrical');
    });

    test('survives a payload missing every optional field', () {
      final request = ServiceRequest.fromJson({'id': 'bare'});

      expect(request.status, RequestStatus.pendingAdminReview);
      expect(request.agreedPrice, isNull);
      expect(request.priceLabel, 'Price pending');
      expect(request.categoryName, 'Service');
    });

    test('a completed job is ratable only until a review exists', () {
      final unrated = ServiceRequest.fromJson(
          {'id': '1', 'status': 'Completed', 'hasReview': false});
      final rated = ServiceRequest.fromJson(
          {'id': '1', 'status': 'Completed', 'hasReview': true});

      expect(unrated.canBeRated, isTrue);
      expect(rated.canBeRated, isFalse);
    });
  });

  group('CreateRequestPayload', () {
    test('initialises the status to PendingAdminReview', () {
      final json = const CreateRequestPayload(
        categoryId: 'cat-1',
        description: 'Broken pipe under the sink',
        address: 'Hodan',
      ).toJson();

      expect(json['status'], 'PendingAdminReview');
      expect(json.containsKey('latitude'), isFalse);
    });

    test('includes the map pin when one was dropped', () {
      final json = const CreateRequestPayload(
        categoryId: 'cat-1',
        description: 'Broken pipe',
        address: 'Hodan',
        latitude: 2.04,
        longitude: 45.31,
      ).toJson();

      expect(json['latitude'], 2.04);
      expect(json['longitude'], 45.31);
    });
  });

  group('AppUser.fromClaims', () {
    test('reads short role claims', () {
      final user = AppUser.fromClaims({
        'sub': 'u-1',
        'name': 'Hodan Ali',
        'role': ['Customer'],
        'phoneNumber': '+252611234567',
      });

      expect(user.roles, [UserRole.customer]);
      expect(user.activeRole, UserRole.customer);
      expect(user.initials, 'HA');
    });

    test('reads the Microsoft role claim URI', () {
      final user = AppUser.fromClaims({
        'sub': 'u-2',
        'http://schemas.microsoft.com/ws/2008/06/identity/claims/role':
            'Provider',
      });

      expect(user.roles, [UserRole.provider]);
      expect(user.activeRole, UserRole.provider);
      expect(user.isProvider, isTrue);
    });

    test('a dual-role account defaults to the customer dashboard', () {
      final user = AppUser.fromClaims({
        'sub': 'u-3',
        'role': ['Provider', 'Customer'],
      });

      expect(user.isDualRole, isTrue);
      expect(user.activeRole, UserRole.customer);
      expect(user.copyWith(activeRole: UserRole.provider).isProvider, isTrue);
    });

    test('defaults to Customer when no role claim is present', () {
      final user = AppUser.fromClaims({'sub': 'u-4'});
      expect(user.roles, [UserRole.customer]);
    });
  });

  group('UserRole.tryParse', () {
    test('accepts backend synonyms', () {
      expect(UserRole.tryParse('ServiceProvider'), UserRole.provider);
      expect(UserRole.tryParse('SkilledPerson'), UserRole.provider);
      expect(UserRole.tryParse('client'), UserRole.customer);
      expect(UserRole.tryParse('Admin'), UserRole.admin);
      expect(UserRole.tryParse('nonsense'), isNull);
      expect(UserRole.tryParse(null), isNull);
    });
  });

  group('asObjectList', () {
    test('unwraps a data envelope', () {
      final items = asObjectList({
        'data': [
          {'id': '1'},
          {'id': '2'},
        ]
      });
      expect(items, hasLength(2));
    });

    test('accepts a bare array', () {
      expect(asObjectList([{'id': '1'}]), hasLength(1));
    });

    test('returns empty for an unexpected shape', () {
      expect(asObjectList('nope'), isEmpty);
      expect(asObjectList(null), isEmpty);
    });
  });

  group('ServiceProvider', () {
    test('formats distance in metres under one kilometre', () {
      final near = ServiceProvider.fromJson(
          {'id': '1', 'fullName': 'Ali Nur', 'distanceKm': 0.4});
      expect(near.distanceLabel, '400 m away');

      final far = ServiceProvider.fromJson(
          {'id': '2', 'fullName': 'Ali Nur', 'distanceKm': 3.25});
      expect(far.distanceLabel, '3.3 km away');
    });

    test('falls back to the city when distance is unknown', () {
      final provider = ServiceProvider.fromJson(
          {'id': '3', 'fullName': 'Ali Nur', 'city': 'Mogadishu'});
      expect(provider.distanceLabel, 'Mogadishu');
    });

    test('parses specialty tags from a comma-separated string', () {
      final provider = ServiceProvider.fromJson({
        'id': '4',
        'fullName': 'Ali Nur',
        'specialties': 'Pipes, Drains ,Taps',
      });
      expect(provider.specialties, ['Pipes', 'Drains', 'Taps']);
    });
  });
}
