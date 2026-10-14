import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../config/game_config.dart';
import '../../models/weather_state.dart';

/// Single procedural cloud rendered using multi-puff geometry
/// with 2-tone pixel-art shading (base shadow underbelly + sunlit highlight cap).
class ProceduralCloud extends PositionComponent {
  final double baseSpeed;
  final WeatherState weather;
  final double parallaxFactor;

  ProceduralCloud({
    required Vector2 position,
    required Vector2 size,
    required this.baseSpeed,
    required this.weather,
    this.parallaxFactor = 1.0,
  }) : super(position: position, size: size);

  @override
  void update(double dt) {
    super.update(dt);
    // Kinematic horizontal drift driven by weather windSpeed
    final effectiveSpeed = baseSpeed * (1.0 + weather.windSpeed * 1.8) * parallaxFactor;
    position.x -= effectiveSpeed * dt;

    // Wrap around screen right when exiting left edge
    if (position.x + size.x < -20.0) {
      final parentWidth = (parent as PositionComponent?)?.size.x ?? GameConfig.virtualWidth;
      position.x = parentWidth + 20.0;
    }
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    // Determine colors based on weather state
    final Color highlightColor;
    final Color shadowColor;

    switch (weather.currentType) {
      case WeatherType.clearDawn:
        highlightColor = const Color(0xFFFDE68A);
        shadowColor = const Color(0xFFD97706);
        break;
      case WeatherType.clearDay:
        highlightColor = const Color(0xFFFFFFFF);
        shadowColor = const Color(0xFFCBD5E1);
        break;
      case WeatherType.overcast:
        highlightColor = const Color(0xFFCBD5E1);
        shadowColor = const Color(0xFF64748B);
        break;
      case WeatherType.monsoon:
        highlightColor = const Color(0xFF64748B);
        shadowColor = const Color(0xFF334155);
        break;
    }

    // Shadow / base puff layer
    final shadowPaint = Paint()
      ..color = shadowColor
      ..style = PaintingStyle.fill;

    // Highlight / sunlit cap layer
    final highlightPaint = Paint()
      ..color = highlightColor
      ..style = PaintingStyle.fill;

    // 1. Flat underbelly rounded rectangle
    final baseRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, h * 0.45, w, h * 0.55),
      Radius.circular(h * 0.25),
    );
    canvas.drawRRect(baseRRect, shadowPaint);

    // 2. Overlapping cumulus domes (shadow pass)
    final puffs = [
      Offset(w * 0.50, h * 0.42), // Main center dome
      Offset(w * 0.30, h * 0.52), // Left mid dome
      Offset(w * 0.70, h * 0.50), // Right mid dome
      Offset(w * 0.14, h * 0.64), // Left edge puff
      Offset(w * 0.86, h * 0.64), // Right edge puff
    ];
    final radii = [h * 0.42, h * 0.32, h * 0.34, h * 0.22, h * 0.20];

    for (int i = 0; i < puffs.length; i++) {
      canvas.drawCircle(puffs[i], radii[i], shadowPaint);
    }

    // 3. Highlight pass: drawn upward-shifted and slightly scaled
    final highlightRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.05, h * 0.38, w * 0.90, h * 0.50),
      Radius.circular(h * 0.22),
    );
    canvas.drawRRect(highlightRRect, highlightPaint);

    for (int i = 0; i < puffs.length; i++) {
      final shiftedCenter = puffs[i] - Offset(0, h * 0.09);
      canvas.drawCircle(shiftedCenter, radii[i] * 0.82, highlightPaint);
    }
  }
}

/// Cloud layer coordinator hosting multiple procedural drifting clouds
class CloudLayerComponent extends PositionComponent {
  final WeatherState weather;

  CloudLayerComponent({
    required Vector2 size,
    required this.weather,
  }) : super(
          size: size,
          priority: GameConfig.priorityClouds,
        );

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Staggered cloud formations across the sky with varying heights and speeds
    final clouds = [
      ProceduralCloud(
        position: Vector2(60, 25),
        size: Vector2(130, 48),
        baseSpeed: 12.0,
        weather: weather,
        parallaxFactor: 0.8,
      ),
      ProceduralCloud(
        position: Vector2(240, 65),
        size: Vector2(160, 56),
        baseSpeed: 16.0,
        weather: weather,
        parallaxFactor: 1.1,
      ),
      ProceduralCloud(
        position: Vector2(450, 20),
        size: Vector2(110, 42),
        baseSpeed: 10.0,
        weather: weather,
        parallaxFactor: 0.7,
      ),
      ProceduralCloud(
        position: Vector2(580, 80),
        size: Vector2(140, 50),
        baseSpeed: 14.0,
        weather: weather,
        parallaxFactor: 1.0,
      ),
      ProceduralCloud(
        position: Vector2(-80, 50),
        size: Vector2(120, 44),
        baseSpeed: 13.0,
        weather: weather,
        parallaxFactor: 0.9,
      ),
    ];

    for (final cloud in clouds) {
      add(cloud);
    }
  }
}
