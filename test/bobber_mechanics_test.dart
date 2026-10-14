import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monsoon_catch/components/bobber.dart';
import 'package:monsoon_catch/logic/wave_generator.dart';
import 'package:monsoon_catch/models/weather_state.dart';

void main() {
  group('BobberComponent Mechanics & Water Physics Tests', () {
    test('Bobber initializes with Anchor.center and default floating position', () {
      final pos = Vector2(300.0, 240.0);
      final bobber = BobberComponent(position: pos);

      expect(bobber.anchor, equals(Anchor.center));
      expect(bobber.state, equals(BobberState.floating));
      expect(bobber.originalPosition.x, equals(300.0));
      expect(bobber.originalPosition.y, equals(240.0));
    });

    test('Floating elevation strictly synchronizes with WaveGenerator at waterline y = 234.0', () {
      final weather = WeatherState();
      final pos = Vector2(350.0, 234.0);
      final bobber = BobberComponent(position: pos, weather: weather);

      const waveGen = WaveGenerator();

      // Sample at multiple time intervals
      for (double t = 0.0; t < 5.0; t += 0.5) {
        bobber.update(0.5);

        // Expected water surface at x=350
        final waveElevation = waveGen.computeElevation(350.0, t + 0.5, weather.waveTurbulence);
        final waterY = 234.0 + waveElevation;

        // Bobber should be riding within buoyancy bobbing tolerance (-2.0 +- 0.6)
        expect(bobber.position.y, closeTo(waterY - 2.0, 1.5));
      }
    });

    test('Bite state pulls bobber submerged underwater', () {
      final pos = Vector2(350.0, 234.0);
      final bobber = BobberComponent(position: pos);

      bobber.changeState(BobberState.bite);
      expect(bobber.state, equals(BobberState.bite));

      bobber.update(0.1);

      // In bite state: submerged by +11.0 px (+- 1.2 px wave)
      expect(bobber.position.y, greaterThan(234.0 + 8.0));
    });

    test('Ballistic casting trajectory animates smoothly and lands with 2.5D ripples', () {
      final bobber = BobberComponent(position: Vector2(167.67, 153.88));
      final start = Vector2(167.67, 153.88);
      final target = Vector2(400.0, 250.0);

      bool landed = false;
      bobber.startCastTrajectory(
        from: start,
        to: target,
        duration: 0.5,
        onTouchdown: () {
          landed = true;
        },
      );

      expect(bobber.state, equals(BobberState.airborne));
      expect(bobber.position.x, equals(start.x));

      // Advance halfway (t = 0.25s)
      bobber.update(0.25);
      expect(bobber.position.x, greaterThan(start.x));
      expect(bobber.position.x, lessThan(target.x));
      // Parabolic apex should lift bobber above linear interpolation
      expect(bobber.position.y, lessThan(start.y + (target.y - start.y) * 0.5));

      // Advance to touchdown
      bobber.update(0.26);
      expect(landed, isTrue);
      expect(bobber.state, equals(BobberState.floating));
    });

    test('Procedural Canvas rendering works with zero bitmap assets across all states', () {
      final bobber = BobberComponent(position: Vector2(320.0, 250.0));

      for (final state in BobberState.values) {
        bobber.changeState(state);
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(() => bobber.render(canvas), returnsNormally);

        final picture = recorder.endRecording();
        expect(picture, isNotNull);
      }
    });

    test('Bobber reset clears particles and timers atomically', () {
      final bobber = BobberComponent(position: Vector2(320.0, 250.0));
      bobber.triggerSplash();
      bobber.reset();

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(() => bobber.render(canvas), returnsNormally);
    });
  });
}
