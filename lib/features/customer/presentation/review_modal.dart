import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/service_request.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/rating_stars.dart';
import '../../auth/presentation/login_screen.dart' show ErrorBanner;
import '../application/review_controller.dart';

/// Opens the rating sheet for a completed job. Returns true when a review was
/// submitted.
Future<bool> showReviewModal(BuildContext context, ServiceRequest request) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ReviewSheet(request: request),
  );
  return result ?? false;
}

class _ReviewSheet extends ConsumerStatefulWidget {
  const _ReviewSheet({required this.request});

  final ServiceRequest request;

  @override
  ConsumerState<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<_ReviewSheet> {
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await ref
        .read(reviewControllerProvider.notifier)
        .submit(widget.request.id);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      showAppSnackBar(context, 'Thanks for rating this job.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(reviewControllerProvider);
    final controller = ref.read(reviewControllerProvider.notifier);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        4,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Rate this job',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            widget.request.providerName == null
                ? widget.request.categoryName
                : '${widget.request.categoryName} • ${widget.request.providerName}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          RatingInput(value: state.rating, onChanged: controller.setRating),
          const SizedBox(height: 6),
          Text(
            _ratingLabel(state.rating),
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _commentController,
            maxLines: 4,
            minLines: 3,
            maxLength: 400,
            textCapitalization: TextCapitalization.sentences,
            onChanged: controller.setComment,
            decoration: const InputDecoration(
              hintText: 'Tell other customers how it went (optional)',
              alignLabelWithHint: true,
            ),
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 8),
            ErrorBanner(message: state.errorMessage!),
          ],
          const SizedBox(height: 14),
          FilledButton(
            onPressed: state.isSubmitting ? null : _submit,
            child: state.isSubmitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: Colors.white),
                  )
                : const Text('Submit review'),
          ),
        ],
      ),
    );
  }

  String _ratingLabel(int rating) => switch (rating) {
        1 => 'Poor',
        2 => 'Below expectations',
        3 => 'Fine',
        4 => 'Good work',
        _ => 'Excellent',
      };
}
