/// Backend connection settings for the Xirfadle ASP.NET Core Web API.
///
/// Override the host at build time without touching source:
///   flutter run --dart-define=API_BASE_URL=https://api.xirfadle.com
class ApiConfig {
  const ApiConfig._();

  /// Root of the API, including the version segment.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.xirfadle.com/api/v1',
  );

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // ---- Auth -------------------------------------------------------------
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refresh = '/auth/refresh';
  static const String me = '/auth/me';

  // ---- Customer ---------------------------------------------------------
  static const String categories = '/customer/categories';
  static const String providers = '/customer/providers';
  static String providerDetail(String id) => '/customer/providers/$id';
  static const String requests = '/customer/requests';
  static const String reviews = '/customer/reviews';

  // ---- Provider ---------------------------------------------------------
  static const String providerRequests = '/provider/requests';
  static const String availability = '/provider/availability';
  static String respondToRequest(String id) => '/provider/requests/$id/respond';
  static String startRequest(String id) => '/provider/requests/$id/start';
  static String completeRequest(String id) => '/provider/requests/$id/complete';
}
