import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config/game_config.dart';

/// Cubic Bezier control points pair for line rendering and curvature math.
class BezierControlPoints {
  final Offset c1;
  final Offset c2;

  const BezierControlPoints({required this.c1, required this.c2});

  @override
  String toString() => 'BezierControlPoints(c1: $c1, c2: $c2)';
}

/// Pure mathematical calculation engine for physics-aware catenary/Bezier fishing line.
class FishingLineMath {
  FishingLineMath._();

  static const double kSagFactor = 0.14;
  static const double kMinSag = 4.0;
  static const double kMaxSag = 38.0;
  static const double kVibrationFrequency = 32.0; // rad/s (~5.1 Hz)
  static const double kMaxVibrationAmplitude = 1.2; // px
  static const double kWindDriftFactor = 8.0; // max horizontal drift in px

  /// Computes cubic Bezier control points [C1, C2] connecting [p1] (rod tip)
  /// and [p2] (bobber).
  ///
  /// - [tension]: Normalized tension in [0.0, 1.0]. 0.0 is full slack sag, 1.0 is taut chord.
  /// - [windFactor]: Normalized wind drift factor in [-1.0, 1.0].
  /// - [time]: Elapsed game time in seconds, used for strain micro-vibration.
  static BezierControlPoints computeControlPoints({
    required Offset p1,
    required Offset p2,
    required double tension,
    double windFactor = 0.0,
    double time = 0.0,
  }) {
    // Sanitize non-finite inputs
    final safeP1 = Offset(
      p1.dx.isFinite ? p1.dx : 0.0,
      p1.dy.isFinite ? p1.dy : 0.0,
    );
    final safeP2 = Offset(
      p2.dx.isFinite ? p2.dx : 0.0,
      p2.dy.isFinite ? p2.dy : 0.0,
    );
    final safeTension = (tension.isFinite ? tension : 0.0).clamp(0.0, 1.0);
    final safeWind = (windFactor.isFinite ? windFactor : 0.0).clamp(-1.0, 1.0);
    final safeTime = time.isFinite ? time : 0.0;

    final dx = safeP2.dx - safeP1.dx;
    final dy = safeP2.dy - safeP1.dy;
    final span = sqrt(dx * dx + dy * dy);

    // Degenerate zero-length span protection
    if (span < 1e-4) {
      return BezierControlPoints(c1: safeP1, c2: safeP2);
    }

    // 1. Trisection base points along chord
    final m1 = Offset(safeP1.dx + dx / 3.0, safeP1.dy + dy / 3.0);
    final m2 = Offset(safeP1.dx + (2.0 * dx) / 3.0, safeP1.dy + (2.0 * dy) / 3.0);

    // 2. Gravitational sag depth: S_y(tau, L) = clamp(L * 0.14, 4.0, 38.0) * (1.0 - tau)^2
    final maxSag = (span * kSagFactor).clamp(kMinSag, kMaxSag);
    final slackMultiplier = pow(1.0 - safeTension, 2).toDouble();
    final sagY = maxSag * slackMultiplier;

    // Wind drift horizontal deflection: S_x = wind * (1.0 - tau) * 8.0
    final sagX = safeWind * (1.0 - safeTension) * kWindDriftFactor;

    // 3. High-tension micro-vibration (humming strum when tau > 0.75)
    double vibX = 0.0;
    double vibY = 0.0;
    if (safeTension > 0.75) {
      final vibTensionScale = (safeTension - 0.75) / 0.25;
      final vibAmp = kMaxVibrationAmplitude *
          vibTensionScale *
          sin(kVibrationFrequency * safeTime);
      // Unit normal vector perpendicular to chord: (-dy / span, dx / span)
      vibX = (-dy / span) * vibAmp;
      vibY = (dx / span) * vibAmp;
    }

    // 4. Asymmetric catenary weighting (0.85 near rod tip, 1.15 near water/bobber)
    // Factor of 4/3 ensures midpoint evaluation B(0.5) sags exactly by sagY:
    // (w1 + w2) / 2 = (0.85 + 1.15) / 2 = 1.0
    final c1 = Offset(
      m1.dx + (4.0 / 3.0) * sagX * 0.85 + vibX,
      m1.dy + (4.0 / 3.0) * sagY * 0.85 + vibY,
    );
    final c2 = Offset(
      m2.dx + (4.0 / 3.0) * sagX * 1.15 + vibX,
      m2.dy + (4.0 / 3.0) * sagY * 1.15 + vibY,
    );

    return BezierControlPoints(c1: c1, c2: c2);
  }

