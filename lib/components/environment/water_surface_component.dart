import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../config/game_config.dart';
import '../../logic/wave_generator.dart';
import '../../models/weather_state.dart';

/// Animated procedural water surface with multi-harmonic wave simulation,
/// dynamic depth gradient, foam crest highlighting, and rain ripple effects.
class WaterSurfaceComponent extends PositionComponent {
  final WeatherState weather;
  final WaveGenerator waveGenerator;

  double _time = 0.0;
  final List<_RainRipple> _ripples = [];
  final Random _rnd = Random(88);
  double _timeSinceLastRipple = 0.0;

  // Reusable paths to eliminate per-frame allocations during 60 FPS animation
  final Path _waterPath = Path();
  final Path _crestPath = Path();

  // Cached shader and reusable paint instances
  final Paint _waterPaint = Paint();
  ui.Gradient? _cachedWaterShader;
  WeatherType? _cachedWeatherType;
  double _cachedShaderHeight = 0.0;

  final Paint _crestPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  WaterSurfaceComponent({
    required Vector2 size,
    required this.weather,
  })  : waveGenerator = const WaveGenerator(),
        super(
          size: size,
          priority: GameConfig.priorityWaterSurface,
        );

  @override
  void update(double dt) {
    super.update(dt);

    // Wave animation speed accelerates slightly in stormy weather
    final timeScale = 1.0 + (weather.rainIntensity * 0.5);
    _time += dt * timeScale;

    // Procedural rain impact ripples
    if (weather.rainIntensity > 0.0) {
      _timeSinceLastRipple += dt;
      final spawnInterval = 0.25 / (weather.rainIntensity * 4.0 + 0.1);

      if (_timeSinceLastRipple >= spawnInterval && _ripples.length < 35) {
        _timeSinceLastRipple = 0.0;
        final startX = size.x * 0.30 + _rnd.nextDouble() * (size.x * 0.70);
        final startY = size.y * 0.65 + _rnd.nextDouble() * (size.y * 0.32);
        _ripples.add(_RainRipple(position: Offset(startX, startY)));
      }
    }

    // Update active ripples
    for (int i = _ripples.length - 1; i >= 0; i--) {
      _ripples[i].update(dt);
      if (_ripples[i].isDead) {
        _ripples.removeAt(i);
      }
    }
  }

  /// Rebuilds depth gradient shader only when weather state or component height shifts.
  void _updateWaterShader() {
    final baseY = size.y * 0.65;
    final Color surfaceColor;
    final Color midColor;
    final Color abyssColor;

    switch (weather.currentType) {
      case WeatherType.clearDawn:
        surfaceColor = const Color(0xFF3E9296);
        midColor = const Color(0xFF28586E);
        abyssColor = const Color(0xFF16212E);
        break;
      case WeatherType.clearDay:
        surfaceColor = const Color(0xFF38A3A5);
        midColor = const Color(0xFF22577A);
        abyssColor = const Color(0xFF0F1E29);
        break;
      case WeatherType.overcast:
        surfaceColor = const Color(0xFF2E6F7A);
        midColor = const Color(0xFF1B445A);
        abyssColor = const Color(0xFF0B1720);
        break;
      case WeatherType.monsoon:
        surfaceColor = const Color(0xFF1E3A42);
        midColor = const Color(0xFF142733);
        abyssColor = const Color(0xFF081017);
        break;
    }

    _cachedWaterShader = ui.Gradient.linear(
      Offset(0, baseY),
      Offset(0, size.y),
      [surfaceColor, midColor, abyssColor],
      const [0.0, 0.40, 1.00],
    );
    _waterPaint.shader = _cachedWaterShader;
    _cachedWeatherType = weather.currentType;
    _cachedShaderHeight = size.y;
  }

  @override
  void render(Canvas canvas) {
    final startX = size.x * 0.30; // Water begins where riverbank meets
    final baseY = size.y * 0.65; // ~234 px water surface waterline
    const step = 4.0;

    _waterPath.reset();
    _crestPath.reset();

    final turb = weather.waveTurbulence;

    // 1. Build sinusoidal wave contour reusing existing path buffers
    final firstY = baseY + waveGenerator.computeElevation(startX, _time, turb);
    _waterPath.moveTo(startX, firstY);
    _crestPath.moveTo(startX, firstY);

    for (double x = startX + step; x <= size.x; x += step) {
      final y = baseY + waveGenerator.computeElevation(x, _time, turb);
      _waterPath.lineTo(x, y);
      _crestPath.lineTo(x, y);
    }

    // Close water polygon around viewport bottom
    _waterPath.lineTo(size.x, size.y);
    _waterPath.lineTo(startX, size.y);
    _waterPath.close();

    // 2. Linear depth gradient shader (cached; updated only when weather or height shifts)
    if (_cachedWaterShader == null ||
        _cachedWeatherType != weather.currentType ||
        _cachedShaderHeight != size.y) {
      _updateWaterShader();
    }
    canvas.drawPath(_waterPath, _waterPaint);

    // 3. Crest highlight foam line
    _crestPaint.color = weather.currentType == WeatherType.monsoon
        ? const Color(0x6694A3B8)
        : const Color(0x99FFFFFF);
    canvas.drawPath(_crestPath, _crestPaint);

    // 4. Render raindrop impact ripples
    for (final ripple in _ripples) {
      ripple.render(canvas);
    }
  }
}

/// Expanding elliptical ripple representing raindrop impact on water
class _RainRipple {
  final Offset position;
  double age = 0.0;
  static const double maxAge = 0.65; // Lifetime in seconds
  static const double spreadSpeed = 30.0; // Expansion speed in px/s

  // Shared reusable Paint instance to eliminate per-ripple GC churn across up to 35 ripples
  static final Paint _sharedRipplePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  _RainRipple({required this.position});

  bool get isDead => age >= maxAge;

  void update(double dt) {
    age += dt;
  }

  void render(Canvas canvas) {
    final progress = age / maxAge;
    final alpha = (1.0 - progress).clamp(0.0, 1.0) * 0.65;
    final rx = age * spreadSpeed;
    final ry = rx * 0.35; // 2.5D foreshortened isometric perspective

    _sharedRipplePaint.color = Colors.white.withValues(alpha: alpha);

    canvas.drawOval(
      Rect.fromCenter(center: position, width: rx * 2, height: ry * 2),
      _sharedRipplePaint,
    );
  }
}
