import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/config/app_routes.dart';
import '../../../core/models/service_category.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../auth/presentation/login_screen.dart' show ErrorBanner;
import '../application/create_request_controller.dart';
import '../application/customer_providers.dart';
import 'address_picker_screen.dart';
import 'category_list_view.dart';

/// Timing options offered alongside the free-text description.
const _timingOptions = <String>[
  'As soon as possible',
  'Today',
  'Tomorrow',
  'This week',
  'Flexible',
];

/// `/customer/create-request` — the job submission form.
class CreateRequestScreen extends ConsumerStatefulWidget {
  const CreateRequestScreen({super.key});

  @override
  ConsumerState<CreateRequestScreen> createState() =>
      _CreateRequestScreenState();
}

class _CreateRequestScreenState extends ConsumerState<CreateRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  /// How long a submit error stays on screen before it clears itself.
  static const _errorDisplayDuration = Duration(seconds: 4);
  Timer? _errorTimer;

  @override
  void initState() {
    super.initState();
    // Restore text when returning from the map picker.
    _descriptionController.text =
        ref.read(createRequestControllerProvider).description;
  }

  @override
  void dispose() {
    _errorTimer?.cancel();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickAddress() async {
    final state = ref.read(createRequestControllerProvider);
    final result = await Navigator.of(context).push<PickedAddress>(
      MaterialPageRoute(
        builder: (_) => AddressPickerScreen(
          initialAddress: state.address,
          initialPin: state.pin,
        ),
      ),
    );
    if (result == null) return;
    ref
        .read(createRequestControllerProvider.notifier)
        .setAddress(result.address, pin: result.pin);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final controller = ref.read(createRequestControllerProvider.notifier);
    if (ref.read(createRequestControllerProvider).category == null) {
      _showMessage('Choose a service category first.');
      return;
    }
    if (ref.read(createRequestControllerProvider).address.trim().isEmpty) {
      _showMessage('Add the job address.');
      return;
    }

    final ok = await controller.submit();
    if (!mounted) return;
    // On failure the error banner shows the message; see the listener in build.
    if (ok) context.pushReplacement(AppRoutes.requestConfirmation);
  }

  /// Restarts the auto-dismiss countdown whenever a new error appears.
  void _onErrorChanged(String? previous, String? next) {
    _errorTimer?.cancel();
    if (next == null) return;
    _errorTimer = Timer(_errorDisplayDuration, () {
      if (mounted) {
        ref.read(createRequestControllerProvider.notifier).clearError();
      }
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(createRequestControllerProvider);
    final controller = ref.read(createRequestControllerProvider.notifier);
    final categories = ref.watch(categoriesProvider);
    ref.listen<String?>(
      createRequestControllerProvider.select((s) => s.errorMessage),
      _onErrorChanged,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Request a service')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _FieldLabel(
                'Service category',
                required: true,
                hint: 'What kind of help do you need?',
              ),
              const SizedBox(height: 10),
              AsyncValueView<List<ServiceCategory>>(
                value: categories,
                onRetry: () => ref.invalidate(categoriesProvider),
                loading: const SizedBox(
                  height: 90,
                  child: Center(child: CircularProgressIndicator()),
                ),
                isEmpty: (items) => items.isEmpty,
                empty: const EmptyStateView(
                  icon: Icons.category_outlined,
                  title: 'No categories available',
                ),
                data: (items) => CategoryListView(
                  categories: items,
                  selectedId: state.category?.id,
                  onSelected: controller.selectCategory,
                ),
              ),
              const SizedBox(height: 24),
              _FieldLabel(
                'Describe the issue',
                required: true,
                hint: 'The more detail, the faster the admin can price it.',
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                minLines: 4,
                maxLength: 600,
                textCapitalization: TextCapitalization.sentences,
                onChanged: controller.setDescription,
                decoration: const InputDecoration(
                  hintText:
                      'e.g. The kitchen sink pipe is leaking under the cabinet and water pools on the floor.',
                  alignLabelWithHint: true,
                ),
                validator: (value) =>
                    Validators.minLength(value, 10, 'Description'),
              ),
              const SizedBox(height: 12),
              _FieldLabel('When do you need it?'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in _timingOptions)
                    ChoiceChip(
                      label: Text(option),
                      selected: state.preferredTime == option,
                      onSelected: (selected) => controller
                          .setPreferredTime(selected ? option : null),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              _FieldLabel(
                'Job address',
                required: true,
                hint: 'Drop a pin on the map or type it in.',
              ),
              const SizedBox(height: 10),
              _AddressField(
                address: state.address,
                hasPin: state.pin != null,
                onTap: _pickAddress,
              ),
              if (state.preferredProviderId != null) ...[
                const SizedBox(height: 16),
                _PreferredProviderNote(
                  onClear: () => controller.setPreferredProvider(null),
                ),
              ],
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'After you submit, an admin reviews the job and calls you to agree on the price before a skilled person is dispatched.',
                        style:
                            theme.textTheme.bodySmall?.copyWith(height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: state.errorMessage == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: ErrorBanner(message: state.errorMessage!),
                      ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: state.isSubmitting ? null : _submit,
                icon: state.isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                    state.isSubmitting ? 'Submitting...' : 'Submit request'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label, {this.required = false, this.hint});

  final String label;
  final bool required;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            if (required)
              Text(' *', style: TextStyle(color: theme.colorScheme.error)),
          ],
        ),
        if (hint != null) ...[
          const SizedBox(height: 2),
          Text(hint!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ],
    );
  }
}

class _AddressField extends StatelessWidget {
  const _AddressField({
    required this.address,
    required this.hasPin,
    required this.onTap,
  });

  final String address;
  final bool hasPin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSet = address.trim().isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSet
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSet ? Icons.place_rounded : Icons.add_location_alt_outlined,
              color: isSet
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSet ? address : 'Choose the job location',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isSet ? FontWeight.w600 : FontWeight.w400,
                      color: isSet
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (hasPin) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Map pin attached',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.primary),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _PreferredProviderNote extends StatelessWidget {
  const _PreferredProviderNote({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.person_pin_rounded,
              size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Requesting a specific provider. The admin will try to assign them.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
            ),
          ),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, size: 18),
            tooltip: 'Remove preference',
          ),
        ],
      ),
    );
  }
}
