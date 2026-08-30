import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/request_status.dart';
import '../../../core/models/service_request.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/status_badge.dart';
import '../application/customer_providers.dart';
import '../data/customer_repository.dart';
import 'review_modal.dart';

/// `/customer/my-requests/:id` — full job detail with the status timeline.
class CustomerRequestDetailScreen extends ConsumerWidget {
  const CustomerRequestDetailScreen({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(customerRequestDetailProvider(requestId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request detail'),
        actions: [
          IconButton(
            onPressed: () =>
                ref.invalidate(customerRequestDetailProvider(requestId)),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: AsyncValueView<ServiceRequest>(
        value: detail,
        onRetry: () => ref.invalidate(customerRequestDetailProvider(requestId)),
        data: (request) => _Body(request: request),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.request});

  final ServiceRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                request.categoryName,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            StatusBadge(status: request.status),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${request.shortReference} • submitted ${formatDateTime(request.createdAt)}',
          style:
              theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 22),
        _StatusTimeline(status: request.status),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Job details',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Text(request.description,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
                const Divider(height: 26),
                _DetailRow(
                  icon: Icons.place_outlined,
                  label: 'Address',
                  value: request.address,
                ),
                if (request.preferredTime != null) ...[
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.schedule_rounded,
                    label: 'Preferred time',
                    value: request.preferredTime!,
                  ),
                ],
                const SizedBox(height: 12),
                _DetailRow(
                  icon: Icons.payments_outlined,
                  label: 'Agreed price',
                  value: request.agreedPrice == null
                      ? 'Admin will confirm by phone'
                      : request.priceLabel,
                  highlight: request.agreedPrice != null,
                ),
                if (request.providerName != null) ...[
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.engineering_rounded,
                    label: 'Skilled person',
                    value: request.providerName!,
                  ),
                ],
                if (request.providerPhone != null &&
                    request.status.isActiveForProvider) ...[
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.phone_rounded,
                    label: 'Contact',
                    value: request.providerPhone!,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (request.status == RequestStatus.pendingAdminReview) ...[
          const SizedBox(height: 16),
          _InfoNote(
            icon: Icons.support_agent_rounded,
            message:
                'An admin is reviewing this job and will call you to agree on the price.',
          ),
        ],
        if (request.rejectionReason != null) ...[
          const SizedBox(height: 16),
          _InfoNote(
            icon: Icons.replay_rounded,
            message:
                'The first provider could not take the job (${request.rejectionReason}). The admin is finding a replacement.',
          ),
        ],
        if (request.canBeRated) ...[
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: () async {
              final submitted = await showReviewModal(context, request);
              if (!submitted || !context.mounted) return;
              ref.invalidate(customerRequestDetailProvider(request.id));
            },
            icon: const Icon(Icons.star_rounded),
            label: const Text('Rate this job'),
          ),
        ],
        if (!request.status.isTerminal &&
            request.status == RequestStatus.pendingAdminReview) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _confirmCancel(context, ref),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Cancel request'),
            style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this request?'),
        content: const Text(
            'The admin will stop reviewing it. You can always submit a new request later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(customerRepositoryProvider).cancelRequest(request.id);
      ref.invalidate(myRequestsProvider);
      ref.invalidate(customerRequestDetailProvider(request.id));
      if (context.mounted) showAppSnackBar(context, 'Request cancelled.');
    } catch (error) {
      if (context.mounted) {
        showAppSnackBar(context, error.toString(), isError: true);
      }
    }
  }
}

/// Vertical progress of the backend state machine.
class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.status});

  final RequestStatus status;

  static const _steps = <(String, String, List<RequestStatus>)>[
    (
      'Submitted',
      'Job received by Xirfadle',
      [RequestStatus.pendingAdminReview]
    ),
    (
      'Admin confirmed',
      'Price agreed and provider assigned',
      [RequestStatus.confirmedByAdmin, RequestStatus.assigned]
    ),
    (
      'Provider accepted',
      'Skilled person is on the job',
      [RequestStatus.acceptedByProvider, RequestStatus.inProgress]
    ),
    ('Completed', 'Work finished', [RequestStatus.completed]),
  ];

  int get _currentIndex {
    for (var i = _steps.length - 1; i >= 0; i--) {
      if (_steps[i].$3.contains(status)) return i;
    }
    // Rejected sits between admin confirmation and acceptance.
    if (status == RequestStatus.rejectedByProvider) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final current = _currentIndex;
    final cancelled = status == RequestStatus.cancelled;

    return Column(
      children: [
        for (var i = 0; i < _steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: cancelled
                            ? scheme.surfaceContainerHighest
                            : (i <= current
                                ? status.color
                                : scheme.surfaceContainerHighest),
                        shape: BoxShape.circle,
                      ),
                      child: i <= current && !cancelled
                          ? const Icon(Icons.check_rounded,
                              size: 15, color: Colors.white)
                          : null,
                    ),
                    if (i < _steps.length - 1)
                      Expanded(
                        child: Container(
                          width: 2,
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          color: i < current && !cancelled
                              ? status.color
                              : scheme.surfaceContainerHighest,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        bottom: i < _steps.length - 1 ? 20 : 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _steps[i].$1,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: i == current
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: i <= current
                                ? scheme.onSurface
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _steps[i].$2,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon,
            size: 18,
            color: highlight ? scheme.primary : scheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 1),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: highlight ? scheme.primary : scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.45)),
          ),
        ],
      ),
    );
  }
}
