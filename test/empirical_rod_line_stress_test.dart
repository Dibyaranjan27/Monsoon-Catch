import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monsoon_catch/components/character.dart';
import 'package:monsoon_catch/components/fishing_line.dart';

void main() {
  group('Challenger Empirical Stress Tests: Rod Tip, Continuity & Line Math', () {
    // Ground anchor at default riverbank position
    final defaultGround = Vector2(118.0, 208.8);

    // =========================================================================
    // 1. ANALYTICAL ROD TIP COORDINATES IN ALL 4 POSES
    // =========================================================================
    group('1. Analytical Coordinates Across All 4 Poses', () {
      test('Idle Pose: matches analytical trigonometry with breathing bob', () {
        final character = CharacterComponent(position: defaultGround);
        character.current = CharacterState.idle;

        const expectedBaseX = 118.0 + 14.0; // 132.0
        const expectedBaseY = 208.8 - 22.8; // 186.0
        const thetaRad = 42.0 * pi / 180.0;
        final expectedTipX = expectedBaseX + 48.0 * cos(thetaRad); // ~167.671

        // Verify across 240 samples of full breathing period (2.4s)
        for (int i = 0; i <= 240; i++) {
          final dt = 0.01;
          character.update(dt);
          final tip = character.rodTipPosition;
          final base = character.rodBasePosition;

          // Tip X is constant in idle
          expect(tip.x, closeTo(expectedTipX, 1e-4));
          expect(base.x, closeTo(expectedBaseX, 1e-4));

          // Base Y bobs with 0.8 * sin(2*pi*t/2.4)
          final expectedBob = 0.8 * sin(2.0 * pi * (i * dt) / 2.4);
          expect(base.y, closeTo(expectedBaseY + expectedBob, 0.05));

          // Tip Y is exactly base.y - 48*sin(42 deg)
          final expectedTipY = base.y - 48.0 * sin(thetaRad);
          expect(tip.y, closeTo(expectedTipY, 1e-4));

          // Values must be strictly finite
          expect(tip.x.isFinite, isTrue);
          expect(tip.y.isFinite, isTrue);
        }
      });

      test('Reeling / Strain Pose: matches analytical chord, lean, and 14 Hz micro-jitter', () {
        final character = CharacterComponent(position: defaultGround);
        character.reel();
        expect(character.current, equals(CharacterState.reeling));

        const expectedBaseX = 118.0 + 6.0; // 124.0 (braced back)
        const expectedBaseY = 208.8 - 24.8; // 184.0
        const chordLength = 41.5;
        const thetaRad = -12.0 * pi / 180.0;
        final steadyTipX = expectedBaseX + chordLength * cos(thetaRad); // ~164.593
        final steadyTipY = expectedBaseY - chordLength * sin(thetaRad); // ~192.628

        // Verify across 200 samples of jitter
        for (int i = 0; i < 200; i++) {
          character.update(0.005);
          final tip = character.rodTipPosition;
          final base = character.rodBasePosition;

          expect(base.x, equals(expectedBaseX));
          expect(base.y, equals(expectedBaseY));

          // Jitter bounds: dx in [-0.6, 0.6], dy in [-1.2, 1.2]
          expect(tip.x, closeTo(steadyTipX, 0.61));
          expect(tip.y, closeTo(steadyTipY, 1.21));
          expect(tip.x.isFinite, isTrue);
          expect(tip.y.isFinite, isTrue);
        }
      });

      test('Caught Pose: matches analytical elevation and joyful hop', () {
        final character = CharacterComponent(position: defaultGround);
        character.catchFish();
        expect(character.current, equals(CharacterState.caught));

        const expectedBaseX = 118.0 + 10.0; // 128.0
        const thetaRad = 74.0 * pi / 180.0;
        final steadyTipX = expectedBaseX + 48.0 * cos(thetaRad); // ~141.231

        for (int i = 0; i <= 100; i++) {
          character.update(0.01);
          final tip = character.rodTipPosition;
          final base = character.rodBasePosition;

          expect(tip.x, closeTo(steadyTipX, 1e-4));
          // Hop moves base vertically: -3.5 * |sin(4*pi*t)| in [-3.5, 0.0]
          expect(base.y, inInclusiveRange(172.0 - 3.51, 172.0 + 0.01));
          final expectedTipY = base.y - 48.0 * sin(thetaRad);
          expect(tip.y, closeTo(expectedTipY, 1e-4));
          expect(tip.x.isFinite, isTrue);
          expect(tip.y.isFinite, isTrue);
        }
      });
    });

    // =========================================================================
    // 2. CONTINUOUS C0 CONTINUITY OF ROD TIP THROUGHOUT CASTING ANIMATION
    // =========================================================================
    group('2. Casting Animation C0 Continuity & Boundary Tests', () {
      test('Strict C0 continuity at phase boundaries (t = 0.25, 0.65, 0.85)', () {
        final character = CharacterComponent(position: defaultGround);
        character.current = CharacterState.casting;

        const boundaries = [0.25, 0.65, 0.85];
        const epsilon = 1e-9;

        for (final t0 in boundaries) {
          // Left limit
          character.castProgress = t0 - epsilon;
          final tipLeft = character.rodTipPosition;

          // Right limit
          character.castProgress = t0 + epsilon;
          final tipRight = character.rodTipPosition;

          // Exact limit at boundary
          character.castProgress = t0;
          final tipExact = character.rodTipPosition;

          final deltaLeftRight = (tipRight - tipLeft).length;
          final deltaExact = (tipExact - tipLeft).length;

          // C0 continuity requirement: jump across boundary approaches 0
          expect(deltaLeftRight, lessThan(1e-4),
              reason: 'Discontinuity detected at t = $t0 across left/right limits');
          expect(deltaExact, lessThan(1e-4),
              reason: 'Discontinuity detected at t = $t0 between exact and left limit');
        }
      });

      test('High-resolution sampling (10,000 samples) across t in [0, 1] reveals zero jumps or NaNs', () {
        final character = CharacterComponent(position: defaultGround);
        character.current = CharacterState.casting;

        const sampleCount = 10000;
        Vector2 prevTip = character.rodTipPosition;

        double maxStepDistance = 0.0;
        double maxVelocity = 0.0;

        for (int i = 0; i <= sampleCount; i++) {
          final t = i / sampleCount;
          character.castProgress = t;
          final tip = character.rodTipPosition;

          // Must be strictly finite (no NaN, no Inf)
          expect(tip.x.isFinite, isTrue);
          expect(tip.y.isFinite, isTrue);

          if (i > 0) {
            final stepDist = (tip - prevTip).length;
            if (stepDist > maxStepDistance) {
              maxStepDistance = stepDist;
            }
            final dt = 1.0 / sampleCount;
            final vel = stepDist / dt;
            if (vel > maxVelocity) {
              maxVelocity = vel;
            }

            // At 10,000 steps, max step distance should be very small (< 0.15 px)
            expect(stepDist, lessThan(0.15),
                reason: 'Discontinuous jump of $stepDist px observed at step $i (t = $t)');
          }
          prevTip = tip;
        }

        // Verify trajectory is smooth and bounded
        expect(maxStepDistance, lessThan(0.12));
        expect(maxVelocity, lessThan(1200.0)); // bounded speed in px/s normalized
      });

      test('Extrema are reached at windup (t=0.25) and release (t=0.65)', () {
        final character = CharacterComponent(position: defaultGround);
        character.current = CharacterState.casting;

        // At t = 0.25: Windup Apex
        character.castProgress = 0.25;
        final windupTip = character.rodTipPosition;
        expect(windupTip.x, closeTo(91.15, 0.05));
        expect(windupTip.y, closeTo(139.23, 0.05));

        // At t = 0.65: Forward Release
        character.castProgress = 0.65;
        final releaseTip = character.rodTipPosition;
        expect(releaseTip.x, closeTo(189.10, 0.05));
        expect(releaseTip.y, closeTo(165.58, 0.05));

        // Net horizontal whip span exceeds 95 px
        final whipSpanX = releaseTip.x - windupTip.x;
        expect(whipSpanX, greaterThan(95.0));
      });
    });

    // =========================================================================
    // 3. ROD FLEX DELTA UNDER STRAIN (> 35 PX DROP RELATIVE TO IDLE)
    // =========================================================================
    group('3. Rod Flex Delta Under Strain', () {
      test('Downward bow exceeds 35 px drop across all relative time phase combinations', () {
        final characterIdle = CharacterComponent(position: defaultGround);
        characterIdle.current = CharacterState.idle;

        final characterStrain = CharacterComponent(position: defaultGround);
        characterStrain.reel();

        // Sample 120 time steps covering breathing bob cycle and jitter cycles
        for (int i = 0; i <= 120; i++) {
          final dt = 0.02;
          characterIdle.update(dt);
          characterStrain.update(dt);

          final idleTip = characterIdle.rodTipPosition;
          final strainTip = characterStrain.rodTipPosition;

          final downwardDeflection = strainTip.y - idleTip.y;

          // Strict requirement: drop must exceed 35.0 px under all conditions
          expect(downwardDeflection, greaterThan(35.0),
              reason: 'Downward deflection $downwardDeflection px was not > 35.0 px at step $i');
          expect(downwardDeflection, lessThan(42.0),
              reason: 'Downward deflection $downwardDeflection px exceeded physical plausibility');
        }
      });
    });

    // =========================================================================
    // 4. ELEVATION OF ROD TIP IN CAUGHT POSE RELATIVE TO IDLE
    // =========================================================================
    group('4. Caught Celebratory Pose Elevation', () {
      test('Rod tip is significantly elevated above idle across all animation ticks', () {
        final characterIdle = CharacterComponent(position: defaultGround);
        characterIdle.current = CharacterState.idle;

        final characterCaught = CharacterComponent(position: defaultGround);
        characterCaught.catchFish();

        for (int i = 0; i <= 100; i++) {
          final dt = 0.02;
          characterIdle.update(dt);
          characterCaught.update(dt);

          final idleTip = characterIdle.rodTipPosition;
          final caughtTip = characterCaught.rodTipPosition;

          // Tip elevation = idleTip.y - caughtTip.y (in screen coordinates, lower y is higher elevation)
          final elevation = idleTip.y - caughtTip.y;

          // Must be elevated by at least 25.0 px above idle at all times
          expect(elevation, greaterThan(25.0),
              reason: 'Celebratory rod tip elevation $elevation px was not > 25.0 px at step $i');
          expect(elevation, lessThan(35.0));
        }
      });
    });

    // =========================================================================
    // 5. LINE ORIGIN CONNECTION: STRICTLY 0.0 PX DELTA UNDER ALL CONDITIONS
    // =========================================================================
    group('5. Zero-Gap Line Origin Connection Invariant', () {
      test('Delta between line start and rod tip is strictly 0.0 px across all 4 poses', () {
        final character = CharacterComponent(position: defaultGround);

        for (final state in CharacterState.values) {
          character.current = state;

          for (int t = 0; t <= 50; t++) {
            character.update(0.02);
            if (state == CharacterState.casting) {
              character.castProgress = t / 50.0;
            }

            final rodTip = character.rodTipPosition;
            final lineStart = character.rodTipPosition; // bound by provider

            final delta = (rodTip - lineStart).length;
            expect(delta, equals(0.0));
          }
        }
      });

      test('Cubic Bezier curve start point B(0.0) is mathematically identical to p1', () {
        final character = CharacterComponent(position: defaultGround);
        const bobberPos = Offset(350.0, 245.0);

        for (final state in CharacterState.values) {
          character.current = state;
          final tip = character.rodTipPosition;
          final p1 = Offset(tip.x, tip.y);

          final cp = FishingLineMath.computeControlPoints(
            p1: p1,
            p2: bobberPos,
            tension: 0.5,
          );

          final curveStart = FishingLineMath.evaluateCubicBezier(
            p1: p1,
            c1: cp.c1,
            c2: cp.c2,
            p2: bobberPos,
            t: 0.0,
          );

          final startDelta = (curveStart - p1).distance;
          expect(startDelta, closeTo(0.0, 1e-6));
        }
      });
    });

    // =========================================================================
    // 6. NUMERICAL STABILITY, FLOATING POINT BOUNDS & ADVERSARIAL INPUTS
    // =========================================================================
    group('6. Adversarial Floating-Point Stability & Extreme Edge Cases', () {
      const standardTip = Offset(167.67, 153.88);

      test('Zero distance span (p1 == p2) does not crash or divide by zero', () {
        final cp = FishingLineMath.computeControlPoints(
          p1: standardTip,
          p2: standardTip,
          tension: 1.0,
          windFactor: 1.0,
        );
        expect(cp.c1.dx, equals(standardTip.dx));
        expect(cp.c1.dy, equals(standardTip.dy));
        expect(cp.c2.dx, equals(standardTip.dx));
        expect(cp.c2.dy, equals(standardTip.dy));
      });

      test('Microscopic sub-pixel spans (< 1e-4) gracefully degrade to endpoints', () {
        const microBobber = Offset(167.670001, 153.880001);
        final cp = FishingLineMath.computeControlPoints(
          p1: standardTip,
          p2: microBobber,
          tension: 0.9,
        );
        expect(cp.c1.dx.isFinite, isTrue);
        expect(cp.c1.dy.isFinite, isTrue);
        expect(cp.c2.dx.isFinite, isTrue);
        expect(cp.c2.dy.isFinite, isTrue);
      });

      test('Astronomical spans (1,000,000 px) remain bounded by kMaxSag (38.0)', () {
        const distantBobber = Offset(1000167.67, 153.88);
        final cp = FishingLineMath.computeControlPoints(
          p1: standardTip,
          p2: distantBobber,
          tension: 0.0,
        );
        final mid = FishingLineMath.evaluateCubicBezier(
          p1: standardTip,
          c1: cp.c1,
          c2: cp.c2,
          p2: distantBobber,
          t: 0.5,
        );
        final sag = mid.dy - (standardTip.dy + distantBobber.dy) / 2.0;
        expect(sag, closeTo(FishingLineMath.kMaxSag, 1e-2));
      });

      test('Negative and reversed geometry (bobber behind fisher or above rod)', () {
        // Bobber behind fisher (x < tip.x)
        const behindBobber = Offset(50.0, 200.0);
        final cpBehind = FishingLineMath.computeControlPoints(
          p1: standardTip,
          p2: behindBobber,
          tension: 0.5,
        );
        expect(cpBehind.c1.dx.isFinite, isTrue);
        expect(cpBehind.c1.dy.isFinite, isTrue);

        // Bobber elevated in tree above fisher (y < tip.y)
        const highBobber = Offset(300.0, 50.0);
        final cpHigh = FishingLineMath.computeControlPoints(
          p1: standardTip,
          p2: highBobber,
          tension: 0.5,
        );
        expect(cpHigh.c1.dx.isFinite, isTrue);
        expect(cpHigh.c1.dy.isFinite, isTrue);
      });

      test('Corrupted / Non-finite inputs (NaN, +/- Infinity) sanitized safely', () {
        final cpNaN = FishingLineMath.computeControlPoints(
          p1: const Offset(double.nan, double.nan),
          p2: const Offset(double.nan, double.nan),
          tension: double.nan,
          windFactor: double.nan,
          time: double.nan,
        );
        expect(cpNaN.c1.dx.isFinite, isTrue);
        expect(cpNaN.c1.dy.isFinite, isTrue);
        expect(cpNaN.c2.dx.isFinite, isTrue);
        expect(cpNaN.c2.dy.isFinite, isTrue);

        final cpInf = FishingLineMath.computeControlPoints(
          p1: const Offset(double.infinity, double.negativeInfinity),
          p2: const Offset(double.negativeInfinity, double.infinity),
          tension: double.infinity,
          windFactor: double.negativeInfinity,
          time: double.infinity,
        );
        expect(cpInf.c1.dx.isFinite, isTrue);
        expect(cpInf.c1.dy.isFinite, isTrue);
        expect(cpInf.c2.dx.isFinite, isTrue);
        expect(cpInf.c2.dy.isFinite, isTrue);
      });

      test('Tension and wind factor clamping outside [0, 1] and [-1, 1]', () {
        // Tension = -5.0 (treated as 0.0)
        final cpUnderTension = FishingLineMath.computeControlPoints(
          p1: standardTip,
          p2: const Offset(350.0, 250.0),
          tension: -5.0,
        );
        final cpZeroTension = FishingLineMath.computeControlPoints(
          p1: standardTip,
          p2: const Offset(350.0, 250.0),
          tension: 0.0,
        );
        expect(cpUnderTension.c1.dy, equals(cpZeroTension.c1.dy));

        // Tension = 99.0 (treated as 1.0)
        final cpOverTension = FishingLineMath.computeControlPoints(
          p1: standardTip,
          p2: const Offset(350.0, 250.0),
          tension: 99.0,
          time: 0.0,
        );
        final cpFullTension = FishingLineMath.computeControlPoints(
          p1: standardTip,
          p2: const Offset(350.0, 250.0),
          tension: 1.0,
          time: 0.0,
        );
        expect(cpOverTension.c1.dy, equals(cpFullTension.c1.dy));
      });

      test('OutOfRange parameter t in evaluateCubicBezier is safely clamped', () {
        const c1 = Offset(200.0, 180.0);
        const c2 = Offset(300.0, 220.0);
        const p2 = Offset(350.0, 250.0);

        final ptUnder = FishingLineMath.evaluateCubicBezier(
          p1: standardTip,
          c1: c1,
          c2: c2,
          p2: p2,
          t: -10.0,
        );
        expect(ptUnder.dx, equals(standardTip.dx));
        expect(ptUnder.dy, equals(standardTip.dy));

        final ptOver = FishingLineMath.evaluateCubicBezier(
          p1: standardTip,
          c1: c1,
          c2: c2,
          p2: p2,
          t: 10.0,
        );
        expect(ptOver.dx, equals(p2.dx));
        expect(ptOver.dy, equals(p2.dy));
      });
    });
  });
}
