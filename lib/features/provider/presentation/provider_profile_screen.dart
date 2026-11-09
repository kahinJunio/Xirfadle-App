import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/provider_profile.dart';
import '../../../core/models/service_category.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/login_screen.dart' show ErrorBanner;
import '../../customer/application/customer_providers.dart';
import '../application/provider_profile_controller.dart';

/// `/provider/profile` — the skilled person edits their trade, bio,
/// specialties and city. Persisted on the device until the backend exposes a
/// provider-profile route.
class ProviderProfileScreen extends ConsumerStatefulWidget {
  const ProviderProfileScreen({super.key});

  @override
  ConsumerState<ProviderProfileScreen> createState() =>
      _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends ConsumerState<ProviderProfileScreen> {
  late final TextEditingController _bioController;
  late final TextEditingController _cityController;
  final _specialtyController = TextEditingController();

  String? _categoryId;
  late List<String> _specialties;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(providerProfileControllerProvider).profile;
    _bioController = TextEditingController(text: profile.bio ?? '');
    _cityController = TextEditingController(text: profile.city ?? '');
    _categoryId = profile.categoryId;
    _specialties = List.of(profile.specialties);
  }

  @override
  void dispose() {
    _bioController.dispose();
    _cityController.dispose();
    _specialtyController.dispose();
    super.dispose();
  }

  void _addSpecialty() {
    final value = _specialtyController.text.trim();
    if (value.isEmpty) return;
    final exists =
        _specialties.any((s) => s.toLowerCase() == value.toLowerCase());
    if (!exists) {
      setState(() => _specialties.add(value));
    }
    _specialtyController.clear();
  }

  Future<void> _save(List<ServiceCategory> categories) async {
    FocusScope.of(context).unfocus();
    final current = ref.read(providerProfileControllerProvider).profile;
    final categoryName = _categoryId == null
        ? null
        : categories
            .where((c) => c.id == _categoryId)
            .map((c) => c.name)
            .firstOrNull;

    final bio = _bioController.text.trim();
    final city = _cityController.text.trim();
    final updated = ProviderProfile(
      userId: current.userId,
      bio: bio.isEmpty ? null : bio,
      categoryId: _categoryId,
      categoryName: categoryName ?? current.categoryName,
      city: city.isEmpty ? null : city,
      specialties: _specialties,
    );

    final ok =
        await ref.read(providerProfileControllerProvider.notifier).save(updated);
    if (!mounted) return;
    if (ok) {
      showAppSnackBar(context, 'Profile saved');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(providerProfileControllerProvider);
    final user = ref.watch(currentUserProvider);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Professional profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            'This is what admins and customers see when matching you to jobs.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 22),

          // ---- Trade --------------------------------------------------------
          _Label('Trade', theme),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _categoryId,
            isExpanded: true,
            decoration: const InputDecoration(
              hintText: 'Select your main trade',
              prefixIcon: Icon(Icons.handyman_rounded),
            ),
            items: [
              for (final category in categories)
                DropdownMenuItem(
                  value: category.id,
                  child: Text(category.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) => setState(() => _categoryId = value),
          ),
          if (categories.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Trades could not be loaded. Pull to refresh the home screen '
                'and try again.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: 22),

          // ---- Bio ----------------------------------------------------------
          _Label('About you', theme),
          const SizedBox(height: 8),
          TextField(
            controller: _bioController,
            maxLines: 4,
            maxLength: 400,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText:
                  'Years of experience, the work you do best, how you work…',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),

          // ---- Specialties --------------------------------------------------
          _Label('Specialties', theme),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _specialtyController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addSpecialty(),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Pipe fitting',
                    prefixIcon: Icon(Icons.add_task_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.tonal(
                onPressed: _addSpecialty,
                child: const Text('Add'),
              ),
            ],
          ),
          if (_specialties.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final specialty in _specialties)
                  InputChip(
                    label: Text(specialty),
                    onDeleted: () =>
                        setState(() => _specialties.remove(specialty)),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 22),

          // ---- City ---------------------------------------------------------
          _Label('City / area', theme),
          const SizedBox(height: 8),
          TextField(
            controller: _cityController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Where you take jobs',
              prefixIcon: Icon(Icons.place_outlined),
            ),
          ),

          if (user != null) ...[
            const SizedBox(height: 22),
            Card(
              child: ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: Text(user.fullName),
                subtitle: Text(
                  user.phoneNumber.isEmpty
                      ? 'No phone on file'
                      : user.phoneNumber,
                ),
              ),
            ),
          ],

          if (state.errorMessage != null) ...[
            const SizedBox(height: 16),
            ErrorBanner(message: state.errorMessage!),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed:
                state.isSaving ? null : () => _save(List.of(categories)),
            icon: state.isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(state.isSaving ? 'Saving…' : 'Save profile'),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, this.theme);

  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style:
            theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
      );
}
