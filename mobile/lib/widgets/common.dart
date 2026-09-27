import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Карточка с тонкой обводкой и мягкой подсветкой — базовый контейнер
/// интерфейса. Вынесена отдельно, чтобы скругления и обводки были одинаковыми
/// на всех экранах.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.accent,
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Если задан — карточка получает цветную рамку и лёгкое свечение.
  final Color? accent;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final borderColor = accent?.withValues(alpha: 0.55) ?? VsmColors.stroke;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: gradient == null ? VsmColors.surface : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(VsmSpacing.cardRadius),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x101A1F2C),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(VsmSpacing.cardRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(VsmSpacing.cardRadius),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Небольшая метка-капсула: категория сценария, класс обслуживания, вердикт.
class VsmChip extends StatelessWidget {
  const VsmChip({
    super.key,
    required this.label,
    this.icon,
    this.color = VsmColors.textSecondary,
    this.filled = false,
  });

  final String label;
  final IconData? icon;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: icon == null ? 10 : 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.16) : Colors.transparent,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: color.withValues(alpha: filled ? 0.32 : 0.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Заголовок секции: короткая красная засечка и название обычным регистром.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(
      context,
    ).textTheme.headlineSmall?.copyWith(fontSize: 20);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 10), trailing!],
            ],
          ),
          const SizedBox(height: 6),
          const ColoredBox(
            color: Color(0xFFC4B294),
            child: SizedBox(height: 1, width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// Индикатор сложности сценария: три засечки, активные подсвечены.
class DifficultyDots extends StatelessWidget {
  const DifficultyDots({super.key, required this.difficulty});

  final int difficulty;

  @override
  Widget build(BuildContext context) {
    final color = switch (difficulty) {
      1 => VsmColors.safety,
      2 => VsmColors.loyalty,
      _ => VsmColors.brand,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        final active = index < difficulty;
        return Container(
          margin: const EdgeInsets.only(right: 3),
          width: 14,
          height: 4,
          decoration: BoxDecoration(
            color: active ? color : VsmColors.stroke,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

/// Пустое состояние списка.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 42, color: VsmColors.textMuted),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
