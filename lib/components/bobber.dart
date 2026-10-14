import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config/game_config.dart';
import '../logic/wave_generator.dart';
import '../models/weather_state.dart';

enum BobberState { airborne, floating, nibble, bite, caught, missed }

/// 2.5D elliptical water ripple spawned on bobber splashdown.
class _BobberRipple {
  final Offset center;
  final double maxRadius;
  final double duration;
  final double delay;
  double elapsed = 0.0;

  _BobberRipple({
    required this.center,
    required this.maxRadius,
    required this.duration,
    this.delay = 0.0,
  });

  bool get isFinished => elapsed >= duration + delay;

  void update(double dt) {
    elapsed += dt;
  }

  void render(Canvas canvas, Paint ripplePaint) {
    if (elapsed < delay || isFinished) return;
    final progress = (elapsed - delay) / duration;
    final rx = maxRadius * progress;
    final ry = rx * 0.35; // 2.5D foreshortened pond perspective
    final alpha = (0.85 * (1.0 - progress)).clamp(0.0, 1.0);

    ripplePaint.color = Colors.white.withValues(alpha: alpha);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: rx * 2.0, height: ry * 2.0),
      ripplePaint,
    );
  }
}

/// Miniature water splash droplet.
class _SplashDroplet {
  Offset position;
  Offset velocity;
  double lifetime;
  double elapsed = 0.0;

  _SplashDroplet({
    required this.position,
    required this.velocity,
    required this.lifetime,
  });

  bool get isFinished => elapsed >= lifetime;

  void update(double dt) {
    elapsed += dt;
    velocity = Offset(velocity.dx, velocity.dy + 98.0 * dt); // gravity
    position = Offset(position.dx + velocity.dx * dt, position.dy + velocity.dy * dt);
  }
}

/// 100% Procedural Canvas-rendered fishing bobber.
///
/// Features:
/// - Floating elevation synchronized with [WaveGenerator] at waterline baseline y = 234.0.
/// - 2.5D concentric landing ripples and splash droplets on touchdown.
/// - Expressive states: airborne, floating, nibble, bite, caught, missed.
/// - Zero external bitmap asset dependencies.
class BobberComponent extends PositionComponent {
  BobberState state = BobberState.floating;
  late Vector2 originalPosition;

  final WaveGenerator waveGenerator = const WaveGenerator();
  WeatherState? weather;

  double _time = 0.0;
  double _stateTime = 0.0;

  // Airborne ballistic casting trajectory
  bool _isAirborne = false;
  Vector2 _castStart = Vector2.zero();
  Vector2 _castTarget = Vector2.zero();
  double _castProgress = 0.0;
  double _castDuration = 0.65;
  VoidCallback? _onCastTouchdown;

  // Active ripples and splash droplets
  final List<_BobberRipple> _ripples = [];
  final List<_SplashDroplet> _droplets = [];

  // Cached paints to prevent allocations in game loop
  final Paint _redDomePaint = Paint()..color = const Color(0xFFE63946);
  final Paint _whiteDomePaint = Paint()..color = const Color(0xFFF1FAEE);
  final Paint _seamBandPaint = Paint()..color = const Color(0xFF1D3557);
  final Paint _quillPaint = Paint()
    ..color = const Color(0xFFFFD166)
    ..strokeWidth = 1.5
    ..strokeCap = StrokeCap.round;
  final Paint _quillTipPaint = Paint()..color = const Color(0xFFE63946);
  final Paint _eyeletPaint = Paint()
    ..color = const Color(0xFFD4A373)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  final Paint _specularPaint = Paint()..color = Colors.white.withValues(alpha: 0.85);
  final Paint _submergedPaint = Paint()..color = const Color(0x661D3557);
  final Paint _ripplePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;
  final Paint _dropletPaint = Paint()..color = const Color(0xCCFFFFFF);

  BobberComponent({
    required Vector2 position,
    this.weather,
  }) : super(
          position: position,
          size: Vector2(16.0, 20.0),
          anchor: Anchor.center,
          priority: GameConfig.priorityBobber,
        ) {
    originalPosition = position.clone();
  }

  /// Initiates ballistic arc cast trajectory from [from] to [to].
  void startCastTrajectory({
    required Vector2 from,
    required Vector2 to,
    double duration = 0.65,
    VoidCallback? onTouchdown,
  }) {
    _isAirborne = true;
    state = BobberState.airborne;
    _castStart = from.clone();
    _castTarget = to.clone();
    originalPosition = to.clone();
    _castDuration = duration > 0 ? duration : 0.65;
    _castProgress = 0.0;
    _onCastTouchdown = onTouchdown;
    position.setFrom(from);
  }

  /// Transitions bobber into a new interaction state.
  void changeState(BobberState newState) {
    state = newState;
    _stateTime = 0.0;
    if (newState != BobberState.airborne) {
      _isAirborne = false;
    }

    if (newState == BobberState.floating) {
      triggerSplash();
    }
  }

  /// Spawns 2.5D concentric ripples and water droplets at current position.
  void triggerSplash() {
    final center = Offset.zero; // Local coordinate
    _ripples.clear();
    _ripples.add(_BobberRipple(center: center, maxRadius: 22.0, duration: 0.70));
    _ripples.add(_BobberRipple(center: center, maxRadius: 14.0, duration: 0.60, delay: 0.08));

    // Splash spray droplets
    _droplets.clear();
    final rng = Random();
    for (int i = 0; i < 4; i++) {
      final vx = (rng.nextDouble() - 0.5) * 36.0;
      final vy = -20.0 - rng.nextDouble() * 25.0;
      _droplets.add(
        _SplashDroplet(
          position: center,
          velocity: Offset(vx, vy),
          lifetime: 0.28,
        ),
      );
    }
  }

