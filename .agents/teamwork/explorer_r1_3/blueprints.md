# Code Blueprints: Procedural Environment Components

This document contains reference implementations and component architectures designed for Requirement R1 implementation.

```dart
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Weather presets driving the procedural environment
enum WeatherPreset { clearDawn, clearDay, overcast, monsoonStorm }

/// Unified weather parameters model
class WeatherEnvironmentState {
  WeatherPreset preset;
  double rainIntensity; // 0.0 to 1.0
  double windSpeed; // 0.0 to 1.0
  double overcast; // 0.0 to 1.0
  double lightningFlash; // 0.0 to 1.0 (flash intensity)

  WeatherEnvironmentState({
    this.preset = WeatherPreset.clearDay,
    this.rainIntensity = 0.0,
    this.windSpeed = 0.3,
    this.overcast = 0.0,
    this.lightningFlash = 0.0,
  });

  /// Turbulence factor for wave physics
  double get turbulence => 0.35 + (1.85 * rainIntensity) + (0.50 * windSpeed);
}

/// Sky palette defining 4 vertical gradient stops
class SkyPalette {
  final Color zenith; // Top of sky (0.0)
  final Color mid; // Upper mid sky (0.45)
  final Color low; // Lower sky (0.80)
  final Color horizon; // Ridge line (1.0)

  const SkyPalette({
    required this.zenith,
    required this.mid,
    required this.low,
    required this.horizon,
  });

  static const SkyPalette clearDawn = SkyPalette(
    zenith: Color(0xFF1E2243),
    mid: Color(0xFFD3685C),
    low: Color(0xFFEAA254),
    horizon: Color(0xFFF9D199),
  );

  static const SkyPalette clearDay = SkyPalette(
    zenith: Color(0xFF3B82C4),
    mid: Color(0xFF67B0E8),
    low: Color(0xFF93C5FD),
    horizon: Color(0xFFBAE6FD),
  );

  static const SkyPalette overcast = SkyPalette(
    zenith: Color(0xFF475569),
    mid: Color(0xFF64748B),
    low: Color(0xFF94A3B8),
    horizon: Color(0xFFCBD5E1),
  );

  static const SkyPalette monsoonStorm = SkyPalette(
    zenith: Color(0xFF0F172A),
    mid: Color(0xFF1E293B),
    low: Color(0xFF334155),
    horizon: Color(0xFF233043),
  );

  static SkyPalette forPreset(WeatherPreset preset) {
    switch (preset) {
      case WeatherPreset.clearDawn:
        return clearDawn;
      case WeatherPreset.clearDay:
        return clearDay;
      case WeatherPreset.overcast:
        return overcast;
      case WeatherPreset.monsoonStorm:
        return monsoonStorm;
    }
  }

  static SkyPalette lerp(SkyPalette a, SkyPalette b, double t) {
    return SkyPalette(
      zenith: Color.lerp(a.zenith, b.zenith, t) ?? a.zenith,
      mid: Color.lerp(a.mid, b.mid, t) ?? a.mid,
      low: Color.lerp(a.low, b.low, t) ?? a.low,
      horizon: Color.lerp(a.horizon, b.horizon, t) ?? a.horizon,
    );
  }
}

/// 1. Procedural Gradient Sky Component
class ProceduralSkyComponent extends PositionComponent {
  final WeatherEnvironmentState weather;
  SkyPalette _currentPalette;

  ProceduralSkyComponent({required Vector2 size, required this.weather})
      : _currentPalette = SkyPalette.forPreset(weather.preset),
        super(size: size);

  @override
  void update(double dt) {
    super.update(dt);
    final target = SkyPalette.forPreset(weather.preset);
    // Smooth transition towards target palette
    _currentPalette = SkyPalette.lerp(_currentPalette, target, (dt * 2.5).clamp(0.0, 1.0));
  }

  @override
  void render(Canvas canvas) {
    final skyHeight = size.y * 0.65; // Sky spans top 65% of viewport
    final rect = Rect.fromLTWH(0, 0, size.x, skyHeight);

    // Apply lightning flash if active
    Color applyFlash(Color c) {
      if (weather.lightningFlash <= 0.0) return c;
      return Color.lerp(c, Colors.white, weather.lightningFlash * 0.7) ?? c;
    }

    final shader = ui.Gradient.linear(
      Offset.zero,
      Offset(0, skyHeight),
      [
        applyFlash(_currentPalette.zenith),
        applyFlash(_currentPalette.mid),
        applyFlash(_currentPalette.low),
        applyFlash(_currentPalette.horizon),
      ],
      const [0.0, 0.45, 0.80, 1.00],
    );

    final paint = Paint()..shader = shader;
    canvas.drawRect(rect, paint);
  }
}

/// 2. Floating Procedural Cloud Component
class ProceduralCloud extends PositionComponent {
  final double baseSpeed;
  final WeatherEnvironmentState weather;
  final double opacity;
  final Color shadowColor;
  final Color highlightColor;

  ProceduralCloud({
    required Vector2 position,
    required Vector2 size,
    required this.baseSpeed,
    required this.weather,
    this.opacity = 1.0,
    this.shadowColor = const Color(0xFFCBD5E1),
    this.highlightColor = const Color(0xFFFFFFFF),
  }) : super(position: position, size: size);

  @override
  void update(double dt) {
    super.update(dt);
    // Drift horizontally to the left (monsoon wind direction)
    final effectiveSpeed = baseSpeed * (1.0 + weather.windSpeed * 1.5);
    position.x -= effectiveSpeed * dt;

    // Wrap around screen right when cloud exits left edge
    if (position.x + size.x < 0) {
      position.x = (parent as PositionComponent?)?.size.x ?? 320.0;
    }
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    // Shadow / base puff layer
    final shadowPaint = Paint()
      ..color = shadowColor.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    // Highlight / top crest layer
    final highlightPaint = Paint()
      ..color = highlightColor.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    // Base rounded rect
    final baseRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, h * 0.45, w, h * 0.55),
      Radius.circular(h * 0.25),
    );
    canvas.drawRRect(baseRRect, shadowPaint);

    // Overlapping dome circles
    final puffs = [
      Offset(w * 0.50, h * 0.42), // Center
      Offset(w * 0.30, h * 0.52), // Left mid
      Offset(w * 0.70, h * 0.50), // Right mid
      Offset(w * 0.14, h * 0.64), // Left edge
      Offset(w * 0.86, h * 0.64), // Right edge
    ];
    final radii = [h * 0.42, h * 0.32, h * 0.34, h * 0.22, h * 0.20];

    // Draw shadow domes
    for (int i = 0; i < puffs.length; i++) {
      canvas.drawCircle(puffs[i], radii[i], shadowPaint);
    }

    // Draw highlight domes (slightly offset up and shrunk)
    for (int i = 0; i < puffs.length; i++) {
      final shiftedCenter = puffs[i] - Offset(0, h * 0.08);
      canvas.drawCircle(shiftedCenter, radii[i] * 0.85, highlightPaint);
    }
  }
}

/// 3. Procedural Pine Tree Silhouettes Component
class PineSilhouetteRidgeComponent extends PositionComponent {
  final int seed;
  final double baseY;
  final double minTreeWidth;
  final double maxTreeWidth;
  final double minTreeHeight;
  final double maxTreeHeight;
  final double spacing;
  final Color baseColor;
  final double fogFactor; // Aerial perspective fog blend
  final WeatherEnvironmentState weather;

  late Path _cachedPath;

  PineSilhouetteRidgeComponent({
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
  }) : super(size: size) {
    _generateRidge();
  }

  void _generateRidge() {
    _cachedPath = Path();
    final rnd = Random(seed);
    double x = -10.0;

    while (x < size.x + 20.0) {
      final w = minTreeWidth + rnd.nextDouble() * (maxTreeWidth - minTreeWidth);
      final h = minTreeHeight + rnd.nextDouble() * (maxTreeHeight - minTreeHeight);
      final tiers = 3 + rnd.nextInt(2);

      // Add single tree path to combined ridge path
      _addPineTree(_cachedPath, x, baseY, w, h, tiers);

      x += spacing * (0.65 + rnd.nextDouble() * 0.70);
    }

    // Close path along the bottom
    _cachedPath.lineTo(size.x + 20.0, size.y);
    _cachedPath.lineTo(-10.0, size.y);
    _cachedPath.close();
  }

  void _addPineTree(Path path, double x, double treeBaseY, double w, double h, int tiers) {
    final trunkW = w * 0.12;
    final trunkH = h * 0.15;

    // Foliage tiers from bottom to top
    for (int k = 0; k < tiers; k++) {
      final tierBaseY = treeBaseY - trunkH - ((h - trunkH) * (k / tiers));
      final tierW = w * (1.0 - 0.65 * (k / tiers));
      final tierTipY = treeBaseY - trunkH - ((h - trunkH) * ((k + 1.25) / tiers));

      path.moveTo(x, tierTipY);
      path.lineTo(x - tierW / 2, tierBaseY);
      path.lineTo(x, tierBaseY - h * 0.04); // subtle center notch
      path.lineTo(x + tierW / 2, tierBaseY);
      path.close();
    }
  }

  @override
  void render(Canvas canvas) {
    // Aerial perspective fog color
    final horizonColor = SkyPalette.forPreset(weather.preset).horizon;
    final blendedColor = Color.lerp(baseColor, horizonColor, fogFactor) ?? baseColor;

    final paint = Paint()
      ..color = blendedColor
      ..style = PaintingStyle.fill;

    canvas.drawPath(_cachedPath, paint);
  }
}

/// 4. Procedural Riverbank Component
class RiverBankComponent extends PositionComponent {
  final WeatherEnvironmentState weather;

  RiverBankComponent({required Vector2 size, required this.weather}) : super(size: size);

  @override
  void render(Canvas canvas) {
    final bankWidth = size.x * 0.32;
    final bankPlatformY = size.y * 0.58;
    final waterContactY = size.y * 0.65;

    // 1. Soil Cliff Body Path
    final soilPath = Path()
      ..moveTo(0, bankPlatformY)
      ..lineTo(bankWidth * 0.65, bankPlatformY)
      ..cubicTo(
        bankWidth * 0.85, bankPlatformY,
        bankWidth * 0.75, waterContactY,
        bankWidth, waterContactY,
      )
      ..lineTo(bankWidth, size.y)
      ..lineTo(0, size.y)
      ..close();

    final soilColor = weather.preset == WeatherPreset.monsoonStorm
        ? const Color(0xFF1B1410)
        : const Color(0xFF2C1E18);

    canvas.drawPath(soilPath, Paint()..color = soilColor);

    // 2. Grassy Turf Cap
    final turfPath = Path()
      ..moveTo(0, bankPlatformY)
      ..lineTo(bankWidth * 0.65, bankPlatformY)
      ..cubicTo(
        bankWidth * 0.80, bankPlatformY,
        bankWidth * 0.72, bankPlatformY + 12,
        bankWidth * 0.85, bankPlatformY + 14,
      )
      ..lineTo(bankWidth * 0.82, bankPlatformY + 18)
      ..lineTo(0, bankPlatformY + 14)
      ..close();

    final turfColor = weather.preset == WeatherPreset.monsoonStorm
        ? const Color(0xFF1B382B)
        : const Color(0xFF386641);

    canvas.drawPath(turfPath, Paint()..color = turfColor);
  }
}

/// 5. Animated Procedural Water Surface Component
class WaterSurfaceComponent extends PositionComponent {
  final WeatherEnvironmentState weather;
  double _time = 0.0;

  // Rain ripple pool
  final List<_WaterRipple> _ripples = [];
  final Random _rnd = Random();
  double _timeSinceRipple = 0.0;

  WaterSurfaceComponent({required Vector2 size, required this.weather}) : super(size: size);

  @override
  void update(double dt) {
    super.update(dt);
    final timeScale = 1.0 + (weather.rainIntensity * 0.6);
    _time += dt * timeScale;

    // Spawn raindrops ripples in water zone
    if (weather.rainIntensity > 0.0) {
      _timeSinceRipple += dt;
      final spawnInterval = 0.20 / (weather.rainIntensity * 3.0 + 0.1);
      if (_timeSinceRipple >= spawnInterval) {
        _timeSinceRipple = 0.0;
        final startX = size.x * 0.30 + _rnd.nextDouble() * (size.x * 0.70);
        final startY = size.y * 0.65 + _rnd.nextDouble() * (size.y * 0.32);
        _ripples.add(_WaterRipple(position: Offset(startX, startY)));
      }
    }

    // Update ripples
    for (final r in _ripples) {
      r.update(dt);
    }
    _ripples.removeWhere((r) => r.isDead);
  }

  /// Multi-frequency wave elevation formula
  double waveElevation(double x, double t) {
    final turb = weather.turbulence;
    final w1 = 2.5 * turb * sin((2 * pi / 90.0) * x - 1.8 * t);
    final w2 = 1.2 * turb * sin((2 * pi / 35.0) * x - 3.6 * t + 1.2);
    final w3 = 0.5 * turb * sin((2 * pi / 14.0) * x - 6.5 * t + 2.5);
    return w1 + w2 + w3;
  }

  @override
  void render(Canvas canvas) {
    final startX = size.x * 0.30;
    final baseY = size.y * 0.65;
    const step = 4.0;

    // 1. Construct Water Surface & Body Path
    final waterPath = Path();
    final crestPath = Path();

    final firstY = baseY + waveElevation(startX, _time);
    waterPath.moveTo(startX, firstY);
    crestPath.moveTo(startX, firstY);

    for (double x = startX + step; x <= size.x; x += step) {
      final y = baseY + waveElevation(x, _time);
      waterPath.lineTo(x, y);
      crestPath.lineTo(x, y);
    }

    // Close water polygon around viewport bottom
    waterPath.lineTo(size.x, size.y);
    waterPath.lineTo(startX, size.y);
    waterPath.close();

    // 2. Depth Gradient Shader
    final isStorm = weather.preset == WeatherPreset.monsoonStorm;
    final surfaceColor = isStorm ? const Color(0xFF1E3A42) : const Color(0xFF38A3A5);
    final midColor = isStorm ? const Color(0xFF142733) : const Color(0xFF22577A);
    final abyssColor = isStorm ? const Color(0xFF081017) : const Color(0xFF0F1E29);

    final waterShader = ui.Gradient.linear(
      Offset(0, baseY),
      Offset(0, size.y),
      [surfaceColor, midColor, abyssColor],
      const [0.0, 0.40, 1.00],
    );

    canvas.drawPath(waterPath, Paint()..shader = waterShader);

    // 3. Crest Highlight Stroke
    final crestColor = isStorm
        ? const Color(0x7794A3B8)
        : const Color(0xAAFFFFFF);

    final crestPaint = Paint()
      ..color = crestColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawPath(crestPath, crestPaint);

    // 4. Render Raindrop Impact Ripples
    for (final ripple in _ripples) {
      ripple.render(canvas);
    }
  }
}

class _WaterRipple {
  final Offset position;
  double age = 0.0;
  static const double maxAge = 0.6; // Lifetime in seconds
  static const double spreadSpeed = 25.0; // Px per second

  _WaterRipple({required this.position});

  bool get isDead => age >= maxAge;

  void update(double dt) {
    age += dt;
  }

  void render(Canvas canvas) {
    final progress = age / maxAge;
    final alpha = (1.0 - progress).clamp(0.0, 1.0) * 0.7;
    final rx = age * spreadSpeed;
    final ry = rx * 0.35; // 2.5D perspective foreshortening

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawOval(
      Rect.fromCenter(center: position, width: rx * 2, height: ry * 2),
      paint,
    );
  }
}
```
