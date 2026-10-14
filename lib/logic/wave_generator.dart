import 'dart:math';

/// Mathematical wave generator synthesizing multi-harmonic sinusoidal waves
/// for animated procedural water surfaces.
class WaveGenerator {
  final double baseElevation;

  // Wave harmonic constants
  static const double lambda1 = 90.0;
  static const double lambda2 = 35.0;
  static const double lambda3 = 14.0;

  static const double omega1 = 1.8;
  static const double omega2 = 3.6;
  static const double omega3 = 6.5;

  static const double phi1 = 0.0;
  static const double phi2 = 1.2;
  static const double phi3 = 2.5;

  static const double amp1 = 2.5;
  static const double amp2 = 1.2;
  static const double amp3 = 0.5;

  const WaveGenerator({this.baseElevation = 0.0});

  /// Maximum possible crest displacement from [baseElevation] per unit turbulence
  static const double theoreticalMaxAmplitude = amp1 + amp2 + amp3; // 4.2

  /// Computes wave elevation at horizontal position [x] and time [t]
  /// modulated by [turbulence].
  ///
  /// Guarantees:
  /// - Determinism
  /// - Always returns a finite [double] (never NaN or infinite)
  /// - Peak displacement bounded by `theoreticalMaxAmplitude * turbulence`
  double computeElevation(double x, double t, double turbulence) {
    if (!x.isFinite || !t.isFinite || !turbulence.isFinite) {
      return baseElevation;
    }

    final safeTurb = turbulence < 0.0 ? 0.0 : turbulence;

    final w1 = amp1 * safeTurb * sin((2 * pi / lambda1) * x - omega1 * t + phi1);
    final w2 = amp2 * safeTurb * sin((2 * pi / lambda2) * x - omega2 * t + phi2);
    final w3 = amp3 * safeTurb * sin((2 * pi / lambda3) * x - omega3 * t + phi3);

    final displacement = w1 + w2 + w3;
    if (!displacement.isFinite) {
      return baseElevation;
    }

    return baseElevation + displacement;
  }
}
