import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monsoon_catch/components/bobber.dart';
import 'package:monsoon_catch/components/character.dart';
import 'package:monsoon_catch/components/fishing_line.dart';
import 'package:monsoon_catch/game/monsoon_world.dart';

/// Test spy canvas recording draw calls and capturing paths.
class RecordingSpyCanvas extends Fake implements Canvas {
  int drawCallCount = 0;
  Path? lastDrawnPath;
  Paint? lastDrawnPaint;

  @override
  void drawPath(Path path, Paint paint) {
    drawCallCount++;
    lastDrawnPath = path;
    lastDrawnPaint = paint;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fishing Line Physics & Tension Decay Stress Tests', () {
    const p1 = Offset(167.67, 153.88); // rod tip
    const p2 = Offset(360.0, 260.0); // bobber in pond

    // -------------------------------------------------------------------------
    // 1. Tension Decay Monotonicity
    // -------------------------------------------------------------------------
    test('Tension decay monotonicity: sag strictly decreases across 1,000 tension steps (tau 0.0 -> 1.0)', () {
      final chordMidY = (p1.dy + p2.dy) / 2.0;
      double previousSag = double.infinity;

      const int steps = 1000;
      for (int i = 0; i <= steps; i++) {
        final tau = i / steps.toDouble();
        final cp = FishingLineMath.computeControlPoints(
          p1: p1,
          p2: p2,
          tension: tau,
          time: 0.0, // test pure gravitational tension decay without vibration
        );

        final mid = FishingLineMath.evaluateCubicBezier(
          p1: p1,
          c1: cp.c1,
          c2: cp.c2,
          p2: p2,
          t: 0.5,
        );

        final currentSag = mid.dy - chordMidY;

        // Verify strictly non-negative sag
        expect(currentSag, greaterThanOrEqualTo(-1e-9),
            reason: 'Sag must never be negative when drooping downward at tau=$tau');

        // Verify strict monotonic decrease: currentSag < previousSag for tau > 0
        if (i > 0) {
          expect(currentSag, lessThan(previousSag),
              reason: 'Sag at tau=$tau ($currentSag) must be strictly less than previous ($previousSag)');
        }

        previousSag = currentSag;
      }

      // At tau = 1.0, sag must collapse exactly to 0.0
      expect(previousSag, closeTo(0.0, 1e-9));
    });

    test('Tension decay monotonicity holds across all intermediate curve evaluation points (t in [0.1, 0.9])', () {
      const List<double> tSamples = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9];

      for (final t in tSamples) {
        final chordPointY = p1.dy + (p2.dy - p1.dy) * t;
        double previousDeflection = double.infinity;

        for (int i = 0; i <= 100; i++) {
          final tau = i / 100.0;
          final cp = FishingLineMath.computeControlPoints(
            p1: p1,
            p2: p2,
            tension: tau,
            time: 0.0,
          );

          final pt = FishingLineMath.evaluateCubicBezier(
            p1: p1,
            c1: cp.c1,
            c2: cp.c2,
            p2: p2,
            t: t,
          );

          final deflection = pt.dy - chordPointY;

          expect(deflection, greaterThanOrEqualTo(-1e-9));
          if (i > 0) {
            expect(deflection, lessThan(previousDeflection),
                reason: 'Deflection at t=$t, tau=$tau ($deflection) must be strictly less than previous ($previousDeflection)');
          }
          previousDeflection = deflection;
        }

        expect(previousDeflection, closeTo(0.0, 1e-9));
      }
    });

