import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/service_request.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/status_badge.dart';
import '../application/provider_job_controller.dart';

/// Dispatch card with the Accept / Reject controls.
class IncomingRequestCard extends ConsumerWidget {
  const IncomingRequestCard({
    super.key,
    required this.request,
    this.onTap,
    this.showActions = true,
  });

  final ServiceRequest request;
  final VoidCallback? onTap;
  final bool showActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final busyId = ref.watch(jobActionControllerProvider);
    final isBusy = busyId == request.id;

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
                  StatusBadge(status: request.status, forProvider: true),
                ],
              ),
              const SizedBox(height: 14),
              // The admin-set price is the headline number for the provider.
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.payments_rounded,
                        size: 20, color: scheme.primary),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Agreed price',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
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
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                request.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
              const SizedBox(height: 12),
              _IconLine(icon: Icons.place_outlined, text: request.address),
              if (request.customerName != null) ...[
                const SizedBox(height: 6),
                _IconLine(
                    icon: Icons.person_outline_rounded,
                    text: request.customerName!),
              ],
              if (request.preferredTime != null) ...[
                const SizedBox(height: 6),
                _IconLine(
                    icon: Icons.schedule_rounded, text: request.preferredTime!),
              ],
              if (showActions && request.status.awaitsProviderResponse) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isBusy || busyId != null
                            ? null
                            : () => _reject(context, ref),
                        icon: const Icon(Icons.close_rounded, size: 20),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: scheme.error,
                          side: BorderSide(
                              color: scheme.error.withValues(alpha: 0.5)),
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: isBusy || busyId != null
                            ? null
                            : () => _accept(context, ref),
                        icon: isBusy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.2, color: Colors.white),
                              )
                            : const Icon(Icons.check_rounded, size: 20),
                        label: Text(isBusy ? 'Working...' : 'Accept'),
                        style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _accept(BuildContext context, WidgetRef ref) async {
    final error =
        await ref.read(jobActionControllerProvider.notifier).accept(request.id);
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      error ?? 'Job accepted. The customer has been notified.',
      isError: error != null,
    );
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final reason = await showRejectionDialog(context);
    if (reason == null || !context.mounted) return;

    final error = await ref
        .read(jobActionControllerProvider.notifier)
        .reject(request.id, reason);
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      error ?? 'Job rejected. An admin will re-dispatch it.',
      isError: error != null,
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 15, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

const _rejectionReasons = <String>[
  'Already booked at that time',
  'Too far from my area',
  'Outside my specialty',
  'Price is too low',
];

/// Prompts for a rejection reason, which the admin portal uses to re-dispatch.
Future<String?> showRejectionDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => const _RejectionDialog(),
  );
}

class _RejectionDialog extends StatefulWidget {
  const _RejectionDialog();

  @override
  State<_RejectionDialog> createState() => _RejectionDialogState();
}

class _RejectionDialogState extends State<_RejectionDialog> {
  final _otherController = TextEditingController();
  String? _selected;

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  String? get _reason {
    if (_selected == null) return null;
    if (_selected == 'Other') {
      final text = _otherController.text.trim();
      return text.isEmpty ? null : text;
    }
    return _selected;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Why are you rejecting?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The admin needs a reason to re-dispatch this job quickly.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: _selected,
              onChanged: (value) => setState(() => _selected = value),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final reason in [..._rejectionReasons, 'Other'])
                    RadioListTile<String>(
                      value: reason,
                      title:
                          Text(reason, style: const TextStyle(fontSize: 14)),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                ],
              ),
            ),
            if (_selected == 'Other')
              TextField(
                controller: _otherController,
                autofocus: true,
                maxLength: 160,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: 'Give a reason'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Back'),
        ),
        FilledButton(
          onPressed: _reason == null
              ? null
              : () => Navigator.of(context).pop(_reason),
          child: const Text('Reject job'),
        ),
      ],
    );
  }
}
