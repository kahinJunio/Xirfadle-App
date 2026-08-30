import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/config/app_routes.dart';
import '../../../core/models/request_status.dart';
import '../../../core/models/service_request.dart';
import '../../../core/widgets/async_value_view.dart';
import '../application/provider_job_controller.dart';
import 'job_detail_screen.dart';

/// `/provider/active-job` — the jobs the provider has accepted.
class ActiveJobScreen extends ConsumerWidget {
  const ActiveJobScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(dispatchedRequestsProvider);
    final active = ref.watch(activeJobsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active job'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(dispatchedRequestsProvider),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dispatchedRequestsProvider);
          await ref.read(dispatchedRequestsProvider.future);
        },
        child: AsyncValueView<List<ServiceRequest>>(
          value: requests,
          onRetry: () => ref.invalidate(dispatchedRequestsProvider),
          data: (_) {
            if (active.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  EmptyStateView(
                    icon: Icons.handyman_outlined,
                    title: 'No job in progress',
                    message:
                        'Accept a dispatch and the step-by-step tracker appears here.',
                    action: FilledButton.tonal(
                      onPressed: () => context.go(AppRoutes.providerRequests),
                      child: const Text('View dispatches'),
                    ),
                  ),
                ],
              );
            }

            // The common case is a single active job; show it in full.
            if (active.length == 1) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [JobProgressPanel(request: active.first)],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              itemCount: active.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) =>
                  JobProgressPanel(request: active[index], compact: true),
            );
          },
        ),
      ),
    );
  }
}

/// Step tracker plus the Start / Mark complete actions.
class JobProgressPanel extends ConsumerWidget {
  const JobProgressPanel({
    super.key,
    required this.request,
    this.compact = false,
  });

  final ServiceRequest request;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final busyId = ref.watch(jobActionControllerProvider);
    final isBusy = busyId == request.id;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    request.categoryName,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  request.priceLabel,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              request.shortReference,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            JobStepper(status: request.status),
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 16),
            _Line(
              icon: Icons.person_outline_rounded,
              text: request.customerName ?? 'Customer',
            ),
            const SizedBox(height: 8),
            _Line(icon: Icons.place_outlined, text: request.address),
            if (!compact) ...[
              const SizedBox(height: 14),
              Text(
                request.description,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
            ],
            const SizedBox(height: 18),
            if (request.status == RequestStatus.acceptedByProvider)
              FilledButton.icon(
                onPressed: isBusy || busyId != null
                    ? null
                    : () => _run(
                          context,
                          ref,
                          () => ref
                              .read(jobActionControllerProvider.notifier)
                              .start(request.id),
                          'Job started. The customer can see the update.',
                        ),
                icon: isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.2, color: Colors.white),
                      )
                    : const Icon(Icons.play_arrow_rounded),
                label: const Text('Start work'),
              )
            else if (request.status == RequestStatus.inProgress)
              FilledButton.icon(
                onPressed: isBusy || busyId != null
                    ? null
                    : () => _confirmComplete(context, ref),
                icon: isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.2, color: Colors.white),
                      )
                    : const Icon(Icons.task_alt_rounded),
                label: const Text('Mark complete'),
              ),
            if (compact) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () =>
                    context.push(AppRoutes.providerJobDetailOf(request.id)),
                child: const Text('Open job'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmComplete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mark this job complete?'),
        content: const Text(
            'The customer will be asked to rate your work. Only do this once the job is finished.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Mark complete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await _run(
      context,
      ref,
      () => ref.read(jobActionControllerProvider.notifier).complete(request.id),
      'Job completed. The customer can now rate it.',
    );
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<String?> Function() action,
    String successMessage,
  ) async {
    final error = await action();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error ?? successMessage)));
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
