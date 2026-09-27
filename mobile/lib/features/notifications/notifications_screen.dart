import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/notification_center.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/railway.dart';
import '../scenarios/scenario_briefing_screen.dart';

/// Лента оповещений: новые сценарии, челленджи, сгорающие баллы.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.read(context).markNotificationsSeen();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final items = state.notifications;
    final unread = items
        .where((item) => !state.profile.seenNotificationIds.contains(item.id))
        .length;

    return Scaffold(
      body: CabinBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Лента смены',
                            style: Theme.of(
                              context,
                            ).textTheme.headlineSmall?.copyWith(fontSize: 22),
                          ),
                          const Text(
                            'ВСМ-001 · рейс 717',
                            style: TextStyle(
                              fontSize: 12,
                              color: VsmColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (unread > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: VsmColors.livery,
                          border: const Border(
                            top: BorderSide(color: VsmColors.brand, width: 2),
                          ),
                        ),
                        child: Text(
                          unread == 1 ? '1 новое' : '$unread новых',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: RouteRibbon(light: false),
              ),
              Expanded(
                child: items.isEmpty
                    ? const EmptyState(
                        icon: Icons.notifications_none_rounded,
                        title: 'Пока тихо',
                        message:
                            'Новые сценарии, челленджи и сгорающие баллы '
                            'появятся здесь после первых смен.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          VsmSpacing.screenPadding,
                          0,
                          VsmSpacing.screenPadding,
                          24,
                        ),
                        itemCount: items.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _NotificationCard(
                            item: item,
                            unread: !state.profile.seenNotificationIds.contains(
                              item.id,
                            ),
                            onTap: item.scenarioId == null
                                ? null
                                : () {
                                    final scenario = state.scenarioById(
                                      item.scenarioId!,
                                    );
                                    if (scenario == null) return;
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ScenarioBriefingScreen(
                                          scenario: scenario,
                                        ),
                                      ),
                                    );
                                  },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.unread,
    this.onTap,
  });

  final AppNotification item;
  final bool unread;
  final VoidCallback? onTap;

  Color get _color => switch (item.kind) {
    NotificationKind.newScenario => VsmColors.loyalty,
    NotificationKind.challenge => VsmColors.brand,
    NotificationKind.expiringPoints => VsmColors.danger,
    NotificationKind.competencyGap => VsmColors.safety,
    NotificationKind.achievement => const Color(0xFF9A7B4F),
  };

  @override
  Widget build(BuildContext context) {
    return TicketCard(
      accent: unread ? _color : VsmColors.stroke,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(item.kind.icon, size: 16, color: _color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.kind.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _color,
                  ),
                ),
              ),
              if (item.deadlineLabel != null)
                Text(
                  item.deadlineLabel!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: VsmColors.textMuted,
                  ),
                ),
              if (unread) ...[
                const SizedBox(width: 8),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _color,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            item.body,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: VsmColors.textSecondary,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(height: 10),
            const Text(
              'Открыть сценарий',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: VsmColors.brand,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
