import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/scenario.dart';
import '../../engine/scenario_engine.dart';

/// Мгновенная реакция на принятое решение.
///
/// Показывается сразу после выбора и до следующей сцены. Смысл в том, чтобы
/// связь «решение → последствие» возникала в моменте, а не только в финальном
/// разборе: иначе игрок доходит до конца, не понимая, где именно потерял баллы.
class ReactionSheet extends StatelessWidget {
  const ReactionSheet({
    super.key,
    required this.record,
    required this.isFinal,
    required this.onContinue,
  });

  final DecisionRecord record;

  /// Последнее решение в сценарии — меняется только подпись кнопки.
  final bool isFinal;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final color = verdictColor(record.feedback.verdict);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Transform.translate(
        offset: Offset(0, 40 * (1 - t)),
        child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: VsmColors.surface,
          border: Border(top: BorderSide(color: color, width: 3)),
          boxShadow: [
            BoxShadow(
              color: const Color(0x22121820),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              VsmSpacing.screenPadding,
              16,
              VsmSpacing.screenPadding,
              14,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      verdictIcon(record.feedback.verdict),
                      size: 17,
                      color: color,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      record.wasTimeout
                          ? 'Время вышло'
                          : record.feedback.verdict.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const Spacer(),
                    _DeltaPills(record: record),
                  ],
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 210),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (record.wasTimeout)
                          Text(
                            record.actionText,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              fontStyle: FontStyle.italic,
                              color: VsmColors.textSecondary,
                            ),
                          ),
                        if (record.feedback.why.isNotEmpty) ...[
                          if (record.wasTimeout) const SizedBox(height: 10),
                          Text(
                            record.feedback.why,
                            style: const TextStyle(fontSize: 13, height: 1.5),
                          ),
                        ],
                        if (record.roleModelNote != null) ...[
                          const SizedBox(height: 12),
                          _NoteBlock(
                            icon: Icons.account_tree_rounded,
                            label: 'Ролевая модель',
                            text: record.roleModelNote!,
                            color: VsmColors.brand,
                          ),
                        ],
                        if (record.wasLastMoment) ...[
                          const SizedBox(height: 12),
                          _NoteBlock(
                            icon: Icons.timer_rounded,
                            label: 'На грани',
                            text:
                                'Решение принято в последние секунды. '
                                'Верно — но в реальной смене такой запас '
                                'означает, что ситуация почти вышла из-под '
                                'контроля.',
                            color: VsmColors.loyalty,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: onContinue,
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(isFinal ? 'К разбору смены' : 'Дальше'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Сдвиги обеих шкал одной строкой.
class _DeltaPills extends StatelessWidget {
  const _DeltaPills({required this.record});

  final DecisionRecord record;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (record.loyaltyDelta != 0)
          _Pill(
            value: record.loyaltyDelta,
            icon: Icons.sentiment_satisfied_alt_rounded,
          ),
        if (record.loyaltyDelta != 0 && record.safetyDelta != 0)
          const SizedBox(width: 6),
        if (record.safetyDelta != 0)
          _Pill(value: record.safetyDelta, icon: Icons.shield_rounded),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.value, required this.icon});

  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final positive = value > 0;
    final color = positive ? VsmColors.success : VsmColors.danger;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            '${positive ? '+' : '−'}${value.abs()}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteBlock extends StatelessWidget {
  const _NoteBlock({
    required this.icon,
    required this.label,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(text, style: const TextStyle(fontSize: 12.5, height: 1.45)),
        ],
      ),
    );
  }
}

/// Цвет и иконка вердикта используются и здесь, и на экране разбора.
Color verdictColor(ChoiceVerdict verdict) => switch (verdict) {
  ChoiceVerdict.good => VsmColors.success,
  ChoiceVerdict.acceptable => VsmColors.loyalty,
  ChoiceVerdict.bad => VsmColors.brand,
  ChoiceVerdict.critical => VsmColors.danger,
};

IconData verdictIcon(ChoiceVerdict verdict) => switch (verdict) {
  ChoiceVerdict.good => Icons.check_circle_rounded,
  ChoiceVerdict.acceptable => Icons.info_rounded,
  ChoiceVerdict.bad => Icons.error_rounded,
  ChoiceVerdict.critical => Icons.dangerous_rounded,
};
