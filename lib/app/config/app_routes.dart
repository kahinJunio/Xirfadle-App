/// Named route paths, kept in one place so guards and deep links agree.
class AppRoutes {
  const AppRoutes._();

  static const splash = '/';
  static const login = '/login';
  static const register = '/register';

  static const customerHome = '/customer/home';
  static const customerProviders = '/customer/providers';
  static const customerProviderDetail = '/customer/providers/:id';
  static const createRequest = '/customer/create-request';
  static const requestConfirmation = '/customer/request-confirmation';
  static const myRequests = '/customer/my-requests';
  static const customerRequestDetail = '/customer/my-requests/:id';

  static const providerHome = '/provider/home';
  static const providerRequests = '/provider/requests';
  static const providerActiveJob = '/provider/active-job';
  static const providerJobDetail = '/provider/requests/:id';

  static const profile = '/profile';

  static String providerDetailOf(String id) => '/customer/providers/$id';
  static String customerRequestDetailOf(String id) => '/customer/my-requests/$id';
  static String providerJobDetailOf(String id) => '/provider/requests/$id';
}
