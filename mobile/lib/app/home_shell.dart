import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../features/leaderboard/leaderboard_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/scenarios/scenario_list_screen.dart';
import '../widgets/railway.dart';

/// Каркас с нижней навигацией.
///
/// Три раздела ровно соответствуют циклу вовлечения из ТЗ:
/// сценарии (действие) → профиль (очки и достижения) → рейтинг (мотивация).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _page = PageController();
  int _index = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (index == _index) return;
    _page.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CabinBackground(
        child: PageView(
          controller: _page,
          onPageChanged: (value) => setState(() => _index = value),
          children: const [
            ScenarioListScreen(),
            ProfileScreen(),
            LeaderboardScreen(),
          ],
        ),
      ),
      bottomNavigationBar: _CarriageBar(index: _index, onSelected: _select),
    );
  }
}

class _CarriageBar extends StatelessWidget {
  const _CarriageBar({required this.index, required this.onSelected});

  final int index;
  final ValueChanged<int> onSelected;

  static const _items = [
    (icon: Icons.confirmation_number_outlined, label: 'ВСМ'),
    (icon: Icons.badge_outlined, label: 'Проводник'),
    (icon: Icons.route_outlined, label: 'Бригада'),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: VsmColors.surface,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: VsmColors.stroke)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                for (var i = 0; i < _items.length; i++)
                  Expanded(
                    child: InkWell(
                      onTap: () => onSelected(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 22,
                            height: 2,
                            color: i == index
                                ? VsmColors.brand
                                : Colors.transparent,
                          ),
                          const SizedBox(height: 8),
                          Icon(
                            _items[i].icon,
                            size: 22,
                            color: i == index
                                ? VsmColors.brand
                                : VsmColors.textMuted,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _items[i].label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: i == index
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: i == index
                                  ? VsmColors.brand
                                  : VsmColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
