import 'package:flutter_test/flutter_test.dart';
import 'package:monsoon_catch/logic/wave_generator.dart';

void main() {
  group('WaveGenerator Tests', () {
    const wave = WaveGenerator(baseElevation: 234.0);

    test('Wave calculation is deterministic', () {
      final y1 = wave.computeElevation(120.0, 5.5, 1.2);
      final y2 = wave.computeElevation(120.0, 5.5, 1.2);
      expect(y1, equals(y2));

      final y3 = wave.computeElevation(350.25, 12.8, 2.45);
      final y4 = wave.computeElevation(350.25, 12.8, 2.45);
      expect(y3, equals(y4));
    });

    test('Wave calculation is zero-amplitude at zero turbulence', () {
      for (double x = 0; x <= 640; x += 32) {
        for (double t = 0; t <= 10; t += 2) {
          final y = wave.computeElevation(x, t, 0.0);
          expect(y, equals(wave.baseElevation));
        }
      }
    });

    test('Peak displacement is strictly bounded by theoreticalMaxAmplitude * turbulence', () {
      final turbulences = [0.45, 1.0, 1.85, 2.5];

      for (final turb in turbulences) {
        final maxAllowedDisplacement = WaveGenerator.theoreticalMaxAmplitude * turb + 1e-6;

        for (double x = 0; x <= 640; x += 10) {
          for (double t = 0; t <= 6.28; t += 0.5) {
            final y = wave.computeElevation(x, t, turb);
            final displacement = (y - wave.baseElevation).abs();
            expect(displacement, lessThanOrEqualTo(maxAllowedDisplacement));
          }
        }
      }
    });

    test('Wave output scales linearly with turbulence', () {
      const x = 145.0;
      const t = 3.2;

      final disp1 = wave.computeElevation(x, t, 1.0) - wave.baseElevation;
      final disp2 = wave.computeElevation(x, t, 2.0) - wave.baseElevation;

      expect(disp2, closeTo(disp1 * 2.0, 0.0001));
    });

    test('Guarantees non-NaN and finite values under extreme and invalid inputs', () {
      // Normal range
      for (double x = -1000; x <= 1000; x += 250) {
        final y = wave.computeElevation(x, 10.0, 1.5);
        expect(y.isFinite, isTrue);
        expect(y.isNaN, isFalse);
      }

      // NaN inputs
      expect(wave.computeElevation(double.nan, 1.0, 1.0), equals(wave.baseElevation));
      expect(wave.computeElevation(10.0, double.nan, 1.0), equals(wave.baseElevation));
      expect(wave.computeElevation(10.0, 1.0, double.nan), equals(wave.baseElevation));

      // Infinite inputs
      expect(wave.computeElevation(double.infinity, 1.0, 1.0), equals(wave.baseElevation));
      expect(wave.computeElevation(10.0, double.negativeInfinity, 1.0), equals(wave.baseElevation));
      expect(wave.computeElevation(10.0, 1.0, double.infinity), equals(wave.baseElevation));

      // Negative turbulence gracefully clamps
      final yNegativeTurb = wave.computeElevation(100.0, 2.0, -5.0);
      expect(yNegativeTurb, equals(wave.baseElevation));
    });

    test('Wave elevation demonstrates mathematical continuity', () {
      const t = 4.0;
      const turb = 1.5;
      const dx = 0.0001;

      for (double x = 50.0; x <= 300.0; x += 25.0) {
        final y1 = wave.computeElevation(x, t, turb);
        final y2 = wave.computeElevation(x + dx, t, turb);
        expect((y2 - y1).abs(), lessThan(0.005));
      }
    });
  });
}
