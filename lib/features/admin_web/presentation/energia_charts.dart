import 'package:material_ui/material_ui.dart';

import '../../../core/theme/energia_theme.dart';

/// Dependency-free consumption line chart.
///
/// Points are raw API maps: `label` and `actual` are read defensively so string
/// numbers and missing values never break the painter.
class EnergiaLineChart extends StatelessWidget {
  const EnergiaLineChart({
    required this.points,
    this.height = 220,
    super.key,
  });

  final List<Map<String, Object?>> points;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        key: const Key('energia-line-chart'),
        painter: _LineChartPainter(points),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter(this.points);

  final List<Map<String, Object?>> points;

  static double _number(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static void _text(
    Canvas canvas,
    String value,
    Offset offset, {
    double maxWidth = 180,
    Color color = EnergiaColors.slate,
    double fontSize = 10,
    FontWeight fontWeight = FontWeight.w600,
    TextAlign align = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    painter.paint(canvas, offset);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const left = 44.0;
    const right = 12.0;
    const top = 18.0;
    const bottom = 30.0;
    final plotWidth = size.width - left - right;
    final plotHeight = size.height - top - bottom;

    final gridPaint = Paint()
      ..color = EnergiaColors.deepNavy.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    for (var step = 0; step <= 4; step++) {
      final y = top + plotHeight * step / 4;
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), gridPaint);
    }
    canvas.drawLine(
      Offset(left, top + plotHeight),
      Offset(size.width - right, top + plotHeight),
      Paint()
        ..color = EnergiaColors.deepNavy.withValues(alpha: 0.45)
        ..strokeWidth = 1,
    );

    final values = <double>[];
    final labels = <String>[];
    for (final point in points) {
      values.add(_number(point['actual']));
      labels.add(point['label']?.toString() ?? '');
    }
    if (values.isEmpty || plotWidth <= 0 || plotHeight <= 0) {
      _text(
        canvas,
        'No chart data available',
        Offset(left, size.height / 2 - 7),
        maxWidth: plotWidth,
        align: TextAlign.center,
      );
      return;
    }

    var minValue = values.first;
    var maxValue = values.first;
    var maxIndex = 0;
    for (var index = 0; index < values.length; index++) {
      if (values[index] < minValue) minValue = values[index];
      if (values[index] > maxValue) {
        maxValue = values[index];
        maxIndex = index;
      }
    }
    if (minValue > 0) minValue = 0;
    if (maxValue <= minValue) maxValue = minValue + 1;
    final range = maxValue - minValue;

    final step = values.length == 1 ? 0.0 : plotWidth / (values.length - 1);
    final positions = [
      for (var index = 0; index < values.length; index++)
        Offset(
          left + step * index,
          top + plotHeight - ((values[index] - minValue) / range) * plotHeight,
        ),
    ];

    final area = Path();
    area.moveTo(positions.first.dx, top + plotHeight);
    for (final position in positions) {
      area.lineTo(position.dx, position.dy);
    }
    area.lineTo(positions.last.dx, top + plotHeight);
    area.close();
    canvas.drawPath(
      area,
      Paint()..color = EnergiaColors.teal.withValues(alpha: 0.12),
    );

    final line = Paint()
      ..color = EnergiaColors.teal
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke;
    for (var index = 1; index < positions.length; index++) {
      canvas.drawLine(positions[index - 1], positions[index], line);
    }

    for (final position in positions) {
      canvas.drawCircle(
        position,
        4.2,
        Paint()..color = EnergiaColors.electricLime,
      );
      canvas.drawCircle(
        position,
        4.2,
        Paint()
          ..color = EnergiaColors.deepNavy
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    _text(
      canvas,
      maxValue.toStringAsFixed(maxValue >= 100 ? 0 : 1),
      Offset(2, top - 5),
      maxWidth: left - 6,
    );
    _text(
      canvas,
      minValue.toStringAsFixed(minValue >= 100 ? 0 : 1),
      Offset(2, top + plotHeight - 11),
      maxWidth: left - 6,
    );

    for (final index in {0, values.length ~/ 2, values.length - 1}) {
      final position = positions[index];
      final width = step > 0 ? step.clamp(52.0, 110.0) : 110.0;
      _text(
        canvas,
        labels[index].isEmpty ? '—' : labels[index],
        Offset(position.dx - width / 2, top + plotHeight + 9),
        maxWidth: width,
        align: TextAlign.center,
      );
    }

    final peak = positions[maxIndex];
    _text(
      canvas,
      'max ${values[maxIndex].toStringAsFixed(values[maxIndex] >= 100 ? 0 : 1)}',
      Offset(peak.dx - 55, (peak.dy - 24).clamp(0.0, size.height - 12)),
      maxWidth: 110,
      color: EnergiaColors.deepNavy,
      fontWeight: FontWeight.w800,
      align: TextAlign.center,
    );
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.points != points;
}

/// Simplified Sankey-style site → department → meter flow diagram.
class EnergiaFlowDiagram extends StatelessWidget {
  const EnergiaFlowDiagram({
    required this.nodes,
    required this.links,
    this.height = 240,
    super.key,
  });

  final List<Map<String, Object?>> nodes;
  final List<Map<String, Object?>> links;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        key: const Key('energia-flow-diagram'),
        painter: _FlowPainter(nodes, links),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _FlowPainter extends CustomPainter {
  const _FlowPainter(this.nodes, this.links);

  final List<Map<String, Object?>> nodes;
  final List<Map<String, Object?>> links;

  static int _column(Object? type) {
    return switch (type?.toString().toLowerCase()) {
      'site' || 'sites' => 0,
      'meter' || 'meters' => 2,
      _ => 1,
    };
  }

  static void _text(
    Canvas canvas,
    String value,
    Offset offset, {
    required double maxWidth,
    Color color = EnergiaColors.deepNavy,
    double fontSize = 10,
    FontWeight fontWeight = FontWeight.w700,
    TextAlign align = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    painter.paint(canvas, offset);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (nodes.isEmpty) {
      _text(
        canvas,
        'No flow data available',
        Offset(12, size.height / 2 - 7),
        maxWidth: size.width - 24,
        align: TextAlign.center,
      );
      return;
    }

    const padding = 8.0;
    final nodeWidth = (size.width - 3 * padding * 2) / 3;
    final columns = <int, List<Map<String, Object?>>>{
      0: <Map<String, Object?>>[],
      1: <Map<String, Object?>>[],
      2: <Map<String, Object?>>[],
    };
    for (final node in nodes) {
      columns[_column(node['type'])]!.add(node);
    }

    final rects = <String, Rect>{};
    for (final entry in columns.entries) {
      final columnNodes = entry.value;
      if (columnNodes.isEmpty) continue;
      final spacing = (size.height - 24) / columnNodes.length;
      final nodeHeight = (spacing - 8).clamp(22.0, 42.0);
      for (var index = 0; index < columnNodes.length; index++) {
        final node = columnNodes[index];
        final x = padding + entry.key * (nodeWidth + padding * 2);
        final y = 12 + index * spacing + (spacing - nodeHeight) / 2;
        rects[node['id']?.toString() ?? ''] = Rect.fromLTWH(
          x,
          y,
          nodeWidth,
          nodeHeight,
        );
      }
    }

    var maxValue = 0.0;
    for (final link in links) {
      final value = link['value'];
      final parsed = value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0;
      if (parsed > maxValue) maxValue = parsed;
    }
    if (maxValue <= 0) maxValue = 1;

    for (var index = 0; index < links.length; index++) {
      final link = links[index];
      final source = rects[link['source']?.toString()];
      final target = rects[link['target']?.toString()];
      if (source == null || target == null) continue;
      final rawValue = link['value'];
      final value = rawValue is num
          ? rawValue.toDouble()
          : double.tryParse(rawValue?.toString() ?? '') ?? 0;
      final start = Offset(source.right, source.center.dy);
      final end = Offset(target.left, target.center.dy);
      final controlDx = (end.dx - start.dx) * 0.5;
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(
          start.dx + controlDx,
          start.dy,
          end.dx - controlDx,
          end.dy,
          end.dx,
          end.dy,
        );
      final color = index.isEven ? EnergiaColors.teal : EnergiaColors.electricLime;
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.45)
          ..strokeWidth = 1.5 + 4 * (value / maxValue)
          ..style = PaintingStyle.stroke,
      );
      _text(
        canvas,
        value.toStringAsFixed(value >= 100 ? 0 : 1),
        Offset(
          (start.dx + end.dx) / 2 - 22,
          (start.dy + end.dy) / 2 - 14,
        ),
        maxWidth: 44,
        color: EnergiaColors.slateNavy,
        fontSize: 9,
        align: TextAlign.center,
      );
    }

    for (final entry in rects.entries) {
      final node = nodes.firstWhere(
        (item) => item['id']?.toString() == entry.key,
        orElse: () => <String, Object?>{},
      );
      final rect = entry.value;
      final radius = Radius.circular(8);
      final rrect = RRect.fromRectAndRadius(rect, radius);
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = EnergiaColors.white
          ..style = PaintingStyle.fill,
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = EnergiaColors.deepNavy.withValues(alpha: 0.35)
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke,
      );
      _text(
        canvas,
        node['name']?.toString() ?? entry.key,
        Offset(rect.left + 7, rect.center.dy - 6),
        maxWidth: rect.width - 14,
        fontSize: 10,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FlowPainter oldDelegate) =>
      oldDelegate.nodes != nodes || oldDelegate.links != links;
}
