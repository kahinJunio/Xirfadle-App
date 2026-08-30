import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xirfadle_app/app/config/api_config.dart';
import 'package:xirfadle_app/core/models/request_status.dart';
import 'package:xirfadle_app/core/models/service_request.dart';
import 'package:xirfadle_app/core/network/dio_client.dart';
import 'package:xirfadle_app/features/provider/application/provider_job_controller.dart';
import 'package:xirfadle_app/features/provider/presentation/incoming_request_card.dart';

/// Serves canned API responses and records the calls the app made.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.dispatched);

  List<Map<String, dynamic>> dispatched;
  final calls = <({String method, String path, Object? body})>[];

  /// Set to make the next call fail, exercising the error paths.
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
      return _json({'message': 'Job already taken'}, status: failure);
    }

    if (options.path == ApiConfig.providerRequests) return _json(dispatched);

    // respond / start / complete all answer with the updated job.
    return _json(dispatched.isEmpty ? <String, dynamic>{} : dispatched.first);
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

Map<String, dynamic> _job({
  String id = 'job-1',
  String status = 'Assigned',
}) =>
    {
      'id': id,
      'status': status,
      'categoryName': 'Plumbing',
      'description': 'The kitchen pipe is leaking badly.',
      'address': 'Hodan district, near the market',
      'customerName': 'Hodan Ali',
      'agreedPrice': 30,
      'currency': 'USD',
    };

ProviderContainer _containerWith(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    validateStatus: (s) => s != null && s >= 200 && s < 300,
  ))
    ..httpClientAdapter = adapter;
  return ProviderContainer(overrides: [dioProvider.overrideWithValue(dio)]);
}

