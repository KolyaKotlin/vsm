import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Маршрутная линия, как на табло вагона: станция — путь — станция.
class RouteRibbon extends StatelessWidget {
  const RouteRibbon({
    super.key,
    this.from = 'Москва',
    this.to = 'Санкт-Петербург',
    this.fromDetail = 'Ленинградский вокзал',
    this.toDetail = 'Московский вокзал',
    this.light = false,
  });

  final String from;
  final String to;
  final String fromDetail;
  final String toDetail;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final ink = light ? Colors.white : VsmColors.textPrimary;
    final muted = light ? const Color(0xB3FFFFFF) : VsmColors.textMuted;
    final line = light ? const Color(0x66FFFFFF) : VsmColors.stroke;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _Station(
            name: from,
            detail: fromDetail,
            color: ink,
            muted: muted,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
          child: CustomPaint(
            painter: _TrackPainter(color: line, accent: VsmColors.brand),
            size: const Size(64, 14),
          ),
        ),
        Expanded(
          child: _Station(
            name: to,
            detail: toDetail,
            color: ink,
            muted: muted,
            alignEnd: true,
          ),
        ),
      ],
    );
  }
}

class _Station extends StatelessWidget {
  const _Station({
    required this.name,
    required this.detail,
    required this.color,
    required this.muted,
    this.alignEnd = false,
  });

  final String name;
  final String detail;
  final Color color;
  final Color muted;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final align = alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final textAlign = alignEnd ? TextAlign.right : TextAlign.left;

    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          name,
          textAlign: textAlign,
          style: TextStyle(
            fontSize: 13,
            height: 1.15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          detail,
          textAlign: textAlign,
          style: TextStyle(fontSize: 11, height: 1.2, color: muted),
        ),
      ],
    );
  }
}

class _TrackPainter extends CustomPainter {
  _TrackPainter({required this.color, required this.accent});

  final Color color;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final rail = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), rail);

    final sleeper = Paint()
      ..color = color
      ..strokeWidth = 1.4;
    for (var x = 8.0; x < size.width - 8; x += 10) {
      canvas.drawLine(Offset(x, y - 4), Offset(x, y + 4), sleeper);
    }

    canvas.drawCircle(Offset(0, y), 3.2, Paint()..color = accent);
    canvas.drawCircle(Offset(size.width, y), 3.2, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      old.color != color || old.accent != accent;
}

/// Табло отправления — тёмная ливрея с красной полосой, как нос состава.
class DestinationBoard extends StatelessWidget {
  const DestinationBoard({
    super.key,
    this.train = 'ВСМ-001',
    this.run = '717',
    this.from = 'Москва',
    this.to = 'Санкт-Петербург',
    this.fromStation = 'Ленинградский вокзал',
    this.toStation = 'Московский вокзал',
    this.duration = '2 ч 15 мин',
    this.subtitle = 'Поездная бригада',
  });

  final String train;
  final String run;
  final String from;
  final String to;
  final String fromStation;
  final String toStation;
  final String duration;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(VsmSpacing.cardRadius),
      child: Column(
        children: [
          Container(height: 6, color: VsmColors.brand),
          const ColoredBox(
            color: Color(0xFFE4C56A),
            child: SizedBox(height: 2, width: double.infinity),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            decoration: const BoxDecoration(gradient: VsmGradients.livery),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.train_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            train,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'рейс $run',
                            style: const TextStyle(
                              color: Color(0xFFE4C56A),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          duration,
                          style: const TextStyle(
                            color: Color(0xFFE4C56A),
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'в пути',
                          style: TextStyle(
                            color: Color(0xB3FFFFFF),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                RouteRibbon(
                  from: from,
                  to: to,
                  fromDetail: fromStation,
                  toDetail: toStation,
                  light: true,
                ),
                const SizedBox(height: 12),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xB3FFFFFF),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Карточка в виде посадочного талона: красный корешок слева.
class TicketCard extends StatelessWidget {
  const TicketCard({
    super.key,
    required this.child,
    this.onTap,
    this.accent,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 16),
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? accent;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final stripe = accent ?? VsmColors.brand;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: VsmColors.surface,
        borderRadius: BorderRadius.circular(VsmSpacing.cardRadius),
        border: Border.all(color: VsmColors.stroke),
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
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 8,
                  decoration: BoxDecoration(
                    color: stripe,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(VsmSpacing.cardRadius - 1),
                    ),
                  ),
                ),
                const SizedBox(
                  width: 12,
                  child: CustomPaint(painter: _StubPerforationPainter()),
                ),
                Expanded(
                  child: Padding(padding: padding, child: child),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Номерная табличка вагона: тёмный металл и красная полоса сверху.
class PlateMark extends StatelessWidget {
  const PlateMark({
    super.key,
    required this.label,
    this.width = 46,
    this.height = 52,
  });

  final String label;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: VsmColors.livery,
        border: Border(top: BorderSide(color: VsmColors.brand, width: 3)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: Colors.white,
          fontSize: 22,
          height: 1,
        ),
      ),
    );
  }
}

/// Фон салона: тёплый градиент панелей, без полосы по верхнему краю.
class CabinBackground extends StatelessWidget {
  const CabinBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: VsmGradients.cabin),
      child: child,
    );
  }
}

class _StubPerforationPainter extends CustomPainter {
  const _StubPerforationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final hole = Paint()..color = const Color(0xFFC4B294);
    final x = size.width / 2;
    for (var y = 6.0; y < size.height - 4; y += 8) {
      canvas.drawCircle(Offset(x, y), 1.5, hole);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
