import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../config/game_config.dart';
import '../../models/weather_state.dart';

/// Procedural gradient sky component dynamically rendering
/// a 4-stop linear vertical gradient responsive to weather conditions.
class SkyComponent extends PositionComponent {
  final WeatherState weather;

  SkyComponent({
    required Vector2 size,
    required this.weather,
  }) : super(
          size: size,
          priority: GameConfig.prioritySky,
        );

  @override
  void render(Canvas canvas) {
    // Sky covers upper ~68% of virtual height where pine ridges meet the horizon
    final skyHeight = size.y * 0.68;
    final rect = Rect.fromLTWH(0, 0, size.x, skyHeight);

    final palette = weather.currentPalette;

    // Apply lightning flash brightness modulation if active
    Color applyFlash(Color c) {
      if (weather.lightningFlash <= 0.0) return c;
      return Color.lerp(c, Colors.white, weather.lightningFlash * 0.75) ?? c;
    }

    final shader = ui.Gradient.linear(
      Offset.zero,
      Offset(0, skyHeight),
      [
        applyFlash(palette.zenith),
        applyFlash(palette.mid),
        applyFlash(palette.low),
        applyFlash(palette.horizon),
      ],
      const [0.0, 0.45, 0.80, 1.00],
    );

    final paint = Paint()..shader = shader;
    canvas.drawRect(rect, paint);
  }
}