    test('Sag monotonicity holds across diverse span regimes (short, medium, long, extreme)', () {
      final List<Offset> targets = [
        Offset(p1.dx + 5.0, p1.dy + 5.0), // Span ~7.07 px (sub-min clamped)
        Offset(p1.dx + 25.0, p1.dy + 10.0), // Span ~26.9 px
        Offset(p1.dx + 120.0, p1.dy + 80.0), // Span ~144.2 px
        Offset(p1.dx + 300.0, p1.dy + 120.0), // Span ~323.1 px (above max clamped)
        Offset(p1.dx + 800.0, p1.dy + 200.0), // Span ~824.6 px (extreme clamped)
      ];

      for (final target in targets) {
        final chordMidY = (p1.dy + target.dy) / 2.0;
        double previousSag = double.infinity;

        for (int i = 0; i <= 50; i++) {
          final tau = i / 50.0;
          final cp = FishingLineMath.computeControlPoints(
            p1: p1,
            p2: target,
            tension: tau,
            time: 0.0,
          );

          final mid = FishingLineMath.evaluateCubicBezier(
            p1: p1,
            c1: cp.c1,
            c2: cp.c2,
            p2: target,
            t: 0.5,
          );

          final sag = mid.dy - chordMidY;
          if (i > 0) {
            expect(sag, lessThan(previousSag));
          }
          previousSag = sag;
        }
        expect(previousSag, closeTo(0.0, 1e-9));
      }
    });

    test('Horizontal wind drift strictly decays to 0.0 as tension increases to 1.0', () {
      final chordMidX = (p1.dx + p2.dx) / 2.0;
      double previousDrift = double.infinity;

      for (int i = 0; i <= 100; i++) {
        final tau = i / 100.0;
        final cp = FishingLineMath.computeControlPoints(
          p1: p1,
          p2: p2,
          tension: tau,
          windFactor: 1.0, // maximum crosswind
          time: 0.0,
        );

        final mid = FishingLineMath.evaluateCubicBezier(
          p1: p1,
          c1: cp.c1,
          c2: cp.c2,
          p2: p2,
          t: 0.5,
        );

        final drift = mid.dx - chordMidX;
        expect(drift, greaterThanOrEqualTo(-1e-9));
        if (i > 0) {
          expect(drift, lessThan(previousDrift));
        }
        previousDrift = drift;
      }
      expect(previousDrift, closeTo(0.0, 1e-9));
    });

    test('Out-of-range tension values clamp safely ([<0.0] -> 0.0, [>1.0] -> 1.0)', () {
      final chordMidY = (p1.dy + p2.dy) / 2.0;

      // Negative tension clamped to 0.0 (no runaway sag)
      final cpNeg = FishingLineMath.computeControlPoints(p1: p1, p2: p2, tension: -0.5, time: 0.0);
      final cpZero = FishingLineMath.computeControlPoints(p1: p1, p2: p2, tension: 0.0, time: 0.0);
      final midNeg = FishingLineMath.evaluateCubicBezier(p1: p1, c1: cpNeg.c1, c2: cpNeg.c2, p2: p2, t: 0.5);
      final midZero = FishingLineMath.evaluateCubicBezier(p1: p1, c1: cpZero.c1, c2: cpZero.c2, p2: p2, t: 0.5);
      expect(midNeg.dy - chordMidY, closeTo(midZero.dy - chordMidY, 1e-6));

      // Over-tension clamped to 1.0 (no negative sag or inversion)
      final cpOver = FishingLineMath.computeControlPoints(p1: p1, p2: p2, tension: 2.5, time: 0.0);
      final cpOne = FishingLineMath.computeControlPoints(p1: p1, p2: p2, tension: 1.0, time: 0.0);
      final midOver = FishingLineMath.evaluateCubicBezier(p1: p1, c1: cpOver.c1, c2: cpOver.c2, p2: p2, t: 0.5);
      final midOne = FishingLineMath.evaluateCubicBezier(p1: p1, c1: cpOne.c1, c2: cpOne.c2, p2: p2, t: 0.5);
      expect(midOver.dy - chordMidY, closeTo(midOne.dy - chordMidY, 1e-6));
      expect(midOver.dy - chordMidY, closeTo(0.0, 1e-6));
    });

