import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monsoon_catch/components/fishing_line.dart';

void main() {
  group('FishingLineMath & Catenary Physics Tests', () {
    const p1 = Offset(167.67, 153.88); // rod tip
    const p2 = Offset(360.0, 260.0); // bobber in pond

    test('Endpoints strictly match rod tip (p1) and bobber (p2)', () {
      final controlPoints = FishingLineMath.computeControlPoints(
        p1: p1,
        p2: p2,
        tension: 0.0,
      );

      final start = FishingLineMath.evaluateCubicBezier(
        p1: p1,
        c1: controlPoints.c1,
        c2: controlPoints.c2,
        p2: p2,
        t: 0.0,
      );
      expect(start.dx, closeTo(p1.dx, 1e-4));
      expect(start.dy, closeTo(p1.dy, 1e-4));

      final end = FishingLineMath.evaluateCubicBezier(
        p1: p1,
        c1: controlPoints.c1,
        c2: controlPoints.c2,
        p2: p2,
        t: 1.0,
      );
      expect(end.dx, closeTo(p2.dx, 1e-4));
      expect(end.dy, closeTo(p2.dy, 1e-4));
    });

    test('Sag depth formula strictly obeys S_y(tau, L) = clamp(L * 0.14, 4.0, 38.0) * (1 - tau)^2', () {
      final dx = p2.dx - p1.dx;
      final dy = p2.dy - p1.dy;
      final span = sqrt(dx * dx + dy * dy);
      final maxExpectedSag = (span * 0.14).clamp(4.0, 38.0);

      // 1. Slack tension (tau = 0.0) -> full sag
      final slackCP = FishingLineMath.computeControlPoints(
        p1: p1,
        p2: p2,
        tension: 0.0,
      );
      final chordMidY = (p1.dy + p2.dy) / 2.0;
      final slackMid = FishingLineMath.evaluateCubicBezier(
        p1: p1,
        c1: slackCP.c1,
        c2: slackCP.c2,
        p2: p2,
        t: 0.5,
      );
      final actualSag = slackMid.dy - chordMidY;
      expect(actualSag, closeTo(maxExpectedSag, 1e-2));

      // 2. Taut tension (tau = 1.0) -> zero sag
      final tautCP = FishingLineMath.computeControlPoints(
        p1: p1,
        p2: p2,
        tension: 1.0,
      );
      final tautMid = FishingLineMath.evaluateCubicBezier(
        p1: p1,
        c1: tautCP.c1,
        c2: tautCP.c2,
        p2: p2,
        t: 0.5,
      );
      expect(tautMid.dy, closeTo(chordMidY, 1.5)); // within micro-vibration tolerance

      // 3. Monotonic decrease of sag with tension
      double previousSag = double.infinity;
      for (int i = 0; i <= 10; i++) {
        final tau = i / 10.0;
        final cp = FishingLineMath.computeControlPoints(
          p1: p1,
          p2: p2,
          tension: tau,
        );
        final mid = FishingLineMath.evaluateCubicBezier(
          p1: p1,
          c1: cp.c1,
          c2: cp.c2,
          p2: p2,
          t: 0.5,
        );
        final currentSag = mid.dy - chordMidY;
        expect(currentSag, lessThanOrEqualTo(previousSag + 1e-4));
        previousSag = currentSag;
      }
    });

    test('Clamping bounds hold for short spans (min 4.0) and huge spans (max 38.0)', () {
      // Short span: 10 px
      const shortP2 = Offset(177.67, 153.88);
      final shortCP = FishingLineMath.computeControlPoints(
        p1: p1,
        p2: shortP2,
        tension: 0.0,
      );
      final shortMid = FishingLineMath.evaluateCubicBezier(
        p1: p1,
        c1: shortCP.c1,
        c2: shortCP.c2,
        p2: shortP2,
        t: 0.5,
      );
      expect(shortMid.dy - (p1.dy + shortP2.dy) / 2.0, closeTo(4.0, 1e-2));

      // Huge span: 1000 px
      const hugeP2 = Offset(1167.67, 153.88);
      final hugeCP = FishingLineMath.computeControlPoints(
        p1: p1,
        p2: hugeP2,
        tension: 0.0,
      );
      final hugeMid = FishingLineMath.evaluateCubicBezier(
        p1: p1,
        c1: hugeCP.c1,
        c2: hugeCP.c2,
        p2: hugeP2,
        t: 0.5,
      );
      expect(hugeMid.dy - (p1.dy + hugeP2.dy) / 2.0, closeTo(38.0, 1e-2));
    });

    test('Wind drift deflects slack line and collapses under full tension', () {
      // Positive crosswind with slack line
      final windSlackCP = FishingLineMath.computeControlPoints(
        p1: p1,
        p2: p2,
        tension: 0.0,
        windFactor: 1.0,
      );
      final chordMidX = (p1.dx + p2.dx) / 2.0;
      final windMid = FishingLineMath.evaluateCubicBezier(
        p1: p1,
        c1: windSlackCP.c1,
        c2: windSlackCP.c2,
        p2: p2,
        t: 0.5,
      );
      expect(windMid.dx - chordMidX, closeTo(8.0, 1e-2));

      // Positive crosswind with taut line (tension = 1.0)
      final windTautCP = FishingLineMath.computeControlPoints(
        p1: p1,
        p2: p2,
        tension: 1.0,
        windFactor: 1.0,
      );
      final tautWindMid = FishingLineMath.evaluateCubicBezier(
        p1: p1,
        c1: windTautCP.c1,
        c2: windTautCP.c2,
        p2: p2,
        t: 0.5,
      );
      expect(tautWindMid.dx - chordMidX, closeTo(0.0, 1.5)); // within vibration
    });

    test('High-tension micro-vibration activates strictly above tension 0.75', () {
      // At tension 0.5: no vibration
      final cpHalf1 = FishingLineMath.computeControlPoints(
        p1: p1,
        p2: p2,
        tension: 0.5,
        time: 0.0,
      );
      final cpHalf2 = FishingLineMath.computeControlPoints(
        p1: p1,
        p2: p2,
        tension: 0.5,
        time: 0.25,
      );
      expect(cpHalf1.c1.dx, equals(cpHalf2.c1.dx));
      expect(cpHalf1.c1.dy, equals(cpHalf2.c1.dy));

      // At tension 1.0: active vibration varying with time
      final cpTaut1 = FishingLineMath.computeControlPoints(
        p1: p1,
        p2: p2,
        tension: 1.0,
        time: 0.0,
      );
      final cpTaut2 = FishingLineMath.computeControlPoints(
        p1: p1,
        p2: p2,
        tension: 1.0,
        time: (pi / 2.0) / 32.0, // quarter-period of 32 rad/s
      );
      final diff = (cpTaut2.c1 - cpTaut1.c1).distance;
      expect(diff, greaterThan(0.5));
      expect(diff, lessThanOrEqualTo(1.5));
    });

    test('Pathological inputs (zero span, NaN, infinity) handle safely without crashes', () {
      // Identical points (zero span)
      final zeroCP = FishingLineMath.computeControlPoints(
        p1: p1,
        p2: p1,
        tension: 0.5,
      );
      expect(zeroCP.c1, equals(p1));
      expect(zeroCP.c2, equals(p1));

      // NaN inputs
      expect(
        () => FishingLineMath.computeControlPoints(
          p1: const Offset(double.nan, double.nan),
          p2: p2,
          tension: double.nan,
          windFactor: double.nan,
        ),
        returnsNormally,
      );

      // Infinity inputs
      expect(
        () => FishingLineMath.computeControlPoints(
          p1: const Offset(double.infinity, double.negativeInfinity),
          p2: p2,
          tension: double.infinity,
        ),
        returnsNormally,
      );
    });

    test('FishingLineComponent renders when active and is no-op when inactive', () {
      bool active = true;
      final line = FishingLineComponent(
        rodTipProvider: () => Vector2(167.67, 153.88),
        bobberPositionProvider: () => Vector2(360.0, 260.0),
        tensionProvider: () => 0.0,
        activeProvider: () => active,
      );

      // Active render
      final recActive = PictureRecorder();
      final canvasActive = Canvas(recActive);
      expect(() => line.render(canvasActive), returnsNormally);
      final picActive = recActive.endRecording();
      expect(picActive, isNotNull);

      // Deactivated render
      active = false;
      final recInactive = PictureRecorder();
      final canvasInactive = Canvas(recInactive);
      expect(() => line.render(canvasInactive), returnsNormally);
      final picInactive = recInactive.endRecording();
      expect(picInactive, isNotNull);
    });
  });
}
