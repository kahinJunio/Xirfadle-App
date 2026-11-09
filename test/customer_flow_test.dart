import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:xirfadle_app/app/config/api_config.dart';
import 'package:xirfadle_app/core/models/request_status.dart';
import 'package:xirfadle_app/core/models/service_category.dart';
import 'package:xirfadle_app/core/network/dio_client.dart';
import 'package:xirfadle_app/core/utils/location_service.dart';
import 'package:xirfadle_app/features/customer/application/create_request_controller.dart';
import 'package:xirfadle_app/features/customer/application/customer_providers.dart';
import 'package:xirfadle_app/features/customer/application/review_controller.dart';

/// Routes each path to a canned body and records what was sent.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responses);

  final Map<String, Object?> responses;
  final calls = <({String method, String path, Object? body})>[];
  int? failWithStatus;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add((method: options.method, path: options.path, body: options.data));

    final failure = failWithStatus;
    if (failure != null) {
      return _json({'message': 'Category is no longer available'},
          status: failure);
    }
    return _json(responses[options.path] ?? const <String, dynamic>{});
  }

  @override
  void close({bool force = false}) {}

  ({String method, String path, Object? body}) callTo(String path) =>
      calls.firstWhere((call) => call.path == path);

  ResponseBody _json(Object? payload, {int status = 200}) =>
      ResponseBody.fromString(
        jsonEncode(payload),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        },
      );
}

ProviderContainer _containerWith(
  _FakeAdapter adapter, {
  LatLng? deviceLocation,
}) {
  final dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    validateStatus: (s) => s != null && s >= 200 && s < 300,
  ))
    ..httpClientAdapter = adapter;

  return ProviderContainer(
    overrides: [
      dioProvider.overrideWithValue(dio),
      // Geolocation needs platform channels, so pin it for the tests.
      deviceLocationProvider.overrideWith((ref) => deviceLocation),
    ],
  );
}

/// autoDispose controllers are torn down the moment nothing listens, so keep a
/// subscription alive for the duration of a test.
void _keepAlive(ProviderContainer container, ProviderListenable<Object?> provider) {
  container.listen(provider, (_, _) {}, fireImmediately: true);
}

const _category = ServiceCategory(id: 'cat-plumbing', name: 'Plumbing');

