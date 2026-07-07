import 'dart:math';
import '../components/rain.dart';

class FishingMath {
  final Random _rnd;

  // Allow passing a seeded random for deterministic testing
  FishingMath({Random? random}) : _rnd = random ?? Random();

  /// Returns the duration in seconds until a fish nibbles or bites.
  /// Light rain = longer wait, Heavy rain = shorter wait.
  double getWaitTime(RainIntensity intensity) {
    switch (intensity) {
      case RainIntensity.light:
        return 3.0 + _rnd.nextDouble() * 4.0; // 3 to 7 seconds
      case RainIntensity.medium:
        return 2.0 + _rnd.nextDouble() * 3.0; // 2 to 5 seconds
      case RainIntensity.heavy:
        return 1.0 + _rnd.nextDouble() * 2.0; // 1 to 3 seconds
    }
  }

  /// Returns the duration in seconds the 'Bite' window remains open.
  /// Light rain = wider window, Heavy rain = narrower window.
  double getBiteWindow(RainIntensity intensity) {
    switch (intensity) {
      case RainIntensity.light:
        return 1.2 + _rnd.nextDouble() * 0.5; // 1.2 to 1.7 seconds
      case RainIntensity.medium:
        return 0.8 + _rnd.nextDouble() * 0.4; // 0.8 to 1.2 seconds
      case RainIntensity.heavy:
        return 0.4 + _rnd.nextDouble() * 0.3; // 0.4 to 0.7 seconds
    }
  }

  /// Returns the number of 'Nibbles' before the actual 'Bite' occurs.
  int getNibbleCount() {
    return 1 + _rnd.nextInt(3); // 1, 2, or 3 nibbles
  }
}
