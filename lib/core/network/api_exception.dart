import 'package:dio/dio.dart';

/// A transport-agnostic error the UI can render directly.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.fieldErrors});

  final String message;
  final int? statusCode;

  /// Validation problems keyed by field name (ASP.NET `ValidationProblemDetails`).
  final Map<String, List<String>>? fieldErrors;

  bool get isUnauthorized => statusCode == 401;
  bool get isNetworkIssue => statusCode == null;

  factory ApiException.fromDio(DioException error) {
    final response = error.response;
    final status = response?.statusCode;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(
            'The server took too long to respond. Please try again.');
      case DioExceptionType.connectionError:
        return const ApiException(
            'Cannot reach the Xirfadle server. Check your internet connection.');
      case DioExceptionType.cancel:
        return const ApiException('Request cancelled.');
      case DioExceptionType.badCertificate:
        return const ApiException('The server certificate could not be trusted.');
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        break;
    }

    final data = response?.data;
    Map<String, List<String>>? fieldErrors;
    String? message;

    if (data is Map) {
      final map = data.cast<String, dynamic>();
      message = (map['message'] ??
              map['Message'] ??
              map['title'] ??
              map['Title'] ??
              map['detail'] ??
              map['error'])
          ?.toString();

      final errors = map['errors'] ?? map['Errors'];
      if (errors is Map) {
        fieldErrors = <String, List<String>>{};
        errors.forEach((key, value) {
          fieldErrors![key.toString()] = value is List
              ? value.map((e) => e.toString()).toList()
              : [value.toString()];
        });
        // ASP.NET's `title` here is the generic "One or more validation
        // errors occurred." — the field messages are what the user needs.
        final details = fieldErrors.values.expand((e) => e).toList();
        if (details.isNotEmpty) message = details.join('\n');
      }
    } else if (data is String && data.isNotEmpty && data.length < 300) {
      message = data;
    }

    message ??= switch (status ?? 0) {
      400 => 'The request was rejected. Please check your input.',
      401 => 'Your session has expired. Please sign in again.',
      403 => 'You do not have permission to perform this action.',
      404 => 'We could not find what you were looking for.',
      409 => 'This action conflicts with the current job status.',
      >= 500 => 'The Xirfadle server ran into a problem. Please try again.',
      _ => 'Something went wrong. Please try again.',
    };

    return ApiException(message, statusCode: status, fieldErrors: fieldErrors);
  }

  @override
  String toString() => message;
}
