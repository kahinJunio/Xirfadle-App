import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/request_status.dart';
import '../../../core/models/service_request.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_value_view.dart';
import '../application/provider_job_controller.dart';
import 'active_job_screen.dart';
import 'incoming_request_card.dart';

/// `/provider/requests/:id` — one dispatched job in full.
class JobDetailScreen extends ConsumerWidget {
  const JobDetailScreen({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(providerRequestDetailProvider(requestId));

    return Scaffold(
      appBar: AppBar(title: const Text('Job detail')),
      body: AsyncValueView<ServiceRequest>(
        value: detail,
        onRetry: () => ref.invalidate(providerRequestDetailProvider(requestId)),
        data: (request) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            if (request.status.isActiveForProvider)
              JobProgressPanel(request: request)
            else
              IncomingRequestCard(request: request),
            const SizedBox(height: 18),
            _MetaCard(request: request),
          ],
        ),
      ),
    );
  }
}

/// Step-by-step tracker: Accepted → In Progress → Completed.
class JobStepper extends StatelessWidget {
  const JobStepper({super.key, required this.status});

  final RequestStatus status;

  static const _steps = <(String, RequestStatus)>[
    ('Accepted', RequestStatus.acceptedByProvider),
    ('In progress', RequestStatus.inProgress),
    ('Completed', RequestStatus.completed),
  ];

  int get _currentIndex => switch (status) {
        RequestStatus.inProgress => 1,
        RequestStatus.completed => 2,
        _ => 0,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final current = _currentIndex;

    return Row(
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: i <= current
                      ? status.color
                      : scheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: i < current
                    ? const Icon(Icons.check_rounded,
                        size: 16, color: Colors.white)
                    : Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: i <= current
                              ? Colors.white
                              : scheme.onSurfaceVariant,
                        ),
                      ),
              ),
              const SizedBox(height: 6),
              Text(
                _steps[i].$1,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight:
                      i == current ? FontWeight.w800 : FontWeight.w500,
                  color:
                      i <= current ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (i < _steps.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 22, left: 6, right: 6),
                color:
                    i < current ? status.color : scheme.surfaceContainerHighest,
              ),
            ),
        ],
      ],
    );
  }
}

class _MetaCard extends StatelessWidget {
  const _MetaCard({required this.request});

  final ServiceRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dispatch info',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            _Row(label: 'Reference', value: request.shortReference),
            const SizedBox(height: 10),
            _Row(label: 'Submitted', value: formatDateTime(request.createdAt)),
            if (request.updatedAt != null) ...[
              const SizedBox(height: 10),
              _Row(
                  label: 'Last update',
                  value: formatDateTime(request.updatedAt)),
            ],
            if (request.preferredTime != null) ...[
              const SizedBox(height: 10),
              _Row(label: 'Customer timing', value: request.preferredTime!),
            ],
            if (request.customerPhone != null &&
                request.status.isActiveForProvider) ...[
              const SizedBox(height: 10),
              _Row(label: 'Customer phone', value: request.customerPhone!),
            ],
            if (request.rejectionReason != null) ...[
              const SizedBox(height: 10),
              _Row(
                  label: 'Rejection reason', value: request.rejectionReason!),
            ],
            const SizedBox(height: 14),
            Text(
              'Xirfadle admins agree the price with the customer by phone before dispatching. Contact an admin if anything on this job needs to change.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