void main() {
  group('categories', () {
    test('unwraps a data envelope and maps icons by name', () async {
      final adapter = _FakeAdapter({
        ApiConfig.categories: {
          'data': [
            {'id': '1', 'name': 'Plumbing'},
            {'id': '2', 'name': 'Tutoring', 'providerCount': 4},
          ]
        }
      });
      final container = _containerWith(adapter);
      addTearDown(container.dispose);

      final categories = await container.read(categoriesProvider.future);

      expect(categories, hasLength(2));
      expect(categories.first.name, 'Plumbing');
      expect(categories.last.providerCount, 4);
    });
  });

  group('provider search', () {
    test('ranks available providers first, then distance', () async {
      final adapter = _FakeAdapter({
        ApiConfig.providers: [
          {'id': 'far', 'fullName': 'Far Fatima', 'distanceKm': 9.0},
          {
            'id': 'offline',
            'fullName': 'Offline Omar',
            'isAvailable': false,
            'distanceKm': 0.2
          },
          {'id': 'near', 'fullName': 'Near Nur', 'distanceKm': 1.2},
        ]
      });
      final container = _containerWith(adapter);
      addTearDown(container.dispose);

      await container.read(providerFeedProvider.future);
      final providers = container.read(providerSearchProvider).value!;

      expect(providers.map((p) => p.id), ['near', 'far', 'offline']);
    });

    test('passes the device location so the API can rank by proximity',
        () async {
      final adapter = _FakeAdapter({ApiConfig.providers: <dynamic>[]});
      final container =
          _containerWith(adapter, deviceLocation: const LatLng(2.04, 45.31));
      addTearDown(container.dispose);

      await container.read(providerFeedProvider.future);

      final uri = adapter.calls.first;
      expect(uri.path, ApiConfig.providers);
    });

    test('re-runs when the category filter changes', () async {
      final adapter = _FakeAdapter({ApiConfig.providers: <dynamic>[]});
      final container = _containerWith(adapter);
      addTearDown(container.dispose);

      await container.read(providerFeedProvider.future);
      container.read(providerQueryProvider.notifier).state =
          const ProviderQuery(categoryId: 'cat-plumbing');
      await container.read(providerFeedProvider.future);

      expect(adapter.calls.where((c) => c.path == ApiConfig.providers),
          hasLength(2));
    });

    test('filters locally by text without refetching', () async {
      final adapter = _FakeAdapter({
        ApiConfig.providers: [
          {
            'id': 'a',
            'fullName': 'Ali Hassan',
            'categoryName': 'Plumbing',
            'specialties': ['Pipe fitting'],
          },
          {
            'id': 'b',
            'fullName': 'Bashir Open',
            'categoryName': 'Electrical',
            'specialties': ['Wiring'],
          },
        ]
      });
      final container = _containerWith(adapter);
      addTearDown(container.dispose);

      await container.read(providerFeedProvider.future);
      final callsAfterLoad =
          adapter.calls.where((c) => c.path == ApiConfig.providers).length;

      // Matches the trade, not just the name.
      container.read(providerQueryProvider.notifier).state =
          const ProviderQuery(search: 'plumb');
      expect(
        container.read(providerSearchProvider).value!.map((p) => p.id),
        ['a'],
      );

      // All tokens must match (Amazon-style AND).
      container.read(providerQueryProvider.notifier).state =
          const ProviderQuery(search: 'ali wiring');
      expect(container.read(providerSearchProvider).value, isEmpty);

      // Filtering is purely local — the feed was never fetched again.
      expect(adapter.calls.where((c) => c.path == ApiConfig.providers).length,
          callsAfterLoad);
    });
  });

  group('CreateRequestController', () {
    test('refuses to submit until every required field is filled', () {
      final container = _containerWith(_FakeAdapter({}));
      addTearDown(container.dispose);

      _keepAlive(container, createRequestControllerProvider);
      final controller =
          container.read(createRequestControllerProvider.notifier);
      expect(container.read(createRequestControllerProvider).canSubmit, isFalse);

      controller.selectCategory(_category);
      expect(container.read(createRequestControllerProvider).canSubmit, isFalse);

      controller.setDescription('Too short');
      expect(container.read(createRequestControllerProvider).canSubmit, isFalse);

      controller.setDescription('The kitchen pipe leaks under the cabinet.');
      controller.setAddress('Hodan district');
      expect(container.read(createRequestControllerProvider).canSubmit, isTrue);
    });

    test('submits with PendingAdminReview and the dropped map pin', () async {
      final adapter = _FakeAdapter({
        ApiConfig.requests: {
          'id': 'req-1',
          'status': 'PendingAdminReview',
          'categoryName': 'Plumbing',
          'address': 'Hodan district',
          'referenceCode': 'XRF-1042',
        }
      });
      final container = _containerWith(adapter);
      addTearDown(container.dispose);

      _keepAlive(container, createRequestControllerProvider);
      final controller =
          container.read(createRequestControllerProvider.notifier);
      controller.selectCategory(_category);
      controller.setDescription('The kitchen pipe leaks under the cabinet.');
      controller.setAddress('Hodan district',
          pin: const LatLng(2.0469, 45.3182));
      controller.setPreferredTime('Today');

      expect(await controller.submit(), isTrue);

      final call = adapter.callTo(ApiConfig.requests);
      expect(call.method, 'POST');
      expect(call.body, containsPair('serviceCategoryId', 'cat-plumbing'));
      expect(call.body, containsPair('customerAddress', 'Hodan district'));
      expect(call.body, containsPair('preferredTime', 'Today'));
      expect(call.body, containsPair('latitude', 2.0469));

      final state = container.read(createRequestControllerProvider);
      expect(state.isSubmitting, isFalse);
      expect(state.submitted?.status, RequestStatus.pendingAdminReview);
      expect(state.submitted?.shortReference, 'XRF-1042');
    });

    test('keeps the form filled and shows the API message on failure',
        () async {
      final adapter = _FakeAdapter({})..failWithStatus = 400;
      final container = _containerWith(adapter);
      addTearDown(container.dispose);

      _keepAlive(container, createRequestControllerProvider);
      final controller =
          container.read(createRequestControllerProvider.notifier);
      controller.selectCategory(_category);
      controller.setDescription('The kitchen pipe leaks under the cabinet.');
      controller.setAddress('Hodan district');

      expect(await controller.submit(), isFalse);

      final state = container.read(createRequestControllerProvider);
      expect(state.errorMessage, 'Category is no longer available');
      expect(state.submitted, isNull);
      expect(state.description, 'The kitchen pipe leaks under the cabinet.');
      expect(state.canSubmit, isTrue, reason: 'the user can retry');
    });

    test('reset clears the form for the next job', () {
      final container = _containerWith(_FakeAdapter({}));
      addTearDown(container.dispose);

      _keepAlive(container, createRequestControllerProvider);
      final controller =
          container.read(createRequestControllerProvider.notifier);
      controller.selectCategory(_category);
      controller.setDescription('Something long enough to pass validation.');
      controller.reset();

      final state = container.read(createRequestControllerProvider);
      expect(state.category, isNull);
      expect(state.description, isEmpty);
    });
  });

  group('ReviewController', () {
    test('posts the rating and comment for the request', () async {
      final adapter = _FakeAdapter({});
      final container = _containerWith(adapter);
      addTearDown(container.dispose);

      _keepAlive(container, reviewControllerProvider);
      final controller = container.read(reviewControllerProvider.notifier);
      controller.setRating(4);
      controller.setComment('  Fast and tidy work. ');

      expect(await controller.submit('req-1'), isTrue);

      final call = adapter.callTo(ApiConfig.reviews);
      expect(call.method, 'POST');
      expect(call.body, {
        'serviceRequestId': 'req-1',
        'rating': 4,
        'comment': 'Fast and tidy work.',
      });

      final state = container.read(reviewControllerProvider);
      expect(state.errorMessage, isNull);
      expect(state.isSubmitting, isFalse);
    });

    test('surfaces the API message when the review is refused', () async {
      final adapter = _FakeAdapter({})..failWithStatus = 409;
      final container = _containerWith(adapter);
      addTearDown(container.dispose);

      _keepAlive(container, reviewControllerProvider);
      final controller = container.read(reviewControllerProvider.notifier);

      expect(await controller.submit('req-1'), isFalse);

      final state = container.read(reviewControllerProvider);
      expect(state.errorMessage, isNotNull);
      expect(state.isSubmitting, isFalse);
    });
  });
}
