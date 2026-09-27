import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Одна шкала: подпись, анимированная полоса и числовое значение.
///
/// Шкалы — не украшение: цвет полосы меняется при падении в опасную зону, а
/// последний сдвиг показывается всплывающей меткой, чтобы игрок видел цену
/// решения сразу, а не только в разборе.
class ScaleBar extends StatelessWidget {
  const ScaleBar({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.lastDelta,
    this.compact = false,
  });

  final String label;
  final int value;
  final Color color;
  final IconData icon;

  /// Сдвиг, произошедший последним решением. `null` — ничего не менялось.
  final int? lastDelta;
  final bool compact;

  /// Ниже этого значения шкала считается критической и краснеет.
  static const criticalThreshold = 35;

  @override
  Widget build(BuildContext context) {
    final barColor = value <= criticalThreshold ? VsmColors.danger : color;
    final barHeight = compact ? 5.0 : 7.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: barColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 10.5 : 11.5,
                  fontWeight: FontWeight.w600,
                  color: VsmColors.textSecondary,
                ),
              ),
            ),
            if (lastDelta != null && lastDelta != 0) ...[
              _DeltaBadge(delta: lastDelta!),
              const SizedBox(width: 6),
            ],
            TweenAnimationBuilder<double>(
              tween: Tween(end: value.toDouble()),
              duration: const Duration(milliseconds: 550),
              curve: Curves.easeOutCubic,
              builder: (context, animated, _) => Text(
                animated.round().toString(),
                style: TextStyle(
                  fontSize: compact ? 13 : 15,
                  fontWeight: FontWeight.w800,
                  color: barColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 5 : 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: [
              Container(height: barHeight, color: VsmColors.stroke),
              TweenAnimationBuilder<double>(
                tween: Tween(end: value / 100),
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeOutCubic,
                builder: (context, fraction, _) => FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: fraction.clamp(0.0, 1.0),
                  child: Container(
                    height: barHeight,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [barColor.withValues(alpha: 0.6), barColor],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: barColor.withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Обёртка, показывающая обе шкалы рядом — они всегда читаются вместе.
class DualGauge extends StatelessWidget {
  const DualGauge({
    super.key,
    required this.loyalty,
    required this.safety,
    this.loyaltyDelta,
    this.safetyDelta,
    this.compact = false,
  });

  final int loyalty;
  final int safety;
  final int? loyaltyDelta;
  final int? safetyDelta;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ScaleBar(
            label: 'Лояльность пассажира',
            value: loyalty,
            color: VsmColors.loyalty,
            icon: Icons.sentiment_satisfied_alt_rounded,
            lastDelta: loyaltyDelta,
            compact: compact,
          ),
        ),
        SizedBox(width: compact ? 14 : 18),
        Expanded(
          child: ScaleBar(
            label: 'Рейтинг безопасности',
            value: safety,
            color: VsmColors.safety,
            icon: Icons.shield_rounded,
            lastDelta: safetyDelta,
            compact: compact,
          ),
        ),
      ],
    );
  }
}

/// Всплывающая метка сдвига: «+8» зелёным, «−12» красным.
class _DeltaBadge extends StatelessWidget {
  const _DeltaBadge({required this.delta});

  final int delta;

  @override
  Widget build(BuildContext context) {
    final positive = delta > 0;
    final color = positive ? VsmColors.success : VsmColors.danger;

    return TweenAnimationBuilder<double>(
      key: ValueKey(delta),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, t, _) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 6 * (1 - t)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${positive ? '+' : '−'}${delta.abs()}',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