/// Wraps a widget with a container whose network calls are never touched.
Widget _host(ProviderContainer container, Widget child) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  group('IncomingRequestCard', () {
    testWidgets('shows the admin price, status and both actions',
        (tester) async {
      final container = _containerWith(_FakeAdapter([]));
      addTearDown(container.dispose);

      await tester.pumpWidget(_host(
        container,
        IncomingRequestCard(request: ServiceRequest.fromJson(_job())),
      ));

      expect(find.text('Plumbing'), findsOneWidget);
      expect(find.text('USD 30.00'), findsOneWidget);
      expect(find.text('Awaiting Your Response'), findsOneWidget);
      expect(find.text('Hodan district, near the market'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
    });

    testWidgets('hides the actions once the job is accepted', (tester) async {
      final container = _containerWith(_FakeAdapter([]));
      addTearDown(container.dispose);

      await tester.pumpWidget(_host(
        container,
        IncomingRequestCard(
          request:
              ServiceRequest.fromJson(_job(status: 'AcceptedByProvider')),
        ),
      ));

      expect(find.text('Accepted'), findsOneWidget);
      expect(find.text('Accept'), findsNothing);
      expect(find.text('Reject'), findsNothing);
    });

    testWidgets('reads "Price pending" before the admin sets one',
        (tester) async {
      final container = _containerWith(_FakeAdapter([]));
      addTearDown(container.dispose);

      final job = _job()..remove('agreedPrice');
      await tester.pumpWidget(
          _host(container, IncomingRequestCard(request: ServiceRequest.fromJson(job))));

      expect(find.text('Price pending'), findsOneWidget);
    });
  });

  group('rejection dialog', () {
    testWidgets('stays disabled until a reason is chosen', (tester) async {
      String? captured;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  captured = await showRejectionDialog(context),
              child: const Text('open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final disabled = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Reject job'));
      expect(disabled.onPressed, isNull);

      await tester.tap(find.text('Too far from my area'));
      await tester.pumpAndSettle();

      final enabled = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Reject job'));
      expect(enabled.onPressed, isNotNull);

      await tester.tap(find.text('Reject job'));
      await tester.pumpAndSettle();

      expect(captured, 'Too far from my area');
    });

    testWidgets('requires free text when "Other" is picked', (tester) async {
      String? captured;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  captured = await showRejectionDialog(context),
              child: const Text('open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other'));
      await tester.pumpAndSettle();

      // An empty free-text box keeps the confirm button disabled.
      expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Reject job'))
            .onPressed,
        isNull,
      );

      await tester.enterText(find.byType(TextField), 'Family emergency');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reject job'));
      await tester.pumpAndSettle();

      expect(captured, 'Family emergency');
    });
  });

  group('dispatch feed', () {
    test('splits jobs into pending, active and completed buckets', () async {
      final adapter = _FakeAdapter([
        _job(id: 'a', status: 'Assigned'),
        _job(id: 'b', status: 'AcceptedByProvider'),
        _job(id: 'c', status: 'InProgress'),
        _job(id: 'd', status: 'Completed'),
      ]);
      final container = _containerWith(adapter);
      addTearDown(container.dispose);

      await container.read(dispatchedRequestsProvider.future);

      expect(container.read(pendingDispatchesProvider).map((r) => r.id), ['a']);
      expect(container.read(activeJobsProvider).map((r) => r.id), ['b', 'c']);
      expect(container.read(completedJobsProvider).map((r) => r.id), ['d']);
    });
  });

  group('JobActionController', () {
    test('accept PATCHes respond with AcceptedByProvider', () async {
      final adapter = _FakeAdapter([_job()]);
      final container = _containerWith(adapter);
      addTearDown(container.dispose);

      await container.read(dispatchedRequestsProvider.future);
      adapter.dispatched = [_job(status: 'AcceptedByProvider')];

      final error = await container
          .read(jobActionControllerProvider.notifier)
          .accept('job-1');
      expect(error, isNull);

      final call = adapter.callTo(ApiConfig.respondToRequest('job-1'));
      expect(call.method, 'PATCH');
      expect(call.body, containsPair('status', 'AcceptedByProvider'));

      // The feed was refreshed, so the job moved out of the pending bucket.
      expect(container.read(pendingDispatchesProvider), isEmpty);
      expect(container.read(activeJobsProvider), hasLength(1));
    });

    test('reject sends the reason for the admin to re-dispatch', () async {
      final adapter = _FakeAdapter([_job()]);
      final container = _containerWith(adapter);
      addTearDown(container.dispose);

      await container.read(dispatchedRequestsProvider.future);
      adapter.dispatched = [_job(status: 'RejectedByProvider')];

      final error = await container
          .read(jobActionControllerProvider.notifier)
          .reject('job-1', 'Too far from my area');
      expect(error, isNull);

      final call = adapter.callTo(ApiConfig.respondToRequest('job-1'));
      expect(call.body, containsPair('status', 'RejectedByProvider'));
      expect(call.body, containsPair('rejectionReason', 'Too far from my area'));
    });

    test('start then complete walks the job through the tracker', () async {
      final adapter = _FakeAdapter([_job(status: 'AcceptedByProvider')]);
      final container = _containerWith(adapter);
      addTearDown(container.dispose);

      await container.read(dispatchedRequestsProvider.future);

      adapter.dispatched = [_job(status: 'InProgress')];
      expect(
        await container
            .read(jobActionControllerProvider.notifier)
            .start('job-1'),
        isNull,
      );
      expect(adapter.callTo(ApiConfig.startRequest('job-1')).method, 'PATCH');
      expect(container.read(activeJobsProvider).single.status,
          RequestStatus.inProgress);

      adapter.dispatched = [_job(status: 'Completed')];
      expect(
        await container
            .read(jobActionControllerProvider.notifier)
            .complete('job-1'),
        isNull,
      );
      expect(adapter.callTo(ApiConfig.completeRequest('job-1')).method, 'PATCH');
      expect(container.read(activeJobsProvider), isEmpty);
      expect(container.read(completedJobsProvider), hasLength(1));
    });

    test('surfaces the API message when the job was already taken', () async {
      final adapter = _FakeAdapter([_job()]);
      final container = _containerWith(adapter);
      addTearDown(container.dispose);

      await container.read(dispatchedRequestsProvider.future);
      adapter.failWithStatus = 409;

      final error = await container
          .read(jobActionControllerProvider.notifier)
          .accept('job-1');
      expect(error, 'Job already taken');
      // The controller must release its lock even after a failure.
      expect(container.read(jobActionControllerProvider), isNull);
    });
  });

  group('AvailabilityController', () {
    test('keeps the optimistic value the server confirms', () async {
      final adapter = _FakeAdapter([]);
      final container = _containerWith(adapter);
      addTearDown(container.dispose);

      expect(
          container.read(availabilityControllerProvider).valueOrNull, isFalse);

      final error = await container
          .read(availabilityControllerProvider.notifier)
          .toggle(true);

      expect(error, isNull);
      expect(container.read(availabilityControllerProvider).valueOrNull, isTrue);
      expect(adapter.callTo(ApiConfig.availability).body,
          containsPair('isAvailable', true));
    });

    test('rolls back when the API rejects the change', () async {
      final adapter = _FakeAdapter([])..failWithStatus = 500;
      final container = _containerWith(adapter);
      addTearDown(container.dispose);

      final error = await container
          .read(availabilityControllerProvider.notifier)
          .toggle(true);

      expect(error, isNotNull);
      expect(
          container.read(availabilityControllerProvider).valueOrNull, isFalse);
    });
  });
}
