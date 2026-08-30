import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/config/app_routes.dart';
import '../../../app/config/app_theme.dart';
import '../../../core/models/service_request.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../auth/application/auth_controller.dart';
import '../application/provider_job_controller.dart';
import 'incoming_request_card.dart';

/// `/provider/home` — duty toggle, dispatch banner and job summary.
class ProviderDashboard extends ConsumerWidget {
  const ProviderDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final requests = ref.watch(dispatchedRequestsProvider);
    final pending = ref.watch(pendingDispatchesProvider);
    final active = ref.watch(activeJobsProvider);
    final completed = ref.watch(completedJobsProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dispatchedRequestsProvider);
            await ref.read(dispatchedRequestsProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Skilled person',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                        Text(
                          user?.fullName ?? 'Welcome',
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
              const SizedBox(height: 18),
              const DutyToggleCard(),
              if (pending.isNotEmpty) ...[
                const SizedBox(height: 18),
                _DispatchBanner(count: pending.length),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      icon: Icons.notifications_active_rounded,
                      label: 'Awaiting reply',
                      value: '${pending.length}',
                      color: AppTheme.statusPending,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricTile(
                      icon: Icons.handyman_rounded,
                      label: 'Active jobs',
                      value: '${active.length}',
                      color: AppTheme.statusActive,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricTile(
                      icon: Icons.task_alt_rounded,
                      label: 'Completed',
                      value: '${completed.length}',
                      color: AppTheme.statusDone,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: Text('New dispatches',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.providerRequests),
                    child: const Text('See all'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AsyncValueView<List<ServiceRequest>>(
                value: requests,
                onRetry: () => ref.invalidate(dispatchedRequestsProvider),
                loading: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                data: (_) {
                  if (pending.isEmpty) {
                    return const EmptyStateView(
                      icon: Icons.inbox_outlined,
                      title: 'No new dispatches',
                      message:
                          'Stay online and admins will send jobs your way.',
                    );
                  }
                  return Column(
                    children: [
                      for (final request in pending.take(3)) ...[
                        IncomingRequestCard(
                          request: request,
                          onTap: () => context
                              .push(AppRoutes.providerJobDetailOf(request.id)),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
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

/// Online/offline switch that tells admins whether to dispatch.
class DutyToggleCard extends ConsumerWidget {
  const DutyToggleCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final availability = ref.watch(availabilityControllerProvider);
    final isOnline = availability.valueOrNull ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: isOnline ? AppTheme.brandTeal : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOnline
              ? AppTheme.brandTeal
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isOnline
                  ? Colors.white.withValues(alpha: 0.2)
                  : theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOnline ? Icons.bolt_rounded : Icons.bedtime_outlined,
              color: isOnline ? Colors.white : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOnline ? 'On duty' : 'Off duty',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isOnline ? Colors.white : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isOnline
                      ? 'Admins can dispatch jobs to you'
                      : 'You will not receive new dispatches',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isOnline
                        ? Colors.white.withValues(alpha: 0.85)
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isOnline,
            onChanged: (value) async {
              final error = await ref
                  .read(availabilityControllerProvider.notifier)
                  .toggle(value);
              if (error != null && context.mounted) {
                showAppSnackBar(context, error, isError: true);
              }
            },
            activeThumbColor: Colors.white,
            activeTrackColor: Colors.white.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}

/// Prominent banner for dispatches awaiting a response.
class _DispatchBanner extends StatelessWidget {
  const _DispatchBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.statusPending.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppTheme.statusPending.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_rounded,
              color: AppTheme.statusPending),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              count == 1
                  ? '1 job is waiting for your answer'
                  : '$count jobs are waiting for your answer',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          TextButton(
            onPressed: () => context.go(AppRoutes.providerRequests),
            child: const Text('Review'),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

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
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(value,
              style: theme.textTheme.titleMedium
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
