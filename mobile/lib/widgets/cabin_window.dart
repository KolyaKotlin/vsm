import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Затемнение, как ночной перрон за стеклом, а не серая вуаль Material.
const cabinBarrier = Color(0xCC121820);

/// Диалог в раме вагонного окна: тёмный металл, красная ливрея, бланк внутри.
class CabinDialog extends StatelessWidget {
  const CabinDialog({
    super.key,
    required this.title,
    this.plate = 'Окно',
    this.actions = const [],
    required this.child,
  });

  final String title;
  final String plate;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: CabinFrame(
        plate: plate,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            child,
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 16),
              if (actions.length == 1)
                actions.first
              else
                Row(
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: actions[i]),
                    ],
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Нижняя шторка в той же раме: дверь купе, а не скруглённая карточка.
class CabinSheet extends StatelessWidget {
  const CabinSheet({
    super.key,
    required this.title,
    this.plate = 'Купе',
    this.subtitle,
    required this.child,
  });

  final String title;
  final String plate;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: CabinFrame(
        plate: plate,
        squareBottom: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: VsmColors.textMuted,
                ),
              ),
            ],
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

/// Общая рама: ливрея снаружи, перфорация, кремовый бланк.
class CabinFrame extends StatelessWidget {
  const CabinFrame({
    super.key,
    required this.plate,
    this.squareBottom = false,
    required this.child,
  });

  final String plate;
  final Widget child;
  final bool squareBottom;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.vertical(
      top: const Radius.circular(8),
      bottom: Radius.circular(squareBottom ? 0 : 8),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: VsmColors.livery,
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x59121820),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ColoredBox(
              color: VsmColors.brand,
              child: SizedBox(height: 5, width: double.infinity),
            ),
            const ColoredBox(
              color: Color(0xFFE4C56A),
              child: SizedBox(height: 2, width: double.infinity),
            ),
            ColoredBox(
              color: const Color(0xFF243044),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 7, 14, 7),
                child: Row(
                  children: [
                    Text(
                      plate,
                      style: const TextStyle(
                        color: Color(0xFFE4C56A),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.train_rounded,
                      size: 15,
                      color: Color(0x99FFFFFF),
                    ),
                  ],
                ),
              ),
            ),
            ColoredBox(
              color: VsmColors.surface,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    height: 12,
                    width: double.infinity,
                    child: CustomPaint(painter: _PerforationPainter()),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
                    child: child,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PerforationPainter extends CustomPainter {
  const _PerforationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final hole = Paint()..color = const Color(0xFF243044);
    final y = size.height / 2;
    for (var x = 8.0; x < size.width - 4; x += 9) {
      canvas.drawCircle(Offset(x, y), 1.7, hole);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
