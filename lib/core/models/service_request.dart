import 'json_utils.dart';
import 'request_status.dart';

/// A job as returned by both `/customer/requests` and `/provider/requests`.
class ServiceRequest {
  const ServiceRequest({
    required this.id,
    required this.status,
    required this.categoryName,
    required this.description,
    required this.address,
    this.referenceCode,
    this.categoryId,
    this.customerName,
    this.customerPhone,
    this.providerName,
    this.providerPhone,
    this.agreedPrice,
    this.currency = 'USD',
    this.latitude,
    this.longitude,
    this.preferredTime,
    this.createdAt,
    this.updatedAt,
    this.rejectionReason,
    this.hasReview = false,
  });

  final String id;
  final RequestStatus status;
  final String categoryName;
  final String description;
  final String address;
  final String? referenceCode;
  final String? categoryId;
  final String? customerName;
  final String? customerPhone;
  final String? providerName;
  final String? providerPhone;

  /// Price the admin negotiated off-platform; null until confirmed.
  final double? agreedPrice;
  final String currency;
  final double? latitude;
  final double? longitude;
  final String? preferredTime;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? rejectionReason;
  final bool hasReview;

  bool get canBeRated => status.isRatable && !hasReview;

  String get shortReference =>
      referenceCode ?? '#${id.length > 6 ? id.substring(0, 6) : id}'.toUpperCase();

  String get priceLabel => agreedPrice == null
      ? 'Price pending'
      : '$currency ${agreedPrice!.toStringAsFixed(2)}';

  factory ServiceRequest.fromJson(Map<String, dynamic> json) => ServiceRequest(
        id: asString(json, ['id', 'requestId', 'serviceRequestId']),
        status: RequestStatus.fromWire(
            asStringOrNull(json, ['status', 'requestStatus', 'state'])),
        categoryName: asString(json,
            ['serviceCategoryName', 'categoryName', 'category', 'serviceName'],
            fallback: 'Service'),
        description: asString(json, ['description', 'details', 'problem'],
            fallback: 'No description provided.'),
        address: asString(
            json, ['customerAddress', 'address', 'location', 'addressText'],
            fallback: 'Address not provided'),
        referenceCode: asStringOrNull(json, ['referenceCode', 'reference', 'code']),
        categoryId: asStringOrNull(json, ['serviceCategoryId', 'categoryId']),
        customerName: asStringOrNull(json, ['customerName', 'customer']),
        customerPhone:
            asStringOrNull(json, ['customerPhone', 'customerPhoneNumber']),
        providerName: asStringOrNull(
            json, ['assignedProviderName', 'providerName', 'provider']),
        providerPhone:
            asStringOrNull(json, ['providerPhone', 'providerPhoneNumber']),
        agreedPrice: asDoubleOrNull(json, ['agreedPrice', 'price', 'amount']),
        currency: asString(json, ['currency'], fallback: 'USD'),
        latitude: asDoubleOrNull(json, ['latitude', 'lat']),
        longitude: asDoubleOrNull(json, ['longitude', 'lng', 'lon']),
        preferredTime:
            asStringOrNull(json, ['preferredTime', 'timingPreference', 'timing']),
        createdAt: asDateOrNull(
            json, ['createdAtUtc', 'createdAt', 'createdOn', 'submittedAt']),
        updatedAt:
            asDateOrNull(json, ['updatedAtUtc', 'updatedAt', 'modifiedOn']),
        rejectionReason: asStringOrNull(json, ['rejectionReason', 'reason']),
        hasReview: asBool(json, ['hasReview', 'isReviewed', 'reviewed']),
      );
}

/// Payload for `POST /customer/requests`.
class CreateRequestPayload {
  const CreateRequestPayload({
    required this.categoryId,
    required this.description,
    required this.address,
    this.preferredTime,
    this.latitude,
    this.longitude,
    this.preferredProviderId,
  });

  final String categoryId;
  final String description;
  final String address;
  final String? preferredTime;
  final double? latitude;
  final double? longitude;
  final String? preferredProviderId;

  /// Mirrors the backend's `CreateServiceRequestDto`
  /// (`serviceCategoryId`, `customerAddress`, `latitude`, `longitude`).
  /// The remaining fields are not part of the DTO yet and are ignored by the
  /// server; they are sent so nothing changes here once it accepts them.
  Map<String, dynamic> toJson() => {
        'serviceCategoryId': categoryId,
        'customerAddress': address,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'description': description,
        if (preferredTime != null) 'preferredTime': preferredTime,
        if (preferredProviderId != null)
          'preferredProviderId': preferredProviderId,
      };
}
