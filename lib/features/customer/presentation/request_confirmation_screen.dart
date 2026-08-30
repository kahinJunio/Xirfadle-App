import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/config/app_routes.dart';
import '../../../app/config/app_theme.dart';
import '../../../core/widgets/status_badge.dart';
import '../application/create_request_controller.dart';

/// Shown right after a successful submission: sets the expectation that an
/// admin will call off-platform to confirm details and price.
class RequestConfirmationScreen extends ConsumerWidget {
  const RequestConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final request = ref.watch(createRequestControllerProvider).submitted;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: AppTheme.statusActive.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_rounded,
                          size: 56, color: AppTheme.statusActive),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Request submitted',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'An admin is reviewing your job now. They will call you shortly to confirm the details and agree on a price before a skilled person is dispatched.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  if (request != null) ...[
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _SummaryRow(
                              label: 'Reference',
                              value: request.shortReference,
                            ),
                            const Divider(height: 22),
                            _SummaryRow(
                              label: 'Service',
                              value: request.categoryName,
                            ),
                            const Divider(height: 22),
                            _SummaryRow(
                              label: 'Address',
                              value: request.address,
                            ),
                            const Divider(height: 22),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Status',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme
                                            .colorScheme.onSurfaceVariant)),
                                StatusBadge(status: request.status),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: () {
                      ref
                          .read(createRequestControllerProvider.notifier)
                          .reset();
                      context.go(AppRoutes.myRequests);
                    },
                    icon: const Icon(Icons.receipt_long_rounded),
                    label: const Text('Track my requests'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () {
                      ref
                          .read(createRequestControllerProvider.notifier)
                          .reset();
                      context.go(AppRoutes.customerHome);
                    },
                    child: const Text('Back to home'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

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
