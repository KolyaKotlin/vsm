import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Кольцевой таймер критического решения.
///
/// Меняет цвет по мере истечения времени и начинает пульсировать в последней
/// трети — таймер должен давить, иначе он декоративный.
class TimerRing extends StatelessWidget {
  const TimerRing({
    super.key,
    required this.secondsLeft,
    required this.totalSeconds,
    this.size = 62,
  });

  final int secondsLeft;
  final int totalSeconds;
  final double size;

  double get _fraction =>
      totalSeconds == 0 ? 0 : (secondsLeft / totalSeconds).clamp(0.0, 1.0);

  Color get color {
    if (_fraction > 0.5) return VsmColors.safety;
    if (_fraction > 0.25) return VsmColors.loyalty;
    return VsmColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final urgent = _fraction <= 0.33;

    return TweenAnimationBuilder<double>(
      tween: Tween(end: _fraction),
      duration: const Duration(milliseconds: 950),
      curve: Curves.linear,
      builder: (context, animatedFraction, _) {
        return _Pulse(
          active: urgent,
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _RingPainter(fraction: animatedFraction, color: color),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$secondsLeft',
                      style: TextStyle(
                        fontSize: size * 0.34,
                        fontWeight: FontWeight.w800,
                        color: color,
                        height: 1,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      'сек',
                      style: TextStyle(
                        fontSize: size * 0.14,
                        fontWeight: FontWeight.w600,
                        color: VsmColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - 6) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = VsmColors.stroke;
    canvas.drawCircle(center, radius, track);

    final progress = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [color.withValues(alpha: 0.35), color],
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
      ).createShader(rect);

    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * fraction, false, progress);

    // Свечение по дуге усиливает ощущение уходящего времени.
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * fraction, false, glow);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.color != color;
}

/// Бесконечная пульсация, включается только когда времени мало.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.child, required this.active});

  final Widget child;
  final bool active;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 780),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_Pulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) =>
          Transform.scale(scale: 1 + _controller.value * 0.07, child: child),
      child: widget.child,
    );
  }
}
