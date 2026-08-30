import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/config/app_routes.dart';
import '../../../core/models/request_status.dart';
import '../../../core/models/service_request.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/status_badge.dart';
import '../application/create_request_controller.dart';
import '../application/customer_providers.dart';
import 'review_modal.dart';

/// `/customer/my-requests` — live status tracker for submitted jobs.
class CustomerRequestHistoryScreen extends ConsumerStatefulWidget {
  const CustomerRequestHistoryScreen({super.key});

  @override
  ConsumerState<CustomerRequestHistoryScreen> createState() =>
      _CustomerRequestHistoryScreenState();
}

class _CustomerRequestHistoryScreenState
    extends ConsumerState<CustomerRequestHistoryScreen> {
  _RequestFilter _filter = _RequestFilter.active;

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(myRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My requests'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(myRequestsProvider),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: SegmentedButton<_RequestFilter>(
              segments: const [
                ButtonSegment(
                    value: _RequestFilter.active, label: Text('Active')),
                ButtonSegment(
                    value: _RequestFilter.completed, label: Text('Completed')),
                ButtonSegment(value: _RequestFilter.all, label: Text('All')),
              ],
              selected: {_filter},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  setState(() => _filter = selection.first),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ref.read(createRequestControllerProvider.notifier).reset();
          context.push(AppRoutes.createRequest);
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New request'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myRequestsProvider);
          await ref.read(myRequestsProvider.future);
        },
        child: AsyncValueView<List<ServiceRequest>>(
          value: requests,
          onRetry: () => ref.invalidate(myRequestsProvider),
          data: (items) {
            final visible = _filter.apply(items);
            if (visible.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  EmptyStateView(
                    icon: Icons.inbox_outlined,
                    title: _filter == _RequestFilter.completed
                        ? 'No completed jobs yet'
                        : 'No requests yet',
                    message:
                        'Submit a job and track the admin review right here.',
                    action: FilledButton.tonal(
                      onPressed: () {
                        ref
                            .read(createRequestControllerProvider.notifier)
                            .reset();
                        context.push(AppRoutes.createRequest);
                      },
                      child: const Text('Request a service'),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: visible.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => RequestStatusCard(
                request: visible[index],
                onTap: () => context.push(
                    AppRoutes.customerRequestDetailOf(visible[index].id)),
                onRate: () => _rate(visible[index]),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _rate(ServiceRequest request) async {
    final submitted = await showReviewModal(context, request);
    if (submitted && mounted) ref.invalidate(myRequestsProvider);
  }
}

enum _RequestFilter {
  active,
  completed,
  all;

  List<ServiceRequest> apply(List<ServiceRequest> requests) => switch (this) {
        _RequestFilter.active =>
          requests.where((r) => !r.status.isTerminal).toList(),
        _RequestFilter.completed =>
          requests.where((r) => r.status.isTerminal).toList(),
        _RequestFilter.all => requests,
      };
}

/// One job in the tracker, with its status badge and rate action.
class RequestStatusCard extends StatelessWidget {
  const RequestStatusCard({
    super.key,
    required this.request,
    required this.onTap,
    this.onRate,
  });

  final ServiceRequest request;
  final VoidCallback onTap;
  final VoidCallback? onRate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.categoryName,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${request.shortReference} • ${formatRelative(request.createdAt)}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(status: request.status),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                request.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.place_outlined,
                      size: 15, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      request.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              if (request.agreedPrice != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.payments_outlined,
                        size: 15, color: scheme.primary),
                    const SizedBox(width: 5),
                    Text(
                      'Agreed price: ${request.priceLabel}',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.primary, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
              if (request.providerName != null &&
                  request.status != RequestStatus.pendingAdminReview) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded,
                        size: 15, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 5),
                    Text(
                      request.providerName!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
              if (request.canBeRated && onRate != null) ...[
                const SizedBox(height: 14),
                FilledButton.tonalIcon(
                  onPressed: onRate,
                  icon: const Icon(Icons.star_rounded, size: 20),
                  label: const Text('Rate this job'),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(44)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
