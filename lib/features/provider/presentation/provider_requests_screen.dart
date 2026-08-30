import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/config/app_routes.dart';
import '../../../core/models/request_status.dart';
import '../../../core/models/service_request.dart';
import '../../../core/widgets/async_value_view.dart';
import '../application/provider_job_controller.dart';
import 'incoming_request_card.dart';

/// `/provider/requests` — the dispatch inbox.
class ProviderRequestsScreen extends ConsumerStatefulWidget {
  const ProviderRequestsScreen({super.key});

  @override
  ConsumerState<ProviderRequestsScreen> createState() =>
      _ProviderRequestsScreenState();
}

class _ProviderRequestsScreenState
    extends ConsumerState<ProviderRequestsScreen> {
  _JobFilter _filter = _JobFilter.newDispatch;

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(dispatchedRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispatched jobs'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(dispatchedRequestsProvider),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: SegmentedButton<_JobFilter>(
              segments: const [
                ButtonSegment(value: _JobFilter.newDispatch, label: Text('New')),
                ButtonSegment(value: _JobFilter.active, label: Text('Active')),
                ButtonSegment(value: _JobFilter.past, label: Text('Past')),
              ],
              selected: {_filter},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  setState(() => _filter = selection.first),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dispatchedRequestsProvider);
          await ref.read(dispatchedRequestsProvider.future);
        },
        child: AsyncValueView<List<ServiceRequest>>(
          value: requests,
          onRetry: () => ref.invalidate(dispatchedRequestsProvider),
          data: (items) {
            final visible = _filter.apply(items);
            if (visible.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  EmptyStateView(
                    icon: _filter.emptyIcon,
                    title: _filter.emptyTitle,
                    message: _filter.emptyMessage,
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              itemCount: visible.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => IncomingRequestCard(
                request: visible[index],
                onTap: () => context
                    .push(AppRoutes.providerJobDetailOf(visible[index].id)),
              ),
            );
          },
        ),
      ),
    );
  }
}

enum _JobFilter {
  newDispatch,
  active,
  past;

  List<ServiceRequest> apply(List<ServiceRequest> requests) => switch (this) {
        _JobFilter.newDispatch =>
          requests.where((r) => r.status.awaitsProviderResponse).toList(),
        _JobFilter.active =>
          requests.where((r) => r.status.isActiveForProvider).toList(),
        _JobFilter.past => requests
            .where((r) =>
                r.status.isTerminal ||
                r.status == RequestStatus.rejectedByProvider)
            .toList(),
      };

  IconData get emptyIcon => switch (this) {
        _JobFilter.newDispatch => Icons.inbox_outlined,
        _JobFilter.active => Icons.handyman_outlined,
        _JobFilter.past => Icons.history_rounded,
      };

  String get emptyTitle => switch (this) {
        _JobFilter.newDispatch => 'No new dispatches',
        _JobFilter.active => 'No active jobs',
        _JobFilter.past => 'Nothing in your history yet',
      };

  String get emptyMessage => switch (this) {
        _JobFilter.newDispatch =>
          'Go on duty and admins will send jobs your way.',
        _JobFilter.active => 'Accept a dispatch and it will appear here.',
        _JobFilter.past => 'Completed and rejected jobs are archived here.',
      };
}
