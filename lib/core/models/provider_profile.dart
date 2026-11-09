import 'dart:convert';

import 'json_utils.dart';

/// The editable professional details a skilled person keeps about themselves:
/// their trade, a short bio, the specialties they advertise and where they
/// work. The backend exposes no provider-profile route yet, so this is
/// persisted on the device; the shape mirrors what a future
/// `GET/PATCH /provider/profile` would exchange, so wiring one in later is a
/// drop-in.
class ProviderProfile {
  const ProviderProfile({
    required this.userId,
    this.bio,
    this.categoryId,
    this.categoryName,
    this.city,
    this.specialties = const [],
  });

  /// Owner of the profile. Keeps profiles from different accounts on the same
  /// device apart.
  final String userId;
  final String? bio;
  final String? categoryId;
  final String? categoryName;
  final String? city;
  final List<String> specialties;

  /// A freshly registered provider with nothing filled in yet.
  factory ProviderProfile.empty(String userId) =>
      ProviderProfile(userId: userId);

  bool get isComplete =>
      (categoryId != null && categoryId!.isNotEmpty) &&
      (bio != null && bio!.trim().isNotEmpty);

  ProviderProfile copyWith({
    String? bio,
    String? categoryId,
    String? categoryName,
    String? city,
    List<String>? specialties,
  }) =>
      ProviderProfile(
        userId: userId,
        bio: bio ?? this.bio,
        categoryId: categoryId ?? this.categoryId,
        categoryName: categoryName ?? this.categoryName,
        city: city ?? this.city,
        specialties: specialties ?? this.specialties,
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        if (bio != null) 'bio': bio,
        if (categoryId != null) 'categoryId': categoryId,
        if (categoryName != null) 'categoryName': categoryName,
        if (city != null) 'city': city,
        'specialties': specialties,
      };

  factory ProviderProfile.fromJson(Map<String, dynamic> json) =>
      ProviderProfile(
        userId: asString(json, ['userId', 'id']),
        bio: asStringOrNull(json, ['bio', 'about', 'description']),
        categoryId: asStringOrNull(json, ['categoryId', 'serviceCategoryId']),
        categoryName:
            asStringOrNull(json, ['categoryName', 'category', 'serviceName']),
        city: asStringOrNull(json, ['city', 'town', 'district']),
        specialties: asStringList(json, ['specialties', 'tags', 'skills']),
      );

  String encode() => jsonEncode(toJson());

  static ProviderProfile decode(String source, {required String fallbackId}) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) {
        return ProviderProfile.fromJson(decoded);
      }
    } catch (_) {
      // Corrupt or legacy payload — fall through to an empty profile.
    }
    return ProviderProfile.empty(fallbackId);
  }
}
