import 'json_utils.dart';

/// A skilled person as seen from the customer side.
class ServiceProvider {
  const ServiceProvider({
    required this.id,
    required this.fullName,
    this.bio,
    this.categoryId,
    this.categoryName,
    this.rating = 0,
    this.reviewCount = 0,
    this.completedJobs = 0,
    this.isAvailable = false,
    this.distanceKm,
    this.city,
    this.specialties = const [],
    this.photoUrl,
    this.phoneNumber,
  });

  final String id;
  final String fullName;
  final String? bio;
  final String? categoryId;
  final String? categoryName;
  final double rating;
  final int reviewCount;
  final int completedJobs;
  final bool isAvailable;
  final double? distanceKm;
  final String? city;
  final List<String> specialties;
  final String? photoUrl;
  final String? phoneNumber;

  String get initials {
    final parts =
        fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  String get distanceLabel {
    final km = distanceKm;
    if (km == null) return city ?? '—';
    if (km < 1) return '${(km * 1000).round()} m away';
    return '${km.toStringAsFixed(1)} km away';
  }

  factory ServiceProvider.fromJson(Map<String, dynamic> json) =>
      ServiceProvider(
        id: asString(json, ['id', 'providerId', 'userId']),
        fullName: asString(json, ['fullName', 'name', 'providerName'],
            fallback: 'Unnamed Provider'),
        bio: asStringOrNull(json, ['bio', 'about', 'description']),
        categoryId: asStringOrNull(json, ['categoryId']),
        categoryName:
            asStringOrNull(json, ['categoryName', 'category', 'serviceName']),
        rating: asDouble(json, ['rating', 'averageRating', 'avgRating']),
        reviewCount: asInt(json, ['reviewCount', 'totalReviews', 'reviews']),
        completedJobs:
            asInt(json, ['completedJobs', 'totalJobs', 'jobsCompleted']),
        isAvailable: asBool(json, ['isAvailable', 'available'], fallback: true),
        distanceKm: asDoubleOrNull(json, ['distanceKm', 'distance']),
        city: asStringOrNull(json, ['city', 'town', 'district']),
        specialties: asStringList(json, ['specialties', 'tags', 'skills']),
        photoUrl: asStringOrNull(json, ['photoUrl', 'avatarUrl', 'imageUrl']),
        phoneNumber: asStringOrNull(json, ['phoneNumber', 'phone']),
      );
}

/// A single customer review shown on the provider detail screen.
class ProviderReview {
  const ProviderReview({
    required this.id,
    required this.customerName,
    required this.rating,
    this.comment,
    this.createdAt,
  });

  final String id;
  final String customerName;
  final int rating;
  final String? comment;
  final DateTime? createdAt;

  factory ProviderReview.fromJson(Map<String, dynamic> json) => ProviderReview(
        id: asString(json, ['id', 'reviewId']),
        customerName: asString(json, ['customerName', 'reviewerName', 'name'],
            fallback: 'Customer'),
        rating: asInt(json, ['rating', 'stars'], fallback: 5),
        comment: asStringOrNull(json, ['comment', 'text', 'review']),
        createdAt:
            asDateOrNull(json, ['createdAtUtc', 'createdAt', 'date', 'createdOn']),
      );
}
