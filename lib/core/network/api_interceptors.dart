import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../app/config/api_config.dart';
import '../storage/secure_storage_service.dart';

/// Injects the JWT on every outbound call and transparently refreshes it once
/// when the API answers 401.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.storage,
    required this.refreshClient,
    required this.onSessionExpired,
  });

  final SecureStorageService storage;

  /// A bare Dio without this interceptor, so refreshing cannot recurse.
  final Dio refreshClient;
  final Future<void> Function() onSessionExpired;

  /// Shared across concurrent 401s so only one refresh call is ever in flight.
  Future<String?>? _refreshInFlight;

  static const _retriedFlag = 'xirfadle.retried';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra['skipAuth'] != true) {
      final token = await storage.readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    final isAuthCall = request.path.contains(ApiConfig.refresh) ||
        request.path.contains(ApiConfig.login) ||
        request.extra['skipAuth'] == true;

    if (err.response?.statusCode != 401 ||
        isAuthCall ||
        request.extra[_retriedFlag] == true) {
      return handler.next(err);
    }

    final token = await (_refreshInFlight ??= _refreshToken());
    if (token == null) {
      await onSessionExpired();
      return handler.next(err);
    }

    try {
      request.extra[_retriedFlag] = true;
      request.headers['Authorization'] = 'Bearer $token';
      final response = await refreshClient.fetch<dynamic>(request);
      return handler.resolve(response);
    } on DioException catch (retryError) {
      return handler.next(retryError);
    }
  }

  Future<String?> _refreshToken() async {
    try {
      final refreshToken = await storage.readRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) return null;

      final response = await refreshClient.post<dynamic>(
        ApiConfig.refresh,
        data: {'refreshToken': refreshToken},
        options: Options(extra: {'skipAuth': true}),
      );

      final data = response.data;
      if (data is! Map) return null;
      final map = data.cast<String, dynamic>();
      final access =
          (map['accessToken'] ?? map['token'] ?? map['jwt'])?.toString();
      if (access == null || access.isEmpty) return null;

      await storage.saveTokens(
        accessToken: access,
        refreshToken: (map['refreshToken'] ?? refreshToken)?.toString(),
      );
      return access;
    } on DioException {
      return null;
    } finally {
      // Let the next 401 start a fresh attempt.
      _refreshInFlight = null;
    }
  }
}

/// Compact request/response logging, debug builds only.
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('→ ${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    debugPrint(
        '← ${response.statusCode} ${response.requestOptions.uri.path}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint(
        '✗ ${err.response?.statusCode ?? err.type.name} ${err.requestOptions.uri.path}');
    handler.next(err);
  }
}
