import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../domain/competency.dart';

/// Радар компетенций — основная картинка аналитики.
///
/// Пятиугольник рисуется вручную через [CustomPainter], без графических
/// библиотек: форма простая, а зависимость тянуть не за чем. Провал по одной
/// оси видно сразу — именно это и нужно, чтобы показать «проседающую»
/// компетенцию.
class CompetencyRadar extends StatelessWidget {
  const CompetencyRadar({
    super.key,
    required this.points,
    required this.ceiling,
    this.weakest,
    this.size = 260,
  });

  /// Очки по каждой компетенции.
  final Map<Competency, int> points;

  /// Значение, которое считается 100% радиуса.
  final int ceiling;

  /// Ось, которую нужно подсветить как отстающую.
  final Competency? weakest;
  final double size;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RadarPainter(
            points: points,
            ceiling: ceiling == 0 ? 1 : ceiling,
            weakest: weakest,
            progress: progress,
            labelStyle: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: VsmColors.textSecondary,
            ),
            weakLabelStyle: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: VsmColors.danger,
            ),
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.points,
    required this.ceiling,
    required this.weakest,
    required this.progress,
    required this.labelStyle,
    required this.weakLabelStyle,
  });

  final Map<Competency, int> points;
  final int ceiling;
  final Competency? weakest;
  final double progress;
  final TextStyle labelStyle;
  final TextStyle weakLabelStyle;

  static const _axes = Competency.values;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    // Оставляем поля под подписи осей.
    final radius = size.shortestSide / 2 - 34;

    _drawGrid(canvas, center, radius);
    _drawShape(canvas, center, radius);
    _drawLabels(canvas, center, radius);
  }

  void _drawGrid(Canvas canvas, Offset center, double radius) {
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = VsmColors.stroke;

    // Четыре концентрических контура — «уровни» компетенции.
    for (var ring = 1; ring <= 4; ring++) {
      final path = Path();
      for (var i = 0; i < _axes.length; i++) {
        final offset = _vertex(center, radius * ring / 4, i);
        i == 0
            ? path.moveTo(offset.dx, offset.dy)
            : path.lineTo(offset.dx, offset.dy);
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    for (var i = 0; i < _axes.length; i++) {
      canvas.drawLine(center, _vertex(center, radius, i), gridPaint);
    }
  }

  void _drawShape(Canvas canvas, Offset center, double radius) {
    final path = Path();
    for (var i = 0; i < _axes.length; i++) {
      final value = (points[_axes[i]] ?? 0) / ceiling;
      // Минимальный радиус 6% — иначе у нового профиля фигура вырождается в точку.
      final scaled = (value.clamp(0.0, 1.0) * 0.94 + 0.06) * progress;
      final offset = _vertex(center, radius * scaled, i);
      i == 0
          ? path.moveTo(offset.dx, offset.dy)
          : path.lineTo(offset.dx, offset.dy);
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
          colors: [
            VsmColors.brand.withValues(alpha: 0.28),
            VsmColors.brand.withValues(alpha: 0.06),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = VsmColors.brand,
    );

    for (var i = 0; i < _axes.length; i++) {
      final value = (points[_axes[i]] ?? 0) / ceiling;
      final scaled = (value.clamp(0.0, 1.0) * 0.94 + 0.06) * progress;
      final offset = _vertex(center, radius * scaled, i);
      final isWeak = _axes[i] == weakest;
      canvas.drawCircle(
        offset,
        isWeak ? 4.5 : 3.5,
        Paint()..color = isWeak ? VsmColors.danger : VsmColors.brand,
      );
    }
  }

  void _drawLabels(Canvas canvas, Offset center, double radius) {
    for (var i = 0; i < _axes.length; i++) {
      final competency = _axes[i];
      final isWeak = competency == weakest;
      final anchor = _vertex(center, radius + 20, i);

      final painter = TextPainter(
        text: TextSpan(
          text: '${competency.label}\n${points[competency] ?? 0}',
          style: isWeak ? weakLabelStyle : labelStyle,
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 88);

      painter.paint(
        canvas,
        anchor - Offset(painter.width / 2, painter.height / 2),
      );
    }
  }

  /// Вершина правильного многоугольника: первая ось смотрит строго вверх.
  Offset _vertex(Offset center, double radius, int index) {
    final angle = -math.pi / 2 + index * 2 * math.pi / _axes.length;
    return center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.progress != progress ||
      old.ceiling != ceiling ||
      old.weakest != weakest ||
      !mapEquals(old.points, points);
}