    // -------------------------------------------------------------------------
    // 2. Taut Chord at tau = 1.0 & Micro-Vibration Bounds
    // -------------------------------------------------------------------------
    test('At tau = 1.0 without vibration, line is mathematically identical to straight chord', () {
      final cp = FishingLineMath.computeControlPoints(
        p1: p1,
        p2: p2,
        tension: 1.0,
        time: 0.0,
      );

      // Verify for 100 sample points along parameter t
      for (int i = 0; i <= 100; i++) {
        final t = i / 100.0;
        final bezierPt = FishingLineMath.evaluateCubicBezier(
          p1: p1,
          c1: cp.c1,
          c2: cp.c2,
          p2: p2,
          t: t,
        );

        final straightChordPt = Offset(
          p1.dx + (p2.dx - p1.dx) * t,
          p1.dy + (p2.dy - p1.dy) * t,
        );

        expect(bezierPt.dx, closeTo(straightChordPt.dx, 1e-6),
            reason: 'X coord on straight chord at t=$t must match exactly');
        expect(bezierPt.dy, closeTo(straightChordPt.dy, 1e-6),
            reason: 'Y coord on straight chord at t=$t must match exactly');
      }
    });

    test('At tau = 1.0 with vibration, micro-vibration normal displacement is bounded by <= 1.2 px', () {
      final dx = p2.dx - p1.dx;
      final dy = p2.dy - p1.dy;

      // Test across 200 arbitrary timestamps
      for (int i = 0; i <= 200; i++) {
        final time = i * 0.05; // 0 to 10 seconds
        final cp = FishingLineMath.computeControlPoints(
          p1: p1,
          p2: p2,
          tension: 1.0,
          time: time,
        );

        // Control point displacement from trisection base
        final m1 = Offset(p1.dx + dx / 3.0, p1.dy + dy / 3.0);
        final displacement = (cp.c1 - m1).distance;

        // Max control point vibration amplitude is 1.2 px
        expect(displacement, lessThanOrEqualTo(1.2 + 1e-4),
            reason: 'Control point displacement at time=$time was $displacement, exceeding 1.2 px bound');

        // Check curve midpoint deviation from chord
        final mid = FishingLineMath.evaluateCubicBezier(
          p1: p1,
          c1: cp.c1,
          c2: cp.c2,
          p2: p2,
          t: 0.5,
        );
        final chordMid = Offset((p1.dx + p2.dx) / 2.0, (p1.dy + p2.dy) / 2.0);
        final midDeviation = (mid - chordMid).distance;

        // Bezier midpoint displacement = 0.75 * vibAmp <= 0.9 px
        expect(midDeviation, lessThanOrEqualTo(0.90 + 1e-4),
            reason: 'Midpoint vibration displacement at time=$time was $midDeviation, exceeding theoretical 0.90 px bound');
      }
    });

    test('Micro-vibration frequency matches kVibrationFrequency = 32 rad/s', () {
      // Quarter period: T/4 = (pi / 2) / 32
      const quarterPeriod = (pi / 2.0) / 32.0;

      final cp0 = FishingLineMath.computeControlPoints(p1: p1, p2: p2, tension: 1.0, time: 0.0);
      final cpQuarter = FishingLineMath.computeControlPoints(p1: p1, p2: p2, tension: 1.0, time: quarterPeriod);
      final cpHalf = FishingLineMath.computeControlPoints(p1: p1, p2: p2, tension: 1.0, time: quarterPeriod * 2);
      final cpThreeQuarter = FishingLineMath.computeControlPoints(p1: p1, p2: p2, tension: 1.0, time: quarterPeriod * 3);

      final m1 = Offset(p1.dx + (p2.dx - p1.dx) / 3.0, p1.dy + (p2.dy - p1.dy) / 3.0);

      // At t=0: sin(0) = 0 -> displacement 0
      expect((cp0.c1 - m1).distance, closeTo(0.0, 1e-6));

      // At t=T/4: sin(pi/2) = 1 -> peak displacement 1.2
      expect((cpQuarter.c1 - m1).distance, closeTo(1.2, 1e-4));

      // At t=T/2: sin(pi) = 0 -> displacement 0
      expect((cpHalf.c1 - m1).distance, closeTo(0.0, 1e-4));

      // At t=3T/4: sin(3pi/2) = -1 -> peak displacement 1.2
      expect((cpThreeQuarter.c1 - m1).distance, closeTo(1.2, 1e-4));
    });

