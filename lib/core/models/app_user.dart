import 'json_utils.dart';
import 'user_role.dart';

/// The authenticated principal, assembled from the JWT claims and, when the
/// API returns one, the `/auth/me` profile payload.
class AppUser {
  const AppUser({
    required this.id,
    required this.phoneNumber,
    required this.fullName,
    required this.roles,
    required this.activeRole,
  });

  final String id;
  final String phoneNumber;
  final String fullName;
  final List<UserRole> roles;

  /// Which dashboard the app is currently showing. For dual-role accounts the
  /// user can flip this from the profile screen.
  final UserRole activeRole;

  bool get isDualRole =>
      roles.contains(UserRole.customer) && roles.contains(UserRole.provider);

  bool get isProvider => activeRole == UserRole.provider;

  String get initials {
    final parts =
        fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  AppUser copyWith({
    String? fullName,
    List<UserRole>? roles,
    UserRole? activeRole,
  }) =>
      AppUser(
        id: id,
        phoneNumber: phoneNumber,
        fullName: fullName ?? this.fullName,
        roles: roles ?? this.roles,
        activeRole: activeRole ?? this.activeRole,
      );

  /// Builds a user from decoded JWT claims, tolerating both short claim names
  /// and the full Microsoft claim URIs emitted by ASP.NET Core Identity.
  factory AppUser.fromClaims(Map<String, dynamic> claims) {
    const nameIdUri =
        'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier';
    const nameUri = 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name';
    const roleUri =
        'http://schemas.microsoft.com/ws/2008/06/identity/claims/role';
    const phoneUri =
        'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/mobilephone';

    final rawRoles = <String>[
      ...asStringList(claims, ['role', 'roles']),
      ...asStringList(claims, [roleUri]),
    ];
    final roles = rawRoles
        .map(UserRole.tryParse)
        .whereType<UserRole>()
        .toSet()
        .toList();

    return AppUser(
      id: asString(claims, ['sub', 'userId', 'id', nameIdUri]),
      phoneNumber: asString(claims, ['phoneNumber', 'phone', phoneUri]),
      fullName: asString(claims, ['fullName', 'name', 'unique_name', nameUri],
          fallback: 'Xirfadle User'),
      roles: roles.isEmpty ? const [UserRole.customer] : roles,
      activeRole: roles.contains(UserRole.customer)
          ? UserRole.customer
          : (roles.firstOrNull ?? UserRole.customer),
    );
  }

  /// Merges a `/auth/me` payload over the claim-derived user.
  AppUser mergeProfile(Map<String, dynamic> json) {
    if (json.isEmpty) return this;
    final profileRoles = asStringList(json, ['roles', 'role'])
        .map(UserRole.tryParse)
        .whereType<UserRole>()
        .toList();
    return AppUser(
      id: asString(json, ['id', 'userId'], fallback: id),
      phoneNumber:
          asString(json, ['phoneNumber', 'phone'], fallback: phoneNumber),
      fullName: asString(json, ['fullName', 'name'], fallback: fullName),
      roles: profileRoles.isEmpty ? roles : profileRoles,
      activeRole: (profileRoles.isEmpty ? roles : profileRoles)
              .contains(activeRole)
          ? activeRole
          : ((profileRoles.isEmpty ? roles : profileRoles).firstOrNull ??
              activeRole),
    );
  }
}
