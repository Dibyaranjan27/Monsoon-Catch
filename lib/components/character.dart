import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config/game_config.dart';

enum CharacterState { idle, casting, reeling, caught }

/// Procedural pixel-art fisher character rendered 100% via Canvas primitives.
///
/// Anchored on the riverbank platform at (118.0, 208.8) using [Anchor.bottomCenter].
/// Exposes exact analytical coordinates for the fishing rod tip via [rodTipPosition],
/// guaranteeing zero floating/misalignment with the fishing line.
class CharacterComponent extends PositionComponent {
  CharacterState _state = CharacterState.idle;
  CharacterState get current => _state;
  set current(CharacterState val) {
    if (_state != val) {
      _state = val;
      _stateTime = 0.0;
      if (val != CharacterState.casting) {
        _castProgress = 0.0;
      }
    }
  }

  // Animation and state timers
  double _stateTime = 0.0;
  double _castProgress = 0.0;
  double get castProgress => _castProgress;
  set castProgress(double val) {
    _castProgress = val.clamp(0.0, 1.0);
  }

  double _castDuration = 0.65;
  VoidCallback? _onCastComplete;

  // Cached vector paths to avoid per-frame allocations
  final Path _hatPath = Path();
  final Path _ponchoPath = Path();
  final Path _rodPath = Path();
  final Path _fishPath = Path();

  // Cached paints
  final Paint _hatPaint = Paint()..color = const Color(0xFFD4A373);
  final Paint _hatHighlightPaint = Paint()
    ..color = const Color(0xFFFAEDCD)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  final Paint _hatShadowPaint = Paint()..color = const Color(0xFFB07D4F);
  final Paint _hatBandPaint = Paint()..color = const Color(0xFF582F0E);

  final Paint _skinPaint = Paint()..color = const Color(0xFFFFD1A9);
  final Paint _skinShadowPaint = Paint()..color = const Color(0xFFE0A97E);
  final Paint _eyePaint = Paint()..color = const Color(0xFF1E1E24);
  final Paint _blushPaint = Paint()..color = const Color(0xFFF4A261);

  final Paint _ponchoPaint = Paint()..color = const Color(0xFF2A9D8F);
  final Paint _ponchoShadowPaint = Paint()..color = const Color(0xFF1E6056);
  final Paint _scarfPaint = Paint()..color = const Color(0xFFE76F51);

  final Paint _trousersPaint = Paint()..color = const Color(0xFF3D405B);
  final Paint _bootsPaint = Paint()..color = const Color(0xFF2B2D42);
  final Paint _solePaint = Paint()..color = const Color(0xFF1B1C29);

  final Paint _tackleBoxPaint = Paint()..color = const Color(0xFF8C5835);
  final Paint _tackleBoxTrimPaint = Paint()..color = const Color(0xFFA06D44);
  final Paint _brassClaspPaint = Paint()..color = const Color(0xFFE9C46A);

  final Paint _rodBlankPaint = Paint()
    ..color = const Color(0xFFC59B27)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0
    ..strokeCap = StrokeCap.round;
  final Paint _corkGripPaint = Paint()
    ..color = const Color(0xFFDDB892)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.0
    ..strokeCap = StrokeCap.round;
  final Paint _reelPaint = Paint()..color = const Color(0xFF475569);
  final Paint _guideRingPaint = Paint()
    ..color = const Color(0xFFCBD5E1)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  final Paint _fishBodyPaint = Paint()..color = const Color(0xFF2EC4B6);
  final Paint _fishBellyPaint = Paint()..color = const Color(0xFFCBF3F0);
  final Paint _sparkleGoldPaint = Paint()..color = const Color(0xFFFFD166);
  final Paint _sparkleSeafoamPaint = Paint()..color = const Color(0xFF06D6A0);

  CharacterComponent({
    Vector2? position,
    Vector2? size,
  }) : super(
          position: position ?? Vector2(118.0, 208.8),
          size: size ?? Vector2(80.0, 80.0),
          anchor: Anchor.bottomCenter,
          priority: GameConfig.priorityCharacter,
        );