  /// Evaluates cubic Bezier curve position at parameter [t] in [0, 1].
  static Offset evaluateCubicBezier({
    required Offset p1,
    required Offset c1,
    required Offset c2,
    required Offset p2,
    required double t,
  }) {
    final clampedT = t.clamp(0.0, 1.0);
    final u = 1.0 - clampedT;
    final tt = clampedT * clampedT;
    final uu = u * u;
    final uuu = uu * u;
    final ttt = tt * clampedT;

    final x = uuu * p1.dx + 3 * uu * clampedT * c1.dx + 3 * u * tt * c2.dx + ttt * p2.dx;
    final y = uuu * p1.dy + 3 * uu * clampedT * c1.dy + 3 * u * tt * c2.dy + ttt * p2.dy;

    return Offset(x, y);
  }
}

/// Physics-aware fishing line Flame component.
///
/// Binds strictly to the character's rod tip position with 0.0 px delta,
/// connects dynamically to the bobber, and renders a realistic catenary/Bezier
/// curve with tension sag, wind drift, and strain micro-vibration.
class FishingLineComponent extends Component {
  final Vector2 Function() rodTipProvider;
  final Vector2? Function() bobberPositionProvider;
  final double Function() tensionProvider;
  final double Function()? windFactorProvider;
  final bool Function()? activeProvider;

  bool _internalActive = true;
  double _time = 0.0;

  // Cached vector path and paint to avoid per-frame allocations
  final Path _linePath = Path();
  final Paint _linePaint = Paint()
    ..color = const Color(0xB3FFFFFF) // semi-transparent nylon monofilament
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  FishingLineComponent({
    required this.rodTipProvider,
    required this.bobberPositionProvider,
    required this.tensionProvider,
    this.windFactorProvider,
    this.activeProvider,
  }) : super(priority: GameConfig.priorityFishingLine);

  bool get isActive {
    if (!_internalActive) return false;
    if (activeProvider != null) {
      return activeProvider!();
    }
    return true;
  }

  set isActive(bool value) {
    _internalActive = value;
    if (!value) {
      _linePath.reset();
    }
  }

  /// Retracts and deactivates the line immediately, clearing the path.
  void deactivate() {
    isActive = false;
  }

  /// Activates line rendering.
  void activate() {
    isActive = true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (!isActive) return;

    final bobberPos = bobberPositionProvider();
    if (bobberPos == null) return;

    final rodTip = rodTipProvider();
    final p1 = Offset(rodTip.x, rodTip.y);
    final p2 = Offset(bobberPos.x, bobberPos.y);

    final tension = tensionProvider();
    final wind = windFactorProvider?.call() ?? 0.0;

    final controlPoints = FishingLineMath.computeControlPoints(
      p1: p1,
      p2: p2,
      tension: tension,
      windFactor: wind,
      time: _time,
    );

    _linePath.reset();
    _linePath.moveTo(p1.dx, p1.dy);
    _linePath.cubicTo(
      controlPoints.c1.dx,
      controlPoints.c1.dy,
      controlPoints.c2.dx,
      controlPoints.c2.dy,
      p2.dx,
      p2.dy,
    );

    // Adjust stroke width and alpha under heavy tension
    if (tension > 0.75) {
      _linePaint.strokeWidth = 1.2;
      _linePaint.color = Colors.white;
    } else {
      _linePaint.strokeWidth = 1.0;
      _linePaint.color = const Color(0xB3FFFFFF);
    }

    canvas.drawPath(_linePath, _linePaint);
  }
}
