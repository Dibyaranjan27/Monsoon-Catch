import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../config/game_config.dart';
import '../../models/weather_state.dart';

/// Single procedural pine ridge silhouette layer with atmospheric fog blending
class PineRidgeLayer extends PositionComponent {
  final int seed;
  final double baseY;
  final double minTreeWidth;
  final double maxTreeWidth;
  final double minTreeHeight;
  final double maxTreeHeight;
  final double spacing;
  final Color baseColor;
  final double fogFactor; // 0.0 (no fog) to 1.0 (fully faded to horizon)
  final WeatherState weather;

  late final Path _cachedPath;

  PineRidgeLayer({
    required Vector2 size,
    required this.seed,
    required this.baseY,
    required this.minTreeWidth,
    required this.maxTreeWidth,
    required this.minTreeHeight,
    required this.maxTreeHeight,
    required this.spacing,
    required this.baseColor,
    required this.fogFactor,
    required this.weather,
    required int priority,
  }) : super(size: size, priority: priority) {
    _cachedPath = _generateRidgePath();
  }

  Path _generateRidgePath() {
    final path = Path();
    final rnd = Random(seed);
    double x = -20.0;

    while (x < size.x + 30.0) {
      final w = minTreeWidth + rnd.nextDouble() * (maxTreeWidth - minTreeWidth);
      final h = minTreeHeight + rnd.nextDouble() * (maxTreeHeight - minTreeHeight);
      final tiers = 3 + rnd.nextInt(3); // 3 to 5 tiers

      _addPineTree(path, x, baseY, w, h, tiers);

      x += spacing * (0.65 + rnd.nextDouble() * 0.70);
    }

    // Close path along the bottom
    path.lineTo(size.x + 30.0, size.y);
    path.lineTo(-20.0, size.y);
    path.close();

    return path;
  }

  void _addPineTree(
    Path path,
    double x,
    double treeBaseY,
    double w,
    double h,
    int tiers,
  ) {
    final trunkW = w * 0.15;
    final trunkH = h * 0.14;

    // Trunk
    path.addRect(
      Rect.fromLTWH(x - trunkW / 2, treeBaseY - trunkH, trunkW, trunkH),
    );

    // Drooping foliage tiers from bottom (0) to top (tiers - 1)
    for (int k = 0; k < tiers; k++) {
      final tierProgress = k / tiers;
      final tierBaseY = treeBaseY - trunkH - ((h - trunkH) * tierProgress);
      final tierW = w * (1.0 - 0.58 * tierProgress);
      final tierTipY =
          treeBaseY - trunkH - ((h - trunkH) * ((k + 1.25) / tiers));

      path.moveTo(x, tierTipY);
      path.lineTo(x - tierW / 2, tierBaseY);
      path.lineTo(x, tierBaseY - h * 0.04); // Center notch
      path.lineTo(x + tierW / 2, tierBaseY);
      path.close();
    }
  }

  @override
  void render(Canvas canvas) {
    // Atmospheric perspective: blend base pine color with current sky horizon color
    final horizonColor = weather.currentPalette.horizon;
    final effectiveFog = (fogFactor + weather.skyDarkness * 0.15).clamp(0.0, 0.95);
    final blendedColor =
        Color.lerp(baseColor, horizonColor, effectiveFog) ?? baseColor;

    final paint = Paint()
      ..color = blendedColor
      ..style = PaintingStyle.fill;

    canvas.drawPath(_cachedPath, paint);
  }
}

/// Composite coordinator for multi-layered procedural pine tree ridges
class PineForestComponent extends PositionComponent {
  final WeatherState weather;

  PineForestComponent({
    required Vector2 size,
    required this.weather,
  }) : super(
          size: size,
          priority: GameConfig.priorityFarPines,
        );

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // 1. Far Ridge (distant mountain silhouettes, high fog blend)
    add(
      PineRidgeLayer(
        size: size,
        seed: 101,
        baseY: size.y * 0.58, // ~208 px
        minTreeWidth: 16.0,
        maxTreeWidth: 26.0,
        minTreeHeight: 35.0,
        maxTreeHeight: 55.0,
        spacing: 14.0,
        baseColor: const Color(0xFF1E3838),
        fogFactor: 0.68,
        weather: weather,
        priority: GameConfig.priorityFarPines,
      ),
    );

    // 2. Midground Ridge (intermediate depth silhouettes)
    add(
      PineRidgeLayer(
        size: size,
        seed: 202,
        baseY: size.y * 0.62, // ~223 px
        minTreeWidth: 24.0,
        maxTreeWidth: 38.0,
        minTreeHeight: 50.0,
        maxTreeHeight: 75.0,
        spacing: 22.0,
        baseColor: const Color(0xFF162D2D),
        fogFactor: 0.38,
        weather: weather,
        priority: GameConfig.priorityMidPines,
      ),
    );

    // 3. Near / Bank Ridge (crisp foreground evergreen silhouettes)
    add(
      PineRidgeLayer(
        size: size,
        seed: 303,
        baseY: size.y * 0.65, // ~234 px
        minTreeWidth: 32.0,
        maxTreeWidth: 48.0,
        minTreeHeight: 65.0,
        maxTreeHeight: 95.0,
        spacing: 34.0,
        baseColor: const Color(0xFF0F2222),
        fogFactor: 0.12,
        weather: weather,
        priority: GameConfig.priorityBankTrees,
      ),
    );
  }
}
