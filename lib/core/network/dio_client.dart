import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config/api_config.dart';
import '../storage/secure_storage_service.dart';
import 'api_exception.dart';
import 'api_interceptors.dart';
import 'session_gate.dart';

/// Thin wrapper over Dio that surfaces [ApiException] instead of
/// [DioException] and unwraps response bodies.
class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  Dio get raw => _dio;

  Future<T> get<T>(String path, {Map<String, dynamic>? query}) =>
      _send<T>(() => _dio.get<T>(path, queryParameters: query));

  Future<T> post<T>(String path, {Object? data}) =>
      _send<T>(() => _dio.post<T>(path, data: data));

  Future<T> patch<T>(String path, {Object? data}) =>
      _send<T>(() => _dio.patch<T>(path, data: data));

  Future<T> put<T>(String path, {Object? data}) =>
      _send<T>(() => _dio.put<T>(path, data: data));

  Future<T> delete<T>(String path, {Object? data}) =>
      _send<T>(() => _dio.delete<T>(path, data: data));

  Future<T> _send<T>(Future<Response<T>> Function() call) async {
    try {
      final response = await call();
      return response.data as T;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

/// Builds the shared Dio instance. [onSessionExpired] fires when a refresh
/// attempt fails and the user must sign in again.
Dio buildDio({
  required SecureStorageService storage,
  required Future<void> Function() onSessionExpired,
}) {
  final options = BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: ApiConfig.connectTimeout,
    receiveTimeout: ApiConfig.receiveTimeout,
    contentType: Headers.jsonContentType,
    responseType: ResponseType.json,
    headers: ApiConfig.defaultHeaders,
    // Let the interceptors decide what counts as an error.
    validateStatus: (status) => status != null && status >= 200 && status < 300,
  );

  final dio = Dio(options);
  // Separate client for refresh + retry, so those calls skip AuthInterceptor.
  final refreshClient = Dio(options);

  dio.interceptors.add(AuthInterceptor(
    storage: storage,
    refreshClient: refreshClient,
    onSessionExpired: onSessionExpired,
  ));
  if (kDebugMode) {
    dio.interceptors.add(LoggingInterceptor());
    refreshClient.interceptors.add(LoggingInterceptor());
  }
  return dio;
}

final dioProvider = Provider<Dio>((ref) {
  final gate = ref.watch(sessionGateProvider);
  return buildDio(
    storage: ref.watch(secureStorageProvider),
    onSessionExpired: () async => gate.notifyExpired(),
  );
});

final apiClientProvider =
    Provider<ApiClient>((ref) => ApiClient(ref.watch(dioProvider)));
