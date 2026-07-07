import 'package:flutter_test/flutter_test.dart';
import 'package:monsoon_catch/components/rain.dart';
import 'package:monsoon_catch/logic/fishing_math.dart';

void main() {
  group('FishingMath Tests', () {
    late FishingMath math;

    setUp(() {
      math = FishingMath();
    });

    test('getWaitTime should return shorter times in heavy rain', () {
      final lightWait = math.getWaitTime(RainIntensity.light);
      final heavyWait = math.getWaitTime(RainIntensity.heavy);
      
      // Since it's random, we can't do a strict comparison without a seed,
      // but we can check the bounds.
      expect(lightWait, inInclusiveRange(3.0, 7.0));
      expect(heavyWait, inInclusiveRange(1.0, 3.0));
    });

    test('getBiteWindow should return narrower windows in heavy rain', () {
      final lightWindow = math.getBiteWindow(RainIntensity.light);
      final heavyWindow = math.getBiteWindow(RainIntensity.heavy);
      
      expect(lightWindow, inInclusiveRange(1.2, 1.7));
      expect(heavyWindow, inInclusiveRange(0.4, 0.7));
    });

    test('getNibbleCount should return between 1 and 3', () {
      final nibbles = math.getNibbleCount();
      expect(nibbles, inInclusiveRange(1, 3));
    });
  });
}
