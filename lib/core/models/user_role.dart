/// Roles carried in the JWT `role` claim.
enum UserRole {
  customer('Customer'),
  provider('Provider'),
  admin('Admin');

  const UserRole(this.wireValue);

  final String wireValue;

  static UserRole? tryParse(String? value) {
    if (value == null) return null;
    final normalised = value.trim().toLowerCase();
    for (final role in UserRole.values) {
      if (role.wireValue.toLowerCase() == normalised) return role;
    }
    // Tolerate role names such as "ServiceProvider" or "SkilledPerson".
    if (normalised.contains('provider') || normalised.contains('skilled')) {
      return UserRole.provider;
    }
    if (normalised.contains('customer') || normalised.contains('client')) {
      return UserRole.customer;
    }
    if (normalised.contains('admin')) return UserRole.admin;
    return null;
  }

  String get label => switch (this) {
        UserRole.customer => 'Customer',
        UserRole.provider => 'Skilled Person',
        UserRole.admin => 'Admin',
      };
}
