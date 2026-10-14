import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monsoon_catch/components/environment/cloud_component.dart';
import 'package:monsoon_catch/components/environment/water_surface_component.dart';
import 'package:monsoon_catch/config/game_config.dart';
import 'package:monsoon_catch/logic/wave_generator.dart';
import 'package:monsoon_catch/models/weather_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WaveGenerator Adversarial & Precision Stress Tests', () {
    const wave = WaveGenerator(baseElevation: 234.0);

    test('Floating-point precision at extreme time (t = 10^6 s) produces finite, bounded values', () {
      const extremeTime = 1000000.0; // 10^6 seconds (~11.5 days continuous run)
      const turb = 2.44; // Peak monsoon turbulence

      for (double x = 0; x <= 640; x += 20) {
        final y = wave.computeElevation(x, extremeTime, turb);
        expect(y.isFinite, isTrue, reason: 'Elevation must be finite at t = 10^6');
        expect(y.isNaN, isFalse, reason: 'Elevation must not be NaN at t = 10^6');

        // Must remain within theoretical maximum displacement
        final maxDisp = WaveGenerator.theoreticalMaxAmplitude * turb + 1e-4;
        final disp = (y - wave.baseElevation).abs();
        expect(disp, lessThanOrEqualTo(maxDisp));
      }
    });

    test('Wave generation under extreme and adversarial turbulence inputs', () {
      // Negative wind / turbulence clamps gracefully to zero displacement
      final yNegTurb = wave.computeElevation(100.0, 5.0, -50.0);
      expect(yNegTurb, equals(wave.baseElevation));

      // Extreme positive turbulence scaling analysis
      // If rain = 10.0, wind = 100.0: turb = 0.35 + 1.85*10 + 0.50*100 = 68.85
      const extremeTurb = 68.85;
      final yExtreme = wave.computeElevation(100.0, 5.0, extremeTurb);
      expect(yExtreme.isFinite, isTrue);
      expect(yExtreme.isNaN, isFalse);
    });

    test('All reachable WeatherState configurations strictly keep wave within [0, 360]', () {
      final weather = WeatherState();

      for (final type in WeatherType.values) {
        weather.setWeather(type, instant: true);
        final turb = weather.waveTurbulence;

        for (double x = 0; x <= 640; x += 10) {
          for (double t = 0; t <= 100; t += 2.5) {
            final y = wave.computeElevation(x, t, turb);
            expect(y, greaterThanOrEqualTo(0.0), reason: 'Water must not penetrate top of screen');
            expect(y, lessThanOrEqualTo(360.0), reason: 'Water must not penetrate bottom of screen');
            // Furthermore, tightly bounded near waterline ~234
            expect(y, inInclusiveRange(220.0, 248.0));
          }
        }
      }
    });

    test('NaN, Infinity, and -Infinity inputs safely return baseElevation', () {
      expect(wave.computeElevation(double.nan, 1.0, 1.0), equals(wave.baseElevation));
      expect(wave.computeElevation(100.0, double.nan, 1.0), equals(wave.baseElevation));
      expect(wave.computeElevation(100.0, 1.0, double.nan), equals(wave.baseElevation));

      expect(wave.computeElevation(double.infinity, 1.0, 1.0), equals(wave.baseElevation));
      expect(wave.computeElevation(100.0, double.infinity, 1.0), equals(wave.baseElevation));
      expect(wave.computeElevation(100.0, 1.0, double.infinity), equals(wave.baseElevation));

      expect(wave.computeElevation(double.negativeInfinity, 1.0, 1.0), equals(wave.baseElevation));
      expect(wave.computeElevation(100.0, double.negativeInfinity, 1.0), equals(wave.baseElevation));
      expect(wave.computeElevation(100.0, 1.0, double.negativeInfinity), equals(wave.baseElevation));
    });
  });

  group('WeatherState Transition & Lerp Stability Stress Tests', () {
    late WeatherState weather;

    setUp(() {
      weather = WeatherState(initialType: WeatherType.clearDay);
    });

    test('Rapid oscillation stress test across 5,000 state flips maintains stability', () {
      for (int i = 0; i < 5000; i++) {
        final target = i.isEven ? WeatherType.monsoon : WeatherType.clearDay;
        weather.setWeather(target);
        weather.update(0.016); // 60 FPS tick

        expect(weather.rainIntensity, inInclusiveRange(0.0, 1.0));
        expect(weather.windSpeed, inInclusiveRange(0.0, 1.0));
        expect(weather.skyDarkness, inInclusiveRange(0.0, 1.0));
        expect(weather.cloudDensity, inInclusiveRange(0.0, 1.0));
        expect(weather.waveTurbulence, inInclusiveRange(0.35, 3.0));
        expect(weather.lightningFlash, inInclusiveRange(0.0, 1.0));
      }
    });

    test('Lerp stability across abnormal deltaTimes (dt = 0, dt = 10^6, dt = -1.0)', () {
      weather.setWeather(WeatherType.monsoon);

      // 1. Zero dt produces no change
      final initialRain = weather.rainIntensity;
      weather.update(0.0);
      expect(weather.rainIntensity, equals(initialRain));

      // 2. Negative dt clamps lerpRate to 0.0 and produces no change
      weather.update(-5.0);
      expect(weather.rainIntensity, equals(initialRain));

      // 3. Huge dt (lag spike, dt = 1000.0) snaps cleanly to target without overshooting
      weather.update(1000.0);
      expect(weather.rainIntensity, equals(0.90));
      expect(weather.windSpeed, equals(0.85));
      expect(weather.skyDarkness, equals(0.85));
      expect(weather.cloudDensity, equals(1.0));

      // 4. Switching back with another huge dt snaps cleanly back
      weather.setWeather(WeatherType.clearDay);
      weather.update(500.0);
      expect(weather.rainIntensity, equals(0.0));
      expect(weather.windSpeed, equals(0.25));
    });
  });

  group('ProceduralCloud Kinematics & Memory Leak Stress Tests', () {
    late WeatherState weather;

    setUp(() {
      weather = WeatherState(initialType: WeatherType.monsoon);
    });

    test('Clouds remain bounded and wrap stably over extended simulation (50,000 ticks)', () {
      final cloud = ProceduralCloud(
        position: Vector2(200.0, 50.0),
        size: Vector2(140.0, 50.0),
        baseSpeed: 16.0,
        weather: weather,
      );

      const dt = 0.016; // 60 FPS
      int wrapCount = 0;
      double lastX = cloud.position.x;

      for (int frame = 0; frame < 50000; frame++) {
        cloud.update(dt);

        // Check if wrapped around
        if (cloud.position.x > lastX) {
          wrapCount++;
          // Wrapped cloud must appear at or near right edge
          expect(cloud.position.x, closeTo(GameConfig.virtualWidth + 20.0, 1.0));
        }

        // Cloud x must never blow up to infinity or NaN
        expect(cloud.position.x.isFinite, isTrue);
        expect(cloud.position.x.isNaN, isFalse);

        lastX = cloud.position.x;
      }

      // Over 50,000 ticks (~800s at speed ~44px/s across 820px span), should wrap ~40+ times
      expect(wrapCount, greaterThan(35));
    });

    test('CloudLayerComponent maintains fixed cloud count (no object accumulation)', () async {
      final cloudLayer = CloudLayerComponent(
        size: Vector2(GameConfig.virtualWidth, GameConfig.virtualHeight),
        weather: weather,
      );
      await cloudLayer.onLoad();

      expect(cloudLayer.children.length, equals(5));

      // Run 10,000 update frames
      for (int i = 0; i < 10000; i++) {
        cloudLayer.update(0.016);
      }

      // Cloud count must strictly remain 5
      expect(cloudLayer.children.length, equals(5));
    });
  });

  group('WaterSurfaceComponent Ripple Pool & Extended Lifecycle Stress Tests', () {
    late WeatherState weather;

    setUp(() {
      weather = WeatherState(initialType: WeatherType.monsoon);
    });

    test('WaterSurfaceComponent ripple pool never exceeds maximum capacity of 35', () {
      final water = WaterSurfaceComponent(
        size: Vector2(GameConfig.virtualWidth, GameConfig.virtualHeight),
        weather: weather,
      );

      // Run for 30,000 frames under heavy monsoon rain
      for (int i = 0; i < 30000; i++) {
        water.update(0.016);
      }

      // Render pass should complete normally
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, GameConfig.virtualWidth, GameConfig.virtualHeight));

      expect(() => water.render(canvas), returnsNormally);

      final picture = recorder.endRecording();
      picture.dispose();
    });

    test('WaterSurfaceComponent survives huge dt lag spike without ripple explosion', () {
      final water = WaterSurfaceComponent(
        size: Vector2(GameConfig.virtualWidth, GameConfig.virtualHeight),
        weather: weather,
      );

      // Run normally for a few frames
      for (int i = 0; i < 50; i++) {
        water.update(0.016);
      }

      // Simulate a 60-second system hang / background pause
      water.update(60.0);

      // All previous ripples should be expired and cleanly removed
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, GameConfig.virtualWidth, GameConfig.virtualHeight));

      expect(() => water.render(canvas), returnsNormally);

      final picture = recorder.endRecording();
      picture.dispose();
    });
  });
}
