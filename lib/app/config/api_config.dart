/// Backend connection settings for the Xirfadle ASP.NET Core Web API.
///
/// Override the host at build time without touching source:
///   flutter run --dart-define=API_BASE_URL=https://api.xirfadle.com/api/v1
class ApiConfig {
  const ApiConfig._();

  /// Root of the API, including the version segment.
  ///
  /// Defaults to the localtunnel host exposing the local backend. The tunnel
  /// URL changes each time localtunnel restarts, so pass the new one with
  /// `--dart-define=API_BASE_URL=...` rather than editing this file.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://xirfadle.loca.lt/api/v1',
  );

  /// localtunnel serves an HTML interstitial to anything that looks like a
  /// browser. This header opts out so the API answers with JSON.
  static const Map<String, String> defaultHeaders = {
    'Accept': 'application/json',
    'bypass-tunnel-reminder': 'true',
    'User-Agent': 'XirfadleApp/1.0',
  };

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

  /// POST only. The backend has no `GET /customer/requests`; listing goes
  /// through [myRequests] and single requests are picked out of that list.
  static const String requests = '/customer/requests';
  static const String myRequests = '/customer/requests/my-requests';

  // ---- Provider ---------------------------------------------------------
  /// The provider's dispatched jobs. There is no `GET /provider/requests`,
  /// and no by-id read: detail views filter this list.
  static const String assignedRequests = '/provider/requests/assigned';
  static String respondToRequest(String id) => '/provider/requests/$id/respond';
  static String startRequest(String id) => '/provider/requests/$id/start';
  static String completeRequest(String id) => '/provider/requests/$id/complete';

  // ---- Not exposed by the backend ---------------------------------------
  // The API surface has no route for these, so the features that used them
  // are disabled client-side rather than firing requests that 404:
  //   PATCH /customer/requests/{id}/cancel
  //   POST  /customer/reviews
  //   GET   /customer/providers/{id}/reviews
  //   PATCH /provider/availability
}
