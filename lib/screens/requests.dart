import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

/// 07 · Requests
class RequestsScreen extends StatelessWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 14),
          child: Heading('Requests', size: 38),
        ),
        Segments(
          left: 'Connections · ${app.connections.length}',
          right: 'Collabs · ${app.collabRequests.length}',
          leftSelected: app.requestMode == RequestMode.connections,
          onLeft: () => app.setRequestMode(RequestMode.connections),
          onRight: () => app.setRequestMode(RequestMode.collabs),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: _body(app),
          ),
        ),
      ],
    );
  }

  Widget _body(AppState app) {
    switch (app.listState) {
      case ListState.loading:
        return const Column(
          spacing: 12,
          children: [
            SkeletonCard(height: 168),
            SkeletonCard(height: 168, opacity: 0.6),
          ],
        );
      case ListState.error:
        return LoadError(onRetry: app.retry);
      case ListState.data:
      case ListState.empty:
        break;
    }
    final requests = app.currentRequests;
    if (requests.isEmpty) {
      return MessageBlock(
        title: 'All ',
        em: 'clear.',
        body: app.requestMode == RequestMode.connections
            ? 'No pending connection requests. Keep swiping in Discover.'
            : 'No one has applied to your collabs yet.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [for (final r in requests) _RequestCard(request: r)],
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});

  final ConnectionRequest request;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final person = request.person;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          Row(
            spacing: 12,
            children: [
              Avatar(person: person, size: 56, fontSize: 17),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      person.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${person.creative} · ${person.city}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Pressable(
                onTap: () => app.openPerson(person),
                label: 'View profile',
                builder: (context, _) => const SizedBox(
                  height: 44,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Center(
                      widthFactor: 1,
                      child: Text(
                        'View profile',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Text.rich(
            TextSpan(
              children: [
                if (request.post != null)
                  const TextSpan(
                    text: 'Applied to: ',
                    style: TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                TextSpan(text: request.post ?? person.bio),
              ],
            ),
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppColors.muted,
            ),
          ),
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: PillButton.outline(
                  label: 'Decline',
                  onTap: () => app.declineRequest(request),
                  height: 46,
                  fontSize: 15,
                  padding: EdgeInsets.zero,
                ),
              ),
              Expanded(
                child: PillButton(
                  label: 'Accept',
                  onTap: () => app.acceptRequest(request),
                  height: 46,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