  /// Initiates dynamic casting animation over [duration] seconds.
  void startCast({double duration = 0.65, VoidCallback? onComplete}) {
    _state = CharacterState.casting;
    _stateTime = 0.0;
    _castProgress = 0.0;
    _castDuration = duration > 0 ? duration : 0.65;
    _onCastComplete = onComplete;
  }

  /// Puts character into reeling / strain posture.
  void reel() {
    current = CharacterState.reeling;
  }

  /// Celebrates a caught catch.
  void catchFish() {
    current = CharacterState.caught;
  }

  /// Atomically resets pose to idle.
  void resetToIdle() {
    _state = CharacterState.idle;
    _stateTime = 0.0;
    _castProgress = 0.0;
    _onCastComplete = null;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _stateTime += dt;

    if (_state == CharacterState.casting) {
      _castProgress += dt / _castDuration;
      if (_castProgress >= 1.0) {
        _castProgress = 1.0;
        final callback = _onCastComplete;
        _onCastComplete = null;
        current = CharacterState.idle;
        callback?.call();
      }
    }
  }

  // ===========================================================================
  // EXACT MATHEMATICAL ROD TIP & HAND CALCULATIONS (World 640x360 Coordinates)
  // ===========================================================================

  /// Returns the exact hand anchor position $P_0$ in world coordinates.
  Vector2 get rodBasePosition {
    // Component ground point in world space is (position.x, position.y)
    final gx = position.x;
    final gy = position.y;

    switch (_state) {
      case CharacterState.idle:
        // Subtle breathing bob
        final bob = 0.8 * sin(2.0 * pi * _stateTime / 2.4);
        return Vector2(gx + 14.0, gy - 22.8 + bob);

      case CharacterState.casting:
        return _computeCastHand(gx, gy, _castProgress);

      case CharacterState.reeling:
        return Vector2(gx + 6.0, gy - 24.8);

      case CharacterState.caught:
        final hop = -3.5 * sin(4.0 * pi * _stateTime).abs();
        return Vector2(gx + 10.0, gy - 36.8 + hop);
    }
  }

  Vector2 _computeCastHand(double gx, double gy, double t) {
    if (t < 0.25) {
      // Phase 1: Back-cast windup
      final tau = t / 0.25;
      final x = (gx + 14.0) + ((gx + 4.0) - (gx + 14.0)) * tau;
      final y = (gy - 22.8) + ((gy - 32.8) - (gy - 22.8)) * tau;
      return Vector2(x, y);
    } else if (t < 0.65) {
      // Phase 2: Forward power whip
      final tau = (t - 0.25) / 0.40;
      final x = (gx + 4.0) + ((gx + 26.0) - (gx + 4.0)) * tau;
      final y = (gy - 32.8) + ((gy - 26.8) - (gy - 32.8)) * tau;
      return Vector2(x, y);
    } else if (t < 0.85) {
      // Phase 3: Tip snap & release
      return Vector2(gx + 26.0, gy - 26.8);
    } else {
      // Phase 4: Settle to idle
      final tau = (t - 0.85) / 0.15;
      final x = (gx + 26.0) + ((gx + 14.0) - (gx + 26.0)) * tau;
      final y = (gy - 26.8) + ((gy - 22.8) - (gy - 26.8)) * tau;
      return Vector2(x, y);
    }
  }

