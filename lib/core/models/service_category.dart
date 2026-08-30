import 'package:flutter/material.dart';

import 'json_utils.dart';

class ServiceCategory {
  const ServiceCategory({
    required this.id,
    required this.name,
    this.description,
    this.iconName,
    this.providerCount = 0,
  });

  final String id;
  final String name;
  final String? description;
  final String? iconName;
  final int providerCount;

  factory ServiceCategory.fromJson(Map<String, dynamic> json) =>
      ServiceCategory(
        id: asString(json, ['id', 'categoryId']),
        name: asString(json, ['name', 'title', 'categoryName']),
        description: asStringOrNull(json, ['description']),
        iconName: asStringOrNull(json, ['icon', 'iconName']),
        providerCount: asInt(json, ['providerCount', 'totalProviders']),
      );

  /// Maps the backend icon hint (or the category name) onto a Material icon.
  IconData get icon {
    final key = (iconName ?? name).toLowerCase();
    if (key.contains('plumb') || key.contains('water')) {
      return Icons.plumbing_rounded;
    }
    if (key.contains('electric') || key.contains('power')) {
      return Icons.electrical_services_rounded;
    }
    if (key.contains('tutor') || key.contains('teach') || key.contains('edu')) {
      return Icons.school_rounded;
    }
    if (key.contains('clean')) return Icons.cleaning_services_rounded;
    if (key.contains('paint')) return Icons.format_paint_rounded;
    if (key.contains('carpen') || key.contains('wood')) {
      return Icons.carpenter_rounded;
    }
    if (key.contains('mechanic') || key.contains('car') || key.contains('auto')) {
      return Icons.car_repair_rounded;
    }
    if (key.contains('cook') || key.contains('chef') || key.contains('cater')) {
      return Icons.restaurant_rounded;
    }
    if (key.contains('garden') || key.contains('landscap')) {
      return Icons.yard_rounded;
    }
    if (key.contains('move') || key.contains('transport')) {
      return Icons.local_shipping_rounded;
    }
    if (key.contains('tailor') || key.contains('sew')) {
      return Icons.checkroom_rounded;
    }
    if (key.contains('ac') || key.contains('cool') || key.contains('hvac')) {
      return Icons.ac_unit_rounded;
    }
    if (key.contains('weld') || key.contains('metal')) {
      return Icons.construction_rounded;
    }
    if (key.contains('tech') || key.contains('comput') || key.contains('it')) {
      return Icons.computer_rounded;
    }
    return Icons.handyman_rounded;
  }
}
