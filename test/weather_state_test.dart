import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monsoon_catch/models/weather_state.dart';

void main() {
  group('WeatherState & SkyPalette Tests', () {
    late WeatherState weather;

    setUp(() {
      weather = WeatherState(initialType: WeatherType.clearDay);
    });

    test('Initial parameters default correctly for Clear Day', () {
      expect(weather.currentType, equals(WeatherType.clearDay));
      expect(weather.rainIntensity, equals(0.0));
      expect(weather.windSpeed, equals(0.25));
      expect(weather.skyDarkness, equals(0.0));
      expect(weather.cloudDensity, equals(0.30));
      expect(weather.waveTurbulence, closeTo(0.475, 0.001));
      expect(weather.lightningFlash, equals(0.0));
    });

    test('Instant weather transition updates parameters immediately', () {
      weather.setWeather(WeatherType.monsoon, instant: true);
      expect(weather.currentType, equals(WeatherType.monsoon));
      expect(weather.rainIntensity, equals(0.90));
      expect(weather.windSpeed, equals(0.85));
      expect(weather.skyDarkness, equals(0.85));
      expect(weather.cloudDensity, equals(1.0));
      expect(weather.waveTurbulence, closeTo(2.44, 0.001));

      weather.setWeather(WeatherType.overcast, instant: true);
      expect(weather.currentType, equals(WeatherType.overcast));
      expect(weather.rainIntensity, equals(0.15));
      expect(weather.windSpeed, equals(0.45));
      expect(weather.skyDarkness, equals(0.45));
      expect(weather.cloudDensity, equals(0.85));

      weather.setWeather(WeatherType.clearDawn, instant: true);
      expect(weather.currentType, equals(WeatherType.clearDawn));
      expect(weather.rainIntensity, equals(0.0));
      expect(weather.windSpeed, equals(0.15));
      expect(weather.skyDarkness, equals(0.15));
      expect(weather.cloudDensity, equals(0.20));
    });

    test('Gradual weather transition interpolates smoothly over time', () {
      weather.setWeather(WeatherType.monsoon, instant: false);

      // Initially still near clear day values
      expect(weather.rainIntensity, equals(0.0));

      // Advance by 0.5s
      weather.update(0.5);
      expect(weather.rainIntensity, greaterThan(0.0));
      expect(weather.rainIntensity, lessThan(0.90));
      expect(weather.windSpeed, greaterThan(0.25));

      // Advance over 3.0 seconds total to reach target
      for (int i = 0; i < 30; i++) {
        weather.update(0.1);
      }
      expect(weather.rainIntensity, closeTo(0.90, 0.05));
      expect(weather.windSpeed, closeTo(0.85, 0.05));
    });

    test('Wave turbulence formula strictly matches specification', () {
      // waveTurbulence = 0.35 + (1.85 * rainIntensity) + (0.50 * windSpeed)
      weather.setWeather(WeatherType.clearDay, instant: true);
      final expectedClearTurb = 0.35 + (1.85 * 0.0) + (0.50 * 0.25);
      expect(weather.waveTurbulence, equals(expectedClearTurb));

      weather.setWeather(WeatherType.monsoon, instant: true);
      final expectedMonsoonTurb = 0.35 + (1.85 * 0.90) + (0.50 * 0.85);
      expect(weather.waveTurbulence, closeTo(expectedMonsoonTurb, 0.001));
    });

    test('SkyPalette color lerp behaves continuously across stops', () {
      final a = SkyPalette.clearDay;
      final b = SkyPalette.monsoon;

      final lerp0 = SkyPalette.lerp(a, b, 0.0);
      expect(lerp0.zenith, equals(a.zenith));
      expect(lerp0.horizon, equals(a.horizon));

      final lerp1 = SkyPalette.lerp(a, b, 1.0);
      expect(lerp1.zenith, equals(b.zenith));
      expect(lerp1.horizon, equals(b.horizon));

      final lerpMid = SkyPalette.lerp(a, b, 0.5);
      expect(lerpMid.zenith, equals(Color.lerp(a.zenith, b.zenith, 0.5)));
      expect(lerpMid.mid, equals(Color.lerp(a.mid, b.mid, 0.5)));
      expect(lerpMid.low, equals(Color.lerp(a.low, b.low, 0.5)));
      expect(lerpMid.horizon, equals(Color.lerp(a.horizon, b.horizon, 0.5)));
    });

    test('ChangeNotifier notifies listeners on weather switch', () {
      int notifyCount = 0;
      weather.addListener(() {
        notifyCount++;
      });

      weather.setWeather(WeatherType.overcast);
      expect(notifyCount, equals(1));

      weather.setWeather(WeatherType.monsoon);
      expect(notifyCount, equals(2));

      // Setting same weather does not fire redundant notification
      weather.setWeather(WeatherType.monsoon);
      expect(notifyCount, equals(2));
    });
  });
}