  /// Analytical rod tip coordinate in world space (640x360).
  ///
  /// Guarantees zero gap with fishing line origin across all poses.
  Vector2 get rodTipPosition {
    final gx = position.x;
    final gy = position.y;
    const rodLength = 48.0;

    switch (_state) {
      case CharacterState.idle:
        // Idle tip: (167.67, 153.88) when gx=118, gy=208.8
        // P0 = (gx + 14, gy - 22.8) = (132.0, 186.0)
        // theta = 42 deg -> x = 132 + 48*cos(42) = 167.671, y = 186 - 48*sin(42) = 153.882
        final p0 = rodBasePosition;
        const thetaRad = 42.0 * pi / 180.0;
        final tx = p0.x + rodLength * cos(thetaRad);
        final ty = p0.y - rodLength * sin(thetaRad);
        return Vector2(tx, ty);

      case CharacterState.casting:
        return _computeCastTip(gx, gy, _castProgress);

      case CharacterState.reeling:
        // Strain tip: (164.59, 192.63) when gx=118, gy=208.8
        // Heavy downward flex (38.75 px drop relative to idle 153.88)
        // Micro-jitter at 14 Hz
        final p0 = rodBasePosition;
        const chordLength = 41.5;
        const thetaRad = -12.0 * pi / 180.0;
        final jitterX = 0.6 * sin(28.0 * pi * _stateTime);
        final jitterY = 1.2 * sin(28.0 * pi * _stateTime + pi / 4.0);
        final tx = p0.x + chordLength * cos(thetaRad) + jitterX;
        final ty = p0.y - chordLength * sin(thetaRad) + jitterY;
        return Vector2(tx, ty);

      case CharacterState.caught:
        // Caught tip: (141.23, 125.86) when gx=118, gy=208.8
        // Rod held high at 78 deg
        final p0 = rodBasePosition;
        const thetaRad = 74.0 * pi / 180.0;
        final tx = p0.x + rodLength * cos(thetaRad);
        final ty = p0.y - rodLength * sin(thetaRad);
        return Vector2(tx, ty);
    }
  }

  Vector2 _computeCastTip(double gx, double gy, double t) {
    const rodLength = 48.0;

    if (t < 0.25) {
      // Phase 1: Back-cast windup
      // t=0: idle (theta=42, P0=(132,186)) -> t=0.25: windup (theta=130, P0=(122,176))
      final tau = t / 0.25;
      final p0 = _computeCastHand(gx, gy, t);
      // Smoothstep angle interpolation
      final s = 3.0 * tau * tau - 2.0 * tau * tau * tau;
      final deg = 42.0 + (130.0 - 42.0) * s;
      final rad = deg * pi / 180.0;
      return Vector2(p0.x + rodLength * cos(rad), p0.y - rodLength * sin(rad));
    } else if (t < 0.65) {
      // Phase 2: Forward power whip
      // t=0.25: theta=130 -> t=0.65: theta=20
      final tau = (t - 0.25) / 0.40;
      final p0 = _computeCastHand(gx, gy, t);
      final baseDeg = 130.0 - 110.0 * (tau * tau);
      // Inertial lag flex
      final lagDeg = 46.0 * sin(pi * tau);
      final deg = baseDeg + lagDeg;
      final rad = deg * pi / 180.0;
      final chord = rodLength - 5.5 * sin(pi * tau);
      return Vector2(p0.x + chord * cos(rad), p0.y - chord * sin(rad));
    } else if (t < 0.85) {
      // Phase 3: Tip snap & release
      // t=0.65: theta=20 -> t=0.85: theta=25
      final tau = (t - 0.65) / 0.20;
      final p0 = _computeCastHand(gx, gy, t);
      final snapDeg = -12.0 * (1.0 - tau) * sin(2.0 * pi * tau);
      final deg = 20.0 + 5.0 * tau + snapDeg;
      final rad = deg * pi / 180.0;
      return Vector2(p0.x + rodLength * cos(rad), p0.y - rodLength * sin(rad));
    } else {
      // Phase 4: Settle to idle
      // t=0.85: theta=25 -> t=1.0: theta=42
      final tau = (t - 0.85) / 0.15;
      final p0 = _computeCastHand(gx, gy, t);
      final deg = 25.0 + (42.0 - 25.0) * tau;
      final rad = deg * pi / 180.0;
      return Vector2(p0.x + rodLength * cos(rad), p0.y - rodLength * sin(rad));
    }
  }

