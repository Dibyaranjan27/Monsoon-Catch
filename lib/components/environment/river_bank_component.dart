import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../config/game_config.dart';
import '../../models/weather_state.dart';

/// Procedural riverbank terrain cross-section on the left side (x <= 0.32 * W)
/// featuring damp peat soil strata, grassy turf cap, and shoreline contours.
class RiverBankComponent extends PositionComponent {
  final WeatherState weather;

  // Cached geometry paths to eliminate per-frame heap allocations
  final Path _soilPath = Path();
  final Path _turfPath = Path();
  final Path _rimPath = Path();

  // Cached shoreline foam strip endpoints
  Offset _foamStart = Offset.zero;
  Offset _foamEnd = Offset.zero;

  double _cachedWidth = 0.0;
  double _cachedHeight = 0.0;

  // Reusable paint instances to eliminate per-frame GC churn
  final Paint _soilPaint = Paint()..style = PaintingStyle.fill;
  final Paint _turfPaint = Paint()..style = PaintingStyle.fill;
  final Paint _rimPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;
  final Paint _contactFoamPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.35)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  RiverBankComponent({
    required Vector2 size,
    required this.weather,
  }) : super(
          size: size,
          priority: GameConfig.priorityRiverBank,
        ) {
    _ensurePaths();
  }

  /// Populates cached vector paths for current component dimensions.
  void _ensurePaths() {
    if (_cachedWidth == size.x && _cachedHeight == size.y) return;
    _cachedWidth = size.x;
    _cachedHeight = size.y;

    final bankWidth = size.x * 0.32; // ~204.8 px at 640 width
    final bankPlatformY = size.y * 0.58; // ~208.8 px
    final waterContactY = size.y * 0.65; // ~234.0 px

    // 1. Deep peat soil cross-section
    _soilPath
      ..reset()
      ..moveTo(0, bankPlatformY)
      ..lineTo(bankWidth * 0.65, bankPlatformY)
      ..cubicTo(
        bankWidth * 0.85,
        bankPlatformY,
        bankWidth * 0.78,
        waterContactY,
        bankWidth,
        waterContactY,
      )
      ..lineTo(bankWidth, size.y)
      ..lineTo(0, size.y)
      ..close();

    // 2. Grassy Turf Cap (lush green platform surface)
    _turfPath
      ..reset()
      ..moveTo(0, bankPlatformY)
      ..lineTo(bankWidth * 0.65, bankPlatformY)
      ..cubicTo(
        bankWidth * 0.82,
        bankPlatformY,
        bankWidth * 0.74,
        bankPlatformY + 12,
        bankWidth * 0.88,
        bankPlatformY + 14,
      )
      ..lineTo(bankWidth * 0.82, bankPlatformY + 18)
      ..lineTo(0, bankPlatformY + 16)
      ..close();

    // 3. Highlight edge on top grass rim
    _rimPath
      ..reset()
      ..moveTo(0, bankPlatformY + 1)
      ..lineTo(bankWidth * 0.65, bankPlatformY + 1)
      ..cubicTo(
        bankWidth * 0.82,
        bankPlatformY + 1,
        bankWidth * 0.74,
        bankPlatformY + 11,
        bankWidth * 0.88,
        bankPlatformY + 13,
      );

    // 4. Shoreline foam contact strip endpoints
    _foamStart = Offset(bankWidth - 8.0, waterContactY);
    _foamEnd = Offset(bankWidth + 4.0, waterContactY + 2.0);
  }

  @override
  void render(Canvas canvas) {
    _ensurePaths();

    // Peat color darkens in heavy rain/monsoon
    final Color soilColor;
    switch (weather.currentType) {
      case WeatherType.clearDawn:
        soilColor = const Color(0xFF332018);
        break;
      case WeatherType.clearDay:
        soilColor = const Color(0xFF2C1E18);
        break;
      case WeatherType.overcast:
        soilColor = const Color(0xFF241813);
        break;
      case WeatherType.monsoon:
        soilColor = const Color(0xFF170F0B);
        break;
    }
    _soilPaint.color = soilColor;
    canvas.drawPath(_soilPath, _soilPaint);

    // Grassy Turf Cap
    final Color turfColor;
    switch (weather.currentType) {
      case WeatherType.clearDawn:
        turfColor = const Color(0xFF436F39);
        break;
      case WeatherType.clearDay:
        turfColor = const Color(0xFF386641);
        break;
      case WeatherType.overcast:
        turfColor = const Color(0xFF2D5034);
        break;
      case WeatherType.monsoon:
        turfColor = const Color(0xFF1B382B);
        break;
    }
    _turfPaint.color = turfColor;
    canvas.drawPath(_turfPath, _turfPaint);

    // Highlight edge on top grass rim
    _rimPaint.color = Colors.lightGreenAccent.withValues(
      alpha: weather.currentType == WeatherType.monsoon ? 0.15 : 0.40,
    );
    canvas.drawPath(_rimPath, _rimPaint);

    // Shoreline foam contact strip
    canvas.drawLine(_foamStart, _foamEnd, _contactFoamPaint);
  }
}
