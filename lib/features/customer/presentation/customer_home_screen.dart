import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/config/app_routes.dart';
import '../../../app/config/app_theme.dart';
import '../../../core/models/service_category.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../auth/application/auth_controller.dart';
import '../application/create_request_controller.dart';
import '../application/customer_providers.dart';
import 'category_list_view.dart';
import 'provider_card.dart';

/// `/customer/home` — service discovery entry point.
class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final categories = ref.watch(categoriesProvider);
    final providers = ref.watch(providerSearchProvider);
    final query = ref.watch(providerQueryProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(categoriesProvider);
            ref.invalidate(providerSearchProvider);
            await Future.wait([
              ref.read(categoriesProvider.future),
              ref.read(providerSearchProvider.future),
            ]);
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hello,',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant),
                                ),
                                Text(
                                  user?.fullName ?? 'there',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                          IconButton.filledTonal(
                            onPressed: () => context.push(AppRoutes.profile),
                            icon: const Icon(Icons.person_outline_rounded),
                            tooltip: 'Profile',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _SearchField(
                        initialValue: query.search,
                        onChanged: (value) => ref
                            .read(providerQueryProvider.notifier)
                            .update((state) => state.copyWith(search: value)),
                      ),
                      const SizedBox(height: 18),
                      const _RequestPromptCard(),
                      const SizedBox(height: 22),
                      _SectionHeader(
                        title: 'Browse services',
                        action: query.categoryId == null
                            ? null
                            : TextButton(
                                onPressed: () => ref
                                    .read(providerQueryProvider.notifier)
                                    .update((s) =>
                                        s.copyWith(clearCategory: true)),
                                child: const Text('Clear filter'),
                              ),
                      ),
                      const SizedBox(height: 10),
                      AsyncValueView<List<ServiceCategory>>(
                        value: categories,
                        onRetry: () => ref.invalidate(categoriesProvider),
                        loading: const _GridSkeleton(),
                        isEmpty: (items) => items.isEmpty,
                        empty: const EmptyStateView(
                          icon: Icons.category_outlined,
                          title: 'No services yet',
                          message:
                              'Service categories will appear here once an admin adds them.',
                        ),
                        data: (items) => CategoryListView(
                          categories: items,
                          selectedId: query.categoryId,
                          onSelected: (category) {
                            final isSelected = query.categoryId == category.id;
                            ref.read(providerQueryProvider.notifier).update(
                                  (s) => isSelected
                                      ? s.copyWith(clearCategory: true)
                                      : s.copyWith(categoryId: category.id),
                                );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      _SectionHeader(
                        title: query.categoryId == null
                            ? 'Top rated near you'
                            : 'Available for this service',
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
              providers.when(
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (error, _) => SliverToBoxAdapter(
                  child: ErrorRetryView(
                    message: error.toString(),
                    onRetry: () => ref.invalidate(providerSearchProvider),
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 30),
                        child: EmptyStateView(
                          icon: Icons.person_search_outlined,
                          title: 'No providers found',
                          message:
                              'Try a different service or clear your search.',
                        ),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    sliver: SliverList.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => ProviderCard(
                        provider: items[index],
                        onTap: () => context.push(
                            AppRoutes.providerDetailOf(items[index].id)),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.initialValue, required this.onChanged});

  final String initialValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      textInputAction: TextInputAction.search,
      onFieldSubmitted: onChanged,
      decoration: InputDecoration(
        hintText: 'Search plumbers, tutors, electricians...',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: initialValue.isEmpty
            ? null
            : IconButton(
                onPressed: () => onChanged(''),
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Clear search',
              ),
      ),
    );
  }
}

/// Primary call to action: file a job for admin review.
class _RequestPromptCard extends ConsumerWidget {
  const _RequestPromptCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.brandTeal, Color(0xFF00A896)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Need something fixed?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Describe the job. An admin confirms the price with you by phone.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.tonal(
                  onPressed: () {
                    ref.read(createRequestControllerProvider.notifier).reset();
                    context.push(AppRoutes.createRequest);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.brandTeal,
                    minimumSize: const Size(150, 42),
                  ),
                  child: const Text('Request a service'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        ?action,
      ],
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.02,
      ),
      itemBuilder: (context, _) => DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
