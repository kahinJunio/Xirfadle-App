import 'package:flutter/material.dart';

import '../../../app/config/app_theme.dart';
import '../../../core/models/service_provider.dart';
import '../../../core/widgets/rating_stars.dart';

/// Row used in the provider list and in search results.
class ProviderCard extends StatelessWidget {
  const ProviderCard({super.key, required this.provider, required this.onTap});

  final ServiceProvider provider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProviderAvatar(provider: provider, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            provider.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (provider.isAvailable) const _AvailableDot(),
                      ],
                    ),
                    if (provider.categoryName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        provider.categoryName!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.primary),
                      ),
                    ],
                    const SizedBox(height: 8),
                    RatingStars(
                      rating: provider.rating,
                      reviewCount: provider.reviewCount,
                      size: 15,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.place_outlined,
                            size: 14, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            provider.distanceLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                        if (provider.completedJobs > 0) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.task_alt_rounded,
                              size: 14, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            '${provider.completedJobs} jobs',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class ProviderAvatar extends StatelessWidget {
  const ProviderAvatar({super.key, required this.provider, this.size = 48});

  final ServiceProvider provider;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final photo = provider.photoUrl;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        image: photo != null
            ? DecorationImage(image: NetworkImage(photo), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: photo != null
          ? null
          : Text(
              provider.initials,
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.34,
              ),
            ),
    );
  }
}

class _AvailableDot extends StatelessWidget {
  const _AvailableDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.statusActive.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 7, color: AppTheme.statusActive),
          SizedBox(width: 5),
          Text(
            'Online',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.statusActive,
            ),
          ),
        ],
      ),
    );
  }
}
