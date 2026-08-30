import 'package:flutter/material.dart';

import '../../../core/models/service_category.dart';

/// Visual category grid shown on the customer home screen.
class CategoryListView extends StatelessWidget {
  const CategoryListView({
    super.key,
    required this.categories,
    required this.onSelected,
    this.selectedId,
  });

  final List<ServiceCategory> categories;
  final ValueChanged<ServiceCategory> onSelected;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Keep tiles a comfortable size on phones and tablets alike.
        final columns = (constraints.maxWidth / 150).floor().clamp(2, 5);
        return GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: categories.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.02,
          ),
          itemBuilder: (context, index) {
            final category = categories[index];
            return CategoryTile(
              category: category,
              selected: category.id == selectedId,
              onTap: () => onSelected(category),
            );
          },
        );
      },
    );
  }
}

class CategoryTile extends StatelessWidget {
  const CategoryTile({
    super.key,
    required this.category,
    required this.onTap,
    this.selected = false,
  });

  final ServiceCategory category;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: selected ? 0.22 : 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(category.icon, size: 24, color: scheme.primary),
            ),
            const SizedBox(height: 10),
            Text(
              category.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            if (category.providerCount > 0) ...[
              const SizedBox(height: 3),
              Text(
                '${category.providerCount} available',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
