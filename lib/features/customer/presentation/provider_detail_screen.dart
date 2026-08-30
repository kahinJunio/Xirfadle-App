import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/config/app_routes.dart';
import '../../../core/models/service_provider.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/rating_stars.dart';
import '../application/create_request_controller.dart';
import '../application/customer_providers.dart';
import 'provider_card.dart';

/// `/customer/providers/:id` — bio, rating, review count and specialty tags.
class ProviderDetailScreen extends ConsumerWidget {
  const ProviderDetailScreen({super.key, required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(providerDetailProvider(providerId));

    return Scaffold(
      appBar: AppBar(title: const Text('Provider')),
      body: AsyncValueView<ServiceProvider>(
        value: detail,
        onRetry: () => ref.invalidate(providerDetailProvider(providerId)),
        data: (provider) => _ProviderDetailBody(provider: provider),
      ),
      bottomNavigationBar: detail.maybeWhen(
        data: (provider) => SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton.icon(
            onPressed: () {
              // Pre-fill the request form with this provider and their trade.
              final controller =
                  ref.read(createRequestControllerProvider.notifier);
              controller.reset();
              controller.setPreferredProvider(provider.id);
              final categories =
                  ref.read(categoriesProvider).valueOrNull ?? const [];
              final match = categories
                  .where((c) =>
                      c.id == provider.categoryId ||
                      c.name == provider.categoryName)
                  .firstOrNull;
              if (match != null) controller.selectCategory(match);
              context.push(AppRoutes.createRequest);
            },
            icon: const Icon(Icons.post_add_rounded),
            label: Text('Request ${provider.fullName.split(' ').first}'),
          ),
        ),
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }
}

class _ProviderDetailBody extends ConsumerWidget {
  const _ProviderDetailBody({required this.provider});

  final ServiceProvider provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reviews = ref.watch(providerReviewsProvider(provider.id));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProviderAvatar(provider: provider, size: 76),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.fullName,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  if (provider.categoryName != null) ...[
                    const SizedBox(height: 3),
                    Text(provider.categoryName!,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: scheme.primary)),
                  ],
                  const SizedBox(height: 8),
                  RatingStars(
                    rating: provider.rating,
                    reviewCount: provider.reviewCount,
                    size: 17,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.task_alt_rounded,
                label: 'Jobs done',
                value: '${provider.completedJobs}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                icon: Icons.reviews_outlined,
                label: 'Reviews',
                value: '${provider.reviewCount}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                icon: Icons.place_outlined,
                label: 'Distance',
                value: provider.distanceKm == null
                    ? '—'
                    : '${provider.distanceKm!.toStringAsFixed(1)} km',
              ),
            ),
          ],
        ),
        if (provider.bio != null) ...[
          const SizedBox(height: 24),
          Text('About',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            provider.bio!,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ],
        if (provider.specialties.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Specialties',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in provider.specialties)
                Chip(
                  label: Text(tag),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: scheme.surface,
                ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        Text('Customer reviews',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        reviews.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => const SizedBox.shrink(),
          data: (items) {
            if (items.isEmpty) {
              return Text(
                'No reviews yet. Be the first to hire and rate.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              );
            }
            return Column(
              children: [
                for (final review in items) ...[
                  _ReviewTile(review: review),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(height: 6),
          Text(value,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final ProviderReview review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    review.customerName,
                    style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  formatRelative(review.createdAt),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 6),
            RatingStars(
                rating: review.rating.toDouble(), size: 14, showValue: false),
            if (review.comment != null) ...[
              const SizedBox(height: 8),
              Text(review.comment!,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
            ],
          ],
        ),
      ),
    );
  }
}
