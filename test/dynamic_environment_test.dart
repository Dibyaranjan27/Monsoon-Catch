import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monsoon_catch/components/environment/cloud_component.dart';
import 'package:monsoon_catch/components/environment/dynamic_environment.dart';
import 'package:monsoon_catch/components/environment/pine_forest_component.dart';
import 'package:monsoon_catch/components/environment/river_bank_component.dart';
import 'package:monsoon_catch/components/environment/sky_component.dart';
import 'package:monsoon_catch/components/environment/water_surface_component.dart';
import 'package:monsoon_catch/config/game_config.dart';
import 'package:monsoon_catch/models/weather_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DynamicEnvironment Headless Canvas Rendering Tests', () {
    late WeatherState weather;
    late Vector2 virtualSize;

    setUp(() {
      weather = WeatherState(initialType: WeatherType.clearDay);
      virtualSize = Vector2(GameConfig.virtualWidth, GameConfig.virtualHeight);
    });

    test('SkyComponent renders cleanly to Canvas via PictureRecorder across all weather presets', () {
      final sky = SkyComponent(size: virtualSize, weather: weather);

      for (final type in WeatherType.values) {
        weather.setWeather(type, instant: true);

        final recorder = PictureRecorder();
        final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, virtualSize.x, virtualSize.y));

        expect(() => sky.render(canvas), returnsNormally);

        final picture = recorder.endRecording();
        expect(picture, isNotNull);
        picture.dispose();
      }
    });

    test('SkyComponent renders with lightning flash without errors', () {
      weather.setWeather(WeatherType.monsoon, instant: true);
      final sky = SkyComponent(size: virtualSize, weather: weather);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, virtualSize.x, virtualSize.y));

      expect(() => sky.render(canvas), returnsNormally);
      final picture = recorder.endRecording();
      picture.dispose();
    });

    test('ProceduralCloud renders 2-tone multi-puff geometry headlessly', () {
      final cloud = ProceduralCloud(
        position: Vector2(100, 40),
        size: Vector2(120, 48),
        baseSpeed: 15.0,
        weather: weather,
      );

      for (final type in WeatherType.values) {
        weather.setWeather(type, instant: true);

        final recorder = PictureRecorder();
        final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, virtualSize.x, virtualSize.y));

        expect(() => cloud.render(canvas), returnsNormally);

        final picture = recorder.endRecording();
        picture.dispose();
      }
    });

    test('PineRidgeLayer and PineForestComponent render cached tree paths headlessly', () async {
      final forest = PineForestComponent(size: virtualSize, weather: weather);
      await forest.onLoad();

      expect(forest.children.length, equals(3));
      for (final child in forest.children) {
        expect(child, isA<PineRidgeLayer>());
      }

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, virtualSize.x, virtualSize.y));

      for (final child in forest.children) {
        expect(() => (child as PineRidgeLayer).render(canvas), returnsNormally);
      }

      final picture = recorder.endRecording();
      picture.dispose();
    });

    test('RiverBankComponent renders peat soil and turf cap headlessly', () {
      final bank = RiverBankComponent(size: virtualSize, weather: weather);

      for (final type in WeatherType.values) {
        weather.setWeather(type, instant: true);

        final recorder = PictureRecorder();
        final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, virtualSize.x, virtualSize.y));

        expect(() => bank.render(canvas), returnsNormally);

        final picture = recorder.endRecording();
        picture.dispose();
      }
    });

    test('WaterSurfaceComponent renders wave contour, depth gradient, and ripples headlessly', () {
      final water = WaterSurfaceComponent(size: virtualSize, weather: weather);

      // Advance water animation time and spawn ripples
      weather.setWeather(WeatherType.monsoon, instant: true);
      water.update(0.5);
      water.update(0.5);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, virtualSize.x, virtualSize.y));

      expect(() => water.render(canvas), returnsNormally);

      final picture = recorder.endRecording();
      picture.dispose();
    });

    test('DynamicEnvironment mounts all layers with strict z-order priority hierarchy', () async {
      final env = DynamicEnvironment(size: virtualSize, weather: weather);
      await env.onLoad();

      expect(env.children.length, equals(5));

      final sky = env.children.whereType<SkyComponent>().first;
      final clouds = env.children.whereType<CloudLayerComponent>().first;
      final forest = env.children.whereType<PineForestComponent>().first;
      final bank = env.children.whereType<RiverBankComponent>().first;
      final water = env.children.whereType<WaterSurfaceComponent>().first;

      // Strict z-ordering: sky < clouds < forest < riverBank < water
      expect(sky.priority, equals(GameConfig.prioritySky));
      expect(clouds.priority, equals(GameConfig.priorityClouds));
      expect(forest.priority, equals(GameConfig.priorityFarPines));
      expect(bank.priority, equals(GameConfig.priorityRiverBank));
      expect(water.priority, equals(GameConfig.priorityWaterSurface));

      expect(sky.priority < clouds.priority, isTrue);
      expect(clouds.priority < forest.priority, isTrue);
      expect(forest.priority < bank.priority, isTrue);
      expect(bank.priority < water.priority, isTrue);
    });

    test('DynamicEnvironment update ticks weather model smoothly', () {
      final env = DynamicEnvironment(size: virtualSize, weather: weather);
      weather.setWeather(WeatherType.monsoon, instant: false);

      expect(weather.rainIntensity, equals(0.0));
      env.update(0.2);
      expect(weather.rainIntensity, greaterThan(0.0));
    });

    test('Cloud wrap-around logic works when drifted past left edge', () {
      final cloud = ProceduralCloud(
        position: Vector2(10.0, 50.0),
        size: Vector2(100.0, 40.0),
        baseSpeed: 200.0,
        weather: weather,
      );

      // Large dt forces cloud far to the left past -20.0
      cloud.update(1.0);
      // Cloud must wrap around to parent width or default virtual width + 20
      expect(cloud.position.x, greaterThanOrEqualTo(GameConfig.virtualWidth));
    });
  });
}
