import 'package:material_ui/material_ui.dart';

import '../../../core/theme/energia_theme.dart';
import '../domain/personal_score.dart';

/// Dependency-free trend chart for the score history.
class ScoreTrendChart extends StatelessWidget {
  const ScoreTrendChart({required this.points, super.key});

  final List<ScoreHistoryPoint> points;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      child: CustomPaint(
        key: const Key('score-trend-chart'),
        painter: _ScoreTrendPainter(points),
      ),
    );
  }
}

class _ScoreTrendPainter extends CustomPainter {
  const _ScoreTrendPainter(this.points);

  final List<ScoreHistoryPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = EnergiaColors.line
      ..strokeWidth = 1;
    for (final level in const [0.0, 50.0, 100.0]) {
      final y = size.height - (level / 100) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    if (points.isEmpty) return;

    final step = points.length == 1
        ? 0.0
        : size.width / (points.length - 1);
    final positions = [
      for (var index = 0; index < points.length; index++)
        Offset(
          step * index,
          size.height - (points[index].score.clamp(0, 100) / 100) * size.height,
        ),
    ];
    final linePaint = Paint()
      ..color = EnergiaColors.teal
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    for (var index = 1; index < positions.length; index++) {
      canvas.drawLine(positions[index - 1], positions[index], linePaint);
    }
    final dotPaint = Paint()..color = EnergiaColors.deepNavy;
    for (final position in positions) {
      canvas.drawCircle(position, 4.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScoreTrendPainter oldDelegate) =>
      oldDelegate.points != points;
}
