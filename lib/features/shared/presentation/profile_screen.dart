import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/api_config.dart';
import '../../../app/config/app_theme.dart';
import '../../../core/models/user_role.dart';
import '../../auth/application/auth_controller.dart';
import '../../provider/application/provider_job_controller.dart';

/// `/profile` — identity, the dual-role switcher and sign-out.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Row(
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  user.initials,
                  style: TextStyle(
                    color: scheme.primary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.phoneNumber.isEmpty
                          ? 'No phone on file'
                          : user.phoneNumber,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final role in user.roles)
                          Chip(
                            label: Text(role.label),
                            visualDensity: VisualDensity.compact,
                            labelStyle: const TextStyle(fontSize: 11.5),
                            backgroundColor: role == user.activeRole
                                ? scheme.primaryContainer
                                : scheme.surface,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          if (user.isDualRole) ...[
            Text('Operating mode',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              'Switch between hiring help and taking jobs.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            SegmentedButton<UserRole>(
              segments: const [
                ButtonSegment(
                  value: UserRole.customer,
                  label: Text('Customer'),
                  icon: Icon(Icons.search_rounded),
                ),
                ButtonSegment(
                  value: UserRole.provider,
                  label: Text('Skilled person'),
                  icon: Icon(Icons.handyman_rounded),
                ),
              ],
              selected: {user.activeRole},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => ref
                  .read(authControllerProvider.notifier)
                  .switchRole(selection.first),
            ),
            const SizedBox(height: 26),
          ],
          if (user.isProvider) ...[
            Text('Availability',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _AvailabilityRow(),
            const SizedBox(height: 26),
          ],
          Text('About',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.support_agent_rounded),
                  title: const Text('How Xirfadle works'),
                  subtitle: const Text(
                      'Admins confirm every job by phone before dispatch.'),
                  isThreeLine: true,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.dns_outlined),
                  title: const Text('Connected server'),
                  subtitle: Text(ApiConfig.baseUrl),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          OutlinedButton.icon(
            onPressed: () => _confirmSignOut(context, ref),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.statusRejected,
              side: BorderSide(
                  color: AppTheme.statusRejected.withValues(alpha: 0.5)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need your phone number and password to sign back in.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(authControllerProvider.notifier).signOut();
  }
}

class _AvailabilityRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availability = ref.watch(availabilityControllerProvider);
    final isOnline = availability.valueOrNull ?? false;

    return Card(
      child: SwitchListTile(
        value: isOnline,
        onChanged: (value) => ref
            .read(availabilityControllerProvider.notifier)
            .toggle(value),
        title: Text(isOnline ? 'On duty' : 'Off duty'),
        subtitle: Text(
          isOnline
              ? 'Admins can dispatch jobs to you'
              : 'You will not receive new dispatches',
        ),
        secondary: Icon(
          isOnline ? Icons.bolt_rounded : Icons.bedtime_outlined,
          color: isOnline ? AppTheme.statusActive : null,
        ),
      ),
    );
  }
}