  /// Atomically resets and clears all ripples and state timers.
  void reset() {
    _isAirborne = false;
    _ripples.clear();
    _droplets.clear();
    _castProgress = 0.0;
    _stateTime = 0.0;
    _onCastTouchdown = null;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    _stateTime += dt;

    // 1. Update ripple and droplet particles
    for (final ripple in _ripples) {
      ripple.update(dt);
    }
    _ripples.removeWhere((r) => r.isFinished);

    for (final droplet in _droplets) {
      droplet.update(dt);
    }
    _droplets.removeWhere((d) => d.isFinished);

    // 2. Airborne casting ballistic arc
    if (_isAirborne) {
      _castProgress += dt / _castDuration;
      if (_castProgress >= 1.0) {
        _castProgress = 1.0;
        _isAirborne = false;
        position.setFrom(_castTarget);
        changeState(BobberState.floating);
        final callback = _onCastTouchdown;
        _onCastTouchdown = null;
        callback?.call();
        return;
      }

      // Parabolic ballistic trajectory with 60 px arc peak
      final t = _castProgress;
      // Ease out quad on horizontal flight
      final easeT = 1.0 - (1.0 - t) * (1.0 - t);
      final x = _castStart.x + (_castTarget.x - _castStart.x) * easeT;
      const hArc = 60.0;
      final yLinear = _castStart.y + (_castTarget.y - _castStart.y) * t;
      final yParabolic = yLinear - 4.0 * hArc * t * (1.0 - t);

      position.x = x;
      position.y = yParabolic;
      return;
    }

    // 3. Water surface tracking via WaveGenerator
    final turbulence = weather?.waveTurbulence ?? 1.0;
    final waveElevation = waveGenerator.computeElevation(position.x, _time, turbulence);

    // Baseline waterline Y = 234.0 px (or target elevation clamped to water plane)
    final baselineY = originalPosition.y >= 234.0 ? originalPosition.y : 234.0;
    final waterY = baselineY + waveElevation;

    switch (state) {
      case BobberState.floating:
        // Gentle buoyancy bobbing: -2.0 + 0.6 * sin(2.5 * time)
        final bob = -2.0 + 0.6 * sin(2.5 * _time);
        position.y = waterY + bob;
        break;

      case BobberState.nibble:
        // Quick erratic vertical twitch
        final twitch = -2.0 + 3.5 * sin(18.0 * _stateTime).abs() * exp(-2.0 * (_stateTime % 0.8));
        position.y = waterY + twitch;
        break;

      case BobberState.bite:
        // Sharp pull underwater: +11.0 + 1.2 * sin(12.0 * time)
        final submerged = 11.0 + 1.2 * sin(12.0 * _time);
        position.y = waterY + submerged;
        break;

      case BobberState.caught:
        // Leap out of water alongside the hooked fish
        final leap = -45.0 * sin(pi * (_stateTime.clamp(0.0, 0.5) / 0.5));
        position.y = waterY + leap;
        break;

      case BobberState.missed:
        // Slowly ease back to surface
        final ease = (1.0 - (_stateTime / 0.5)).clamp(0.0, 1.0);
        position.y = waterY + 6.0 * ease;
        break;

      case BobberState.airborne:
        break;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);

    // 1. Render 2.5D concentric ripples behind/under the float
    for (final ripple in _ripples) {
      ripple.render(canvas, _ripplePaint);
    }

    // 2. Bobber tilt angle
    double tilt = 0.0;
    if (_isAirborne) {
      tilt = 0.35;
    } else if (state == BobberState.bite) {
      tilt = -0.35; // Tilted sharply toward rod
    } else if (state == BobberState.nibble) {
      tilt = 0.15 * sin(24.0 * _stateTime);
    } else {
      tilt = 0.06 * cos(2.0 * _time);
    }
    canvas.rotate(tilt);

    // 3. Top Hemisphere (Signal Red)
    canvas.drawArc(
      const Rect.fromLTWH(-6.0, -8.0, 12.0, 12.0),
      pi,
      pi,
      true,
      _redDomePaint,
    );
    // White specular highlight dot
    canvas.drawCircle(const Offset(-2.0, -5.0), 1.0, _specularPaint);

    // 4. Bottom Hemisphere (Porcelain White)
    canvas.drawArc(
      const Rect.fromLTWH(-6.0, -4.0, 12.0, 12.0),
      0,
      pi,
      true,
      _whiteDomePaint,
    );

    // 5. Equatorial Seam Band (Dark Slate)
    canvas.drawRect(const Rect.fromLTWH(-6.0, -2.5, 12.0, 1.5), _seamBandPaint);

    // 6. Quill Antenna (Yellow shaft with red tip)
    canvas.drawLine(const Offset(0.0, -8.0), const Offset(0.0, -15.0), _quillPaint);
    canvas.drawCircle(const Offset(0.0, -15.0), 1.2, _quillTipPaint);

    // 7. Brass Eyelet (Line attachment loop at bottom)
    canvas.drawCircle(const Offset(0.0, 8.5), 1.5, _eyeletPaint);

    // 8. Water Submersion Mask (when submerged during bite)
    if (state == BobberState.bite) {
      canvas.drawOval(const Rect.fromLTWH(-7.0, -2.0, 14.0, 11.0), _submergedPaint);
    }

    // 9. Splash Droplets
    for (final droplet in _droplets) {
      canvas.drawCircle(droplet.position, 1.0, _dropletPaint);
    }

    canvas.restore();
  }
}