  /// Backwards compatibility method for R1 call sites.
  Vector2 getRodTipPosition() => rodTipPosition;

  // ===========================================================================
  // PROCEDURAL CANVAS RENDERING (100% Canvas primitives, 0 bitmaps)
  // ===========================================================================

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Coordinate conversion: render relative to bottom-center anchor (size.x/2, size.y)
    canvas.save();
    canvas.translate(size.x / 2, size.y);

    // 1. Tackle box / Wooden Seat
    _renderSeat(canvas);

    // 2. Legs & Mud Boots
    _renderLegsAndBoots(canvas);

    // 3. Torso & Poncho
    _renderTorso(canvas);

    // 4. Head, Face & Straw Hat
    _renderHeadAndHat(canvas);

    // 5. Arms & Hands
    _renderArms(canvas);

    // 6. Rod Blank & Guides
    _renderRod(canvas);

    // 7. Caught Fish & Celebration Sparkles
    if (_state == CharacterState.caught) {
      _renderCelebration(canvas);
    }

    canvas.restore();
  }

  void _renderSeat(Canvas canvas) {
    // Cedar wooden crate sits at foot level
    final rect = Rect.fromLTWH(-16.0, -18.0, 16.0, 18.0);
    canvas.drawRect(rect, _tackleBoxPaint);
    // Lid trim
    canvas.drawRect(Rect.fromLTWH(-17.0, -18.0, 18.0, 3.0), _tackleBoxTrimPaint);
    // Brass clasp
    canvas.drawRect(Rect.fromLTWH(-9.0, -13.0, 2.0, 4.0), _brassClaspPaint);
  }

  void _renderLegsAndBoots(Canvas canvas) {
    switch (_state) {
      case CharacterState.idle:
      case CharacterState.casting:
        // Left trouser / leg
        canvas.drawRect(const Rect.fromLTWH(-6.0, -14.0, 5.0, 10.0), _trousersPaint);
        // Right trouser / leg
        canvas.drawRect(const Rect.fromLTWH(1.0, -14.0, 5.0, 10.0), _trousersPaint);
        // Boots
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(-7.0, -6.0, 7.0, 6.0), const Radius.circular(1.5)),
          _bootsPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(0.0, -6.0, 8.0, 6.0), const Radius.circular(1.5)),
          _bootsPaint,
        );
        // Mud soles
        canvas.drawRect(const Rect.fromLTWH(-7.0, -1.0, 7.0, 1.0), _solePaint);
        canvas.drawRect(const Rect.fromLTWH(0.0, -1.0, 8.0, 1.0), _solePaint);
        break;

      case CharacterState.reeling:
        // Braced stance: front boot dug in forward, back boot braced back
        canvas.drawRect(const Rect.fromLTWH(-10.0, -13.0, 5.0, 9.0), _trousersPaint);
        canvas.drawRect(const Rect.fromLTWH(2.0, -12.0, 6.0, 8.0), _trousersPaint);
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(-11.0, -5.0, 7.0, 5.0), const Radius.circular(1.5)),
          _bootsPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(2.0, -5.0, 9.0, 5.0), const Radius.circular(1.5)),
          _bootsPaint,
        );
        canvas.drawRect(const Rect.fromLTWH(-11.0, -1.0, 7.0, 1.0), _solePaint);
        canvas.drawRect(const Rect.fromLTWH(2.0, -1.0, 9.0, 1.0), _solePaint);
        break;

      case CharacterState.caught:
        final hop = -3.5 * sin(4.0 * pi * _stateTime).abs();
        canvas.drawRect(Rect.fromLTWH(-5.0, -14.0 + hop, 5.0, 9.0), _trousersPaint);
        canvas.drawRect(Rect.fromLTWH(2.0, -14.0 + hop, 5.0, 9.0), _trousersPaint);
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(-6.0, -6.0 + hop, 7.0, 6.0), const Radius.circular(1.5)),
          _bootsPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(1.0, -6.0 + hop, 7.0, 6.0), const Radius.circular(1.5)),
          _bootsPaint,
        );
        break;
    }
  }

  void _renderTorso(Canvas canvas) {
    double torsoY = -30.0;
    double torsoLean = 0.0;

    switch (_state) {
      case CharacterState.idle:
        torsoY += 0.8 * sin(2.0 * pi * _stateTime / 2.4);
        break;
      case CharacterState.casting:
        if (_castProgress < 0.25) {
          torsoLean = -8.0 * (_castProgress / 0.25);
        } else if (_castProgress < 0.65) {
          torsoLean = -8.0 + 26.0 * ((_castProgress - 0.25) / 0.40);
        } else {
          torsoLean = 18.0 * (1.0 - (_castProgress - 0.65) / 0.35);
        }
        break;
      case CharacterState.reeling:
        torsoLean = -18.0; // Braced backward lean
        break;
      case CharacterState.caught:
        torsoY += -3.5 * sin(4.0 * pi * _stateTime).abs();
        torsoLean = 4.0;
        break;
    }

    canvas.save();
    canvas.translate(0.0, torsoY);
    canvas.rotate(torsoLean * pi / 180.0);

    // Poncho body (trapezoid)
    _ponchoPath.reset();
    _ponchoPath.moveTo(-8.0, -2.0);
    _ponchoPath.lineTo(8.0, -2.0);
    _ponchoPath.lineTo(11.0, 16.0);
    _ponchoPath.lineTo(-11.0, 16.0);
    _ponchoPath.close();
    canvas.drawPath(_ponchoPath, _ponchoPaint);

    // Poncho fold shadow
    canvas.drawRect(const Rect.fromLTWH(-10.0, 6.0, 4.0, 10.0), _ponchoShadowPaint);

    // Saffron scarf peeking above collar
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-6.0, -5.0, 12.0, 4.0), const Radius.circular(2.0)),
      _scarfPaint,
    );

    canvas.restore();
  }

  void _renderHeadAndHat(Canvas canvas) {
    double headY = -37.0;
    double headTilt = 0.0;

    switch (_state) {
      case CharacterState.idle:
        headY += 0.8 * sin(2.0 * pi * _stateTime / 2.4);
        break;
      case CharacterState.casting:
        if (_castProgress < 0.25) {
          headTilt = -6.0 * (_castProgress / 0.25);
        } else if (_castProgress < 0.65) {
          headTilt = 12.0 * ((_castProgress - 0.25) / 0.40);
        }
        break;
      case CharacterState.reeling:
        headY += 1.0;
        headTilt = -12.0;
        break;
      case CharacterState.caught:
        headY += -3.5 * sin(4.0 * pi * _stateTime).abs();
        headTilt = -8.0;
        break;
    }

    canvas.save();
    canvas.translate(0.0, headY);
    canvas.rotate(headTilt * pi / 180.0);

    // 1. Head & Face
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-5.0, -4.0, 10.0, 10.0), const Radius.circular(3.0)),
      _skinPaint,
    );
    // Chin shadow
    canvas.drawRect(const Rect.fromLTWH(-4.0, 4.0, 8.0, 2.0), _skinShadowPaint);

    // Eyes (facing right toward pond)
    if (_state == CharacterState.caught) {
      // Happy closed eyes (^ _)
      canvas.drawLine(const Offset(1.0, -1.0), const Offset(3.0, -2.0), _eyePaint);
      canvas.drawLine(const Offset(3.0, -2.0), const Offset(5.0, -1.0), _eyePaint);
    } else {
      canvas.drawRect(const Rect.fromLTWH(2.0, -1.0, 2.0, 2.0), _eyePaint);
    }

    // Cozy blush dot
    canvas.drawRect(const Rect.fromLTWH(2.0, 2.0, 2.0, 1.0), _blushPaint);

    // 2. Conical Straw Hat (Kasa)
    _hatPath.reset();
    _hatPath.moveTo(0.0, -14.0); // Hat peak
    _hatPath.lineTo(-17.0, -3.0); // Left brim
    _hatPath.quadraticBezierTo(0.0, -1.0, 17.0, -3.0); // Underside rim
    _hatPath.close();

    // Underside brim shadow
    canvas.drawOval(const Rect.fromLTWH(-16.0, -4.0, 32.0, 4.0), _hatShadowPaint);

    // Hat cone
    canvas.drawPath(_hatPath, _hatPaint);
    canvas.drawPath(_hatPath, _hatHighlightPaint);

    // Hat contrast ribbon band
    canvas.drawRect(const Rect.fromLTWH(-9.0, -6.0, 18.0, 2.0), _hatBandPaint);

    canvas.restore();
  }

  void _renderArms(Canvas canvas) {
    // Shoulder to hand articulation
    final handPos = rodBasePosition;
    final localHand = Offset(handPos.x - position.x, handPos.y - position.y);

    double shoulderX = 2.0;
    double shoulderY = -28.0;

    if (_state == CharacterState.caught) {
      shoulderY += -3.5 * sin(4.0 * pi * _stateTime).abs();
    }

    // Arm stroke
    final armPaint = Paint()
      ..color = const Color(0xFF2A9D8F)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final elbowX = (shoulderX + localHand.dx) / 2.0 - 2.0;
    final elbowY = (shoulderY + localHand.dy) / 2.0 + 3.0;

    final armPath = Path()
      ..moveTo(shoulderX, shoulderY)
      ..quadraticBezierTo(elbowX, elbowY, localHand.dx, localHand.dy);
    canvas.drawPath(armPath, armPaint);

    // Peach hand
    canvas.drawCircle(localHand, 2.2, _skinPaint);
  }

  void _renderRod(Canvas canvas) {
    final handWorld = rodBasePosition;
    final tipWorld = rodTipPosition;

    final p0 = Offset(handWorld.x - position.x, handWorld.y - position.y);
    final p3 = Offset(tipWorld.x - position.x, tipWorld.y - position.y);

    // Calculate intermediate control points P1, P2 for rod bend
    final dx = p3.dx - p0.dx;
    final dy = p3.dy - p0.dy;

    Offset p1;
    Offset p2;

    switch (_state) {
      case CharacterState.idle:
        // Subtle sag
        p1 = Offset(p0.dx + dx * 0.35, p0.dy + dy * 0.35 + 0.8);
        p2 = Offset(p0.dx + dx * 0.70, p0.dy + dy * 0.70 + 1.2);
        break;

      case CharacterState.casting:
        // Whipping inertial bend
        final tau = _castProgress;
        final bendOffset = (tau > 0.25 && tau < 0.65) ? -8.0 * sin(pi * (tau - 0.25) / 0.40) : 0.0;
        p1 = Offset(p0.dx + dx * 0.30 + bendOffset, p0.dy + dy * 0.30);
        p2 = Offset(p0.dx + dx * 0.65 + bendOffset * 1.5, p0.dy + dy * 0.65);
        break;

      case CharacterState.reeling:
        // Deep parabolic bow downward toward the water
        p1 = Offset(p0.dx + dx * 0.35 + 2.0, p0.dy + dy * 0.35 + 8.0);
        p2 = Offset(p0.dx + dx * 0.70 + 4.0, p0.dy + dy * 0.70 + 14.0);
        break;

      case CharacterState.caught:
        // Stiff high elevation
        p1 = Offset(p0.dx + dx * 0.35 - 1.0, p0.dy + dy * 0.35 - 1.0);
        p2 = Offset(p0.dx + dx * 0.70 - 1.0, p0.dy + dy * 0.70 - 0.5);
        break;
    }

    _rodPath.reset();
    _rodPath.moveTo(p0.dx, p0.dy);
    _rodPath.cubicTo(p1.dx, p1.dy, p2.dx, p2.dy, p3.dx, p3.dy);
    canvas.drawPath(_rodPath, _rodBlankPaint);

    // Cork grip at rod butt
    final gripEnd = Offset(p0.dx + dx * 0.18, p0.dy + dy * 0.18);
    canvas.drawLine(p0, gripEnd, _corkGripPaint);

    // Reel spool attached to cork handle
    final reelPos = Offset(p0.dx + dx * 0.12 - 1.0, p0.dy + dy * 0.12 + 2.5);
    canvas.drawCircle(reelPos, 2.5, _reelPaint);

    // Guide rings along rod blank
    final ring1 = Offset(p0.dx + dx * 0.45, p0.dy + dy * 0.45);
    final ring2 = Offset(p0.dx + dx * 0.75, p0.dy + dy * 0.75);
    canvas.drawCircle(ring1, 1.2, _guideRingPaint);
    canvas.drawCircle(ring2, 1.0, _guideRingPaint);
  }

  void _renderCelebration(Canvas canvas) {
    final tipWorld = rodTipPosition;
    final tipLocal = Offset(tipWorld.x - position.x, tipWorld.y - position.y);

    // 1. Short leader line dangling the fish
    final fishCenter = Offset(tipLocal.dx + 4.0, tipLocal.dy + 18.0);
    canvas.drawLine(
      tipLocal,
      fishCenter,
      Paint()
        ..color = Colors.white70
        ..strokeWidth = 1.0,
    );

    // 2. Procedural pixel-art catch (emerald/silver scales)
    final fishWiggle = 1.5 * sin(16.0 * pi * _stateTime);
    canvas.save();
    canvas.translate(fishCenter.dx, fishCenter.dy);

    _fishPath.reset();
    _fishPath.moveTo(7.0, 0.0); // Head
    _fishPath.quadraticBezierTo(2.0, -4.5, -4.0, -3.0);
    _fishPath.lineTo(-7.0 + fishWiggle, -6.0); // Top tail fin
    _fishPath.lineTo(-5.0 + fishWiggle, 0.0); // Tail notch
    _fishPath.lineTo(-7.0 + fishWiggle, 6.0); // Bottom tail fin
    _fishPath.lineTo(-4.0, 3.0);
    _fishPath.quadraticBezierTo(2.0, 4.5, 7.0, 0.0);
    _fishPath.close();

    canvas.drawPath(_fishPath, _fishBodyPaint);
    // Silver belly
    canvas.drawOval(const Rect.fromLTWH(-3.0, 0.0, 7.0, 3.0), _fishBellyPaint);
    // Fish eye dot
    canvas.drawCircle(const Offset(4.5, -1.0), 0.8, _eyePaint);

    canvas.restore();

    // 3. Celebratory pixel sparkles
    _renderSparkle(canvas, tipLocal.dx + 12.0, tipLocal.dy - 6.0, _sparkleGoldPaint, 0.0);
    _renderSparkle(canvas, tipLocal.dx - 10.0, tipLocal.dy + 6.0, _sparkleSeafoamPaint, 0.5);
    _renderSparkle(canvas, tipLocal.dx + 8.0, tipLocal.dy + 26.0, _sparkleGoldPaint, 1.0);
  }

  void _renderSparkle(Canvas canvas, double cx, double cy, Paint paint, double phase) {
    final scale = (0.5 + 0.5 * sin(8.0 * _stateTime + phase)).clamp(0.0, 1.0);
    if (scale <= 0.1) return;

    final len = 3.5 * scale;
    canvas.drawLine(Offset(cx - len, cy), Offset(cx + len, cy), paint..strokeWidth = 1.0);
    canvas.drawLine(Offset(cx, cy - len), Offset(cx, cy + len), paint..strokeWidth = 1.0);
  }
}

/// Backwards compatibility alias for CharacterPlaceholder
typedef CharacterPlaceholder = CharacterComponent;