    test('Line endpoints remain strictly pinned to rod tip and bobber under all conditions', () {
      final rng = Random(42);

      for (int i = 0; i < 50; i++) {
        final randP1 = Offset(rng.nextDouble() * 200, rng.nextDouble() * 200);
        final randP2 = Offset(250 + rng.nextDouble() * 300, 200 + rng.nextDouble() * 150);
        final randTau = rng.nextDouble();
        final randWind = rng.nextDouble() * 2.0 - 1.0;
        final randTime = rng.nextDouble() * 10.0;

        final cp = FishingLineMath.computeControlPoints(
          p1: randP1,
          p2: randP2,
          tension: randTau,
          windFactor: randWind,
          time: randTime,
        );

        final evaluatedStart = FishingLineMath.evaluateCubicBezier(
          p1: randP1,
          c1: cp.c1,
          c2: cp.c2,
          p2: randP2,
          t: 0.0,
        );
        expect((evaluatedStart - randP1).distance, closeTo(0.0, 1e-6));

        final evaluatedEnd = FishingLineMath.evaluateCubicBezier(
          p1: randP1,
          c1: cp.c1,
          c2: cp.c2,
          p2: randP2,
          t: 1.0,
        );
        expect((evaluatedEnd - randP2).distance, closeTo(0.0, 1e-6));
      }
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Rapid State Cycling & Flame Lifecycle Cleanup
  // ---------------------------------------------------------------------------
  group('Rapid State Cycling & Lifecycle Stress Tests', () {
    late MonsoonWorld world;

    setUp(() async {
      world = MonsoonWorld();
      await world.onLoad();
    });

    test('Simulate 150 rapid alternating cast() and reset() cycles: 0 orphan bobbers remain', () {
      final rng = Random(1337);

      for (int cycle = 1; cycle <= 150; cycle++) {
        final targetX = 220.0 + rng.nextDouble() * 300.0;
        final targetY = 230.0 + rng.nextDouble() * 80.0;

        world.castTo(Vector2(targetX, targetY));

        // Invariant: active cast has exactly 1 bobber and active line
        expect(world.children.whereType<BobberComponent>().length, equals(1));
        expect(world.currentBobber, isNotNull);
        expect(world.fishingLine.isActive, isTrue);

        // Immediate reset
        world.resetFishingState();

        // Invariant: clean state with 0 orphan entities
        expect(world.children.whereType<BobberComponent>().isEmpty, isTrue,
            reason: 'Cycle $cycle: Orphan bobber remained in world.children');
        expect(world.currentBobber, isNull,
            reason: 'Cycle $cycle: currentBobber was not cleared');
        expect(world.fishingLine.isActive, isFalse,
            reason: 'Cycle $cycle: fishingLine remained active');
        expect(world.character.current, equals(CharacterState.idle),
            reason: 'Cycle $cycle: character did not return to idle');
      }
    });

    test('Simulate 120 rapid repeated cast() calls without intermediate reset: no bobbers leak', () {
      final rng = Random(777);

      for (int cycle = 1; cycle <= 120; cycle++) {
        final targetX = 220.0 + rng.nextDouble() * 300.0;
        final targetY = 230.0 + rng.nextDouble() * 80.0;

        // Cast immediately without manual reset
        world.castTo(Vector2(targetX, targetY));

        // Crucial invariant: never allow more than 1 BobberComponent in Flame children tree
        final bobberCount = world.children.whereType<BobberComponent>().length;
        expect(bobberCount, equals(1),
            reason: 'Cycle $cycle: Bobber leak detected! Child count was $bobberCount instead of 1');
      }

      // Clean cleanup at end
      world.resetFishingState();
      expect(world.children.whereType<BobberComponent>().isEmpty, isTrue);
      expect(world.currentBobber, isNull);
    });

    test('Simulate 100 complete state lifecycles (cast -> touchdown -> bite -> reel -> catch -> auto-reset)', () {
      for (int cycle = 1; cycle <= 100; cycle++) {
        world.castTo(Vector2(320.0, 250.0));
        expect(world.character.current, equals(CharacterState.casting));

        // Advance touchdown
        world.currentBobber!.update(0.70);
        expect(world.currentBobber!.state, equals(BobberState.floating));

        // Trigger fish strike
        world.currentBobber!.changeState(BobberState.bite);
        world.character.reel();
        expect(world.character.current, equals(CharacterState.reeling));

        // Successful catch
        world.currentBobber!.changeState(BobberState.caught);
        world.character.catchFish();
        expect(world.character.current, equals(CharacterState.caught));

        // Reset
        world.resetFishingState();
        expect(world.children.whereType<BobberComponent>().isEmpty, isTrue);
        expect(world.currentBobber, isNull);
        expect(world.fishingLine.isActive, isFalse);
        expect(world.character.current, equals(CharacterState.idle));
      }
    });

    test('Simulate 100 early miss lifecycles (cast -> touchdown -> early reel -> miss -> reset)', () {
      for (int cycle = 1; cycle <= 100; cycle++) {
        world.castTo(Vector2(300.0, 245.0));

        // Touchdown
        world.currentBobber!.update(0.70);
        expect(world.currentBobber!.state, equals(BobberState.floating));

        // Premature reel -> miss
        world.currentBobber!.changeState(BobberState.missed);
        world.character.current = CharacterState.idle;

        // Reset
        world.resetFishingState();
        expect(world.children.whereType<BobberComponent>().isEmpty, isTrue);
        expect(world.currentBobber, isNull);
        expect(world.fishingLine.isActive, isFalse);
      }
    });

    test('Adversarial fuzzing: 500 chaotic random actions preserve zero-leak invariant', () {
      final rng = Random(999);

      for (int step = 0; step < 500; step++) {
        final action = rng.nextInt(6);
        switch (action) {
          case 0:
            world.castTo(Vector2(200.0 + rng.nextDouble() * 300.0, 225.0 + rng.nextDouble() * 90.0));
            break;
          case 1:
            world.update(rng.nextDouble() * 0.5);
            break;
          case 2:
            if (world.currentBobber != null) {
              world.character.reel();
              world.currentBobber!.changeState(BobberState.bite);
            }
            break;
          case 3:
            if (world.currentBobber != null) {
              world.character.catchFish();
              world.currentBobber!.changeState(BobberState.caught);
            }
            break;
          case 4:
            if (world.currentBobber != null) {
              world.currentBobber!.changeState(BobberState.missed);
            }
            break;
          case 5:
            world.resetFishingState();
            break;
        }

        // At any point, bobber count is either 0 or 1, never more!
        final bobbers = world.children.whereType<BobberComponent>().length;
        expect(bobbers, inInclusiveRange(0, 1),
            reason: 'Step $step: Multiple bobbers detected in Flame tree: $bobbers');
      }

      // Final cleanup verification
      world.resetFishingState();
      expect(world.children.whereType<BobberComponent>().isEmpty, isTrue);
      expect(world.currentBobber, isNull);
      expect(world.fishingLine.isActive, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Canvas Retraction & Empty Path Invariants
  // ---------------------------------------------------------------------------
  group('Canvas Retraction & Empty Path Stress Tests', () {
    test('Deactivated fishing line executes exactly 0 canvas draw calls', () {
      final spyCanvas = RecordingSpyCanvas();
      final line = FishingLineComponent(
        rodTipProvider: () => Vector2(167.67, 153.88),
        bobberPositionProvider: () => Vector2(360.0, 260.0),
        tensionProvider: () => 0.0,
        activeProvider: () => false, // inactive
      );

      // Render 50 frames while inactive
      for (int frame = 0; frame < 50; frame++) {
        line.render(spyCanvas);
      }

      expect(spyCanvas.drawCallCount, equals(0),
          reason: 'Deactivated line must generate exactly 0 draw calls');
      expect(spyCanvas.lastDrawnPath, isNull);
    });

    test('Null bobber provider executes exactly 0 canvas draw calls', () {
      final spyCanvas = RecordingSpyCanvas();
      final line = FishingLineComponent(
        rodTipProvider: () => Vector2(167.67, 153.88),
        bobberPositionProvider: () => null, // no bobber in world
        tensionProvider: () => 0.0,
        activeProvider: () => true,
      );

      line.render(spyCanvas);
      expect(spyCanvas.drawCallCount, equals(0));
    });

    test('Internal path resets to empty on deactivate()', () {
      final spyCanvas = RecordingSpyCanvas();
      bool active = true;

      final line = FishingLineComponent(
        rodTipProvider: () => Vector2(167.67, 153.88),
        bobberPositionProvider: () => Vector2(360.0, 260.0),
        tensionProvider: () => 0.5,
        activeProvider: () => active,
      );

      // 1. Render active frame
      line.render(spyCanvas);
      expect(spyCanvas.drawCallCount, equals(1));
      final capturedPath = spyCanvas.lastDrawnPath!;

      // Active path must have non-empty geometry
      expect(capturedPath.computeMetrics().isEmpty, isFalse,
          reason: 'Active line path must contain valid contour metrics');
      expect(capturedPath.getBounds().isEmpty, isFalse,
          reason: 'Active line path bounds must not be empty');

      // 2. Deactivate line
      active = false;
      line.deactivate();

      // Deactivation must have executed _linePath.reset() in-place on the captured reference
      expect(capturedPath.computeMetrics().isEmpty, isTrue,
          reason: 'Deactivated line path must be completely empty after reset');
      expect(capturedPath.getBounds().isEmpty, isTrue,
          reason: 'Deactivated line path bounds must be Rect.zero/empty');

      // 3. Render next frame
      line.render(spyCanvas);
      // Draw call count must NOT have incremented
      expect(spyCanvas.drawCallCount, equals(1),
          reason: 'No additional draw calls should be emitted while deactivated');
    });

    test('100 alternating activate/deactivate cycles preserve clean 0-draw invariant', () {
      final spyCanvas = RecordingSpyCanvas();
      final line = FishingLineComponent(
        rodTipProvider: () => Vector2(167.67, 153.88),
        bobberPositionProvider: () => Vector2(360.0, 260.0),
        tensionProvider: () => 0.0,
      );

      int expectedDraws = 0;
      for (int cycle = 0; cycle < 100; cycle++) {
        // Activate & render
        line.activate();
        line.render(spyCanvas);
        expectedDraws++;
        expect(spyCanvas.drawCallCount, equals(expectedDraws));

        // Deactivate & render
        line.deactivate();
        line.render(spyCanvas);
        // Draw call count must stay the same
        expect(spyCanvas.drawCallCount, equals(expectedDraws));
      }
    });

    test('World resetFishingState() guarantees 0 line draw calls on subsequent renders', () async {
      final world = MonsoonWorld();
      await world.onLoad();

      world.castTo(Vector2(350.0, 250.0));
      expect(world.fishingLine.isActive, isTrue);

      final activeCanvas = RecordingSpyCanvas();
      world.fishingLine.render(activeCanvas);
      expect(activeCanvas.drawCallCount, equals(1));

      // Reset
      world.resetFishingState();
      expect(world.fishingLine.isActive, isFalse);

      final resetCanvas = RecordingSpyCanvas();
      world.fishingLine.render(resetCanvas);
      expect(resetCanvas.drawCallCount, equals(0));
    });
  });
}
