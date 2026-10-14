import 'dart:math';
import 'package:flutter/material.dart';

/// Available weather conditions in Monsoon Catch
enum WeatherType {
  clearDawn('Clear Dawn'),
  clearDay('Clear Day'),
  overcast('Overcast'),
  monsoon('Monsoon Storm');

  final String displayName;
  const WeatherType(this.displayName);
}

/// 4-stop vertical linear gradient sky palette
class SkyPalette {
  final Color zenith; // 0.00 stop (top of sky)
  final Color mid; // 0.45 stop (upper-mid sky)
  final Color low; // 0.80 stop (lower sky)
  final Color horizon; // 1.00 stop (ridge / horizon line)

  const SkyPalette({
    required this.zenith,
    required this.mid,
    required this.low,
    required this.horizon,
  });

  static const SkyPalette clearDawn = SkyPalette(
    zenith: Color(0xFF1E2243),
    mid: Color(0xFFD3685C),
    low: Color(0xFFEAA254),
    horizon: Color(0xFFF9D199),
  );

  static const SkyPalette clearDay = SkyPalette(
    zenith: Color(0xFF3B82C4),
    mid: Color(0xFF67B0E8),
    low: Color(0xFF93C5FD),
    horizon: Color(0xFFBAE6FD),
  );

  static const SkyPalette overcast = SkyPalette(
    zenith: Color(0xFF475569),
    mid: Color(0xFF64748B),
    low: Color(0xFF94A3B8),
    horizon: Color(0xFFCBD5E1),
  );

  static const SkyPalette monsoon = SkyPalette(
    zenith: Color(0xFF0F172A),
    mid: Color(0xFF1E293B),
    low: Color(0xFF334155),
    horizon: Color(0xFF233043),
  );

  static SkyPalette forWeather(WeatherType type) {
    switch (type) {
      case WeatherType.clearDawn:
        return clearDawn;
      case WeatherType.clearDay:
        return clearDay;
      case WeatherType.overcast:
        return overcast;
      case WeatherType.monsoon:
        return monsoon;
    }
  }

  static SkyPalette lerp(SkyPalette a, SkyPalette b, double t) {
    final clamped = t.clamp(0.0, 1.0);
    return SkyPalette(
      zenith: Color.lerp(a.zenith, b.zenith, clamped) ?? a.zenith,
      mid: Color.lerp(a.mid, b.mid, clamped) ?? a.mid,
      low: Color.lerp(a.low, b.low, clamped) ?? a.low,
      horizon: Color.lerp(a.horizon, b.horizon, clamped) ?? a.horizon,
    );
  }
}

/// Reactive weather state controlling environmental parameters
class WeatherState extends ChangeNotifier {
  WeatherType _currentType;

  // Active interpolated parameters
  double _rainIntensity = 0.0; // 0.0 (dry) to 1.0 (heavy monsoon)
  double _windSpeed = 0.25; // 0.0 (calm) to 1.0 (gale)
  double _skyDarkness = 0.0; // 0.0 (bright) to 1.0 (deep storm)
  double _cloudDensity = 0.30; // 0.0 (clear) to 1.0 (dense storm cover)
  double _lightningFlash = 0.0; // 0.0 to 1.0 (storm flash)

  // Target values based on current type
  double _targetRainIntensity = 0.0;
  double _targetWindSpeed = 0.25;
  double _targetSkyDarkness = 0.0;
  double _targetCloudDensity = 0.30;

  // Palette interpolation
  SkyPalette _currentPalette;

  // Lightning timer for monsoon
  double _lightningCooldown = 4.0;
  final Random _rnd = Random(42);

  WeatherState({WeatherType initialType = WeatherType.clearDay})
      : _currentType = initialType,
        _currentPalette = SkyPalette.forWeather(initialType) {
    _applyPresetTargets(initialType);
    _snapToTargets();
  }

  WeatherType get currentType => _currentType;
  double get rainIntensity => _rainIntensity;
  double get windSpeed => _windSpeed;
  double get skyDarkness => _skyDarkness;
  double get cloudDensity => _cloudDensity;
  double get lightningFlash => _lightningFlash;
  SkyPalette get currentPalette => _currentPalette;

  /// Multi-harmonic wave turbulence factor
  double get waveTurbulence =>
      0.35 + (1.85 * _rainIntensity) + (0.50 * _windSpeed);

  void _applyPresetTargets(WeatherType type) {
    switch (type) {
      case WeatherType.clearDay:
        _targetRainIntensity = 0.0;
        _targetWindSpeed = 0.25;
        _targetSkyDarkness = 0.0;
        _targetCloudDensity = 0.30;
        break;
      case WeatherType.clearDawn:
        _targetRainIntensity = 0.0;
        _targetWindSpeed = 0.15;
        _targetSkyDarkness = 0.15;
        _targetCloudDensity = 0.20;
        break;
      case WeatherType.overcast:
        _targetRainIntensity = 0.15;
        _targetWindSpeed = 0.45;
        _targetSkyDarkness = 0.45;
        _targetCloudDensity = 0.85;
        break;
      case WeatherType.monsoon:
        _targetRainIntensity = 0.90;
        _targetWindSpeed = 0.85;
        _targetSkyDarkness = 0.85;
        _targetCloudDensity = 1.0;
        break;
    }
  }

  void _snapToTargets() {
    _rainIntensity = _targetRainIntensity;
    _windSpeed = _targetWindSpeed;
    _skyDarkness = _targetSkyDarkness;
    _cloudDensity = _targetCloudDensity;
    _currentPalette = SkyPalette.forWeather(_currentType);
  }

  /// Change weather condition with optional instant transition
  void setWeather(WeatherType type, {bool instant = false}) {
    if (_currentType == type && !instant) return;
    _currentType = type;
    _applyPresetTargets(type);

    if (instant) {
      _snapToTargets();
    }
    notifyListeners();
  }

  /// Advance weather transitions and storm effects
  void update(double dt) {
    final lerpRate = (dt * 1.0).clamp(0.0, 1.0);

    _rainIntensity += (_targetRainIntensity - _rainIntensity) * lerpRate;
    _windSpeed += (_targetWindSpeed - _windSpeed) * lerpRate;
    _skyDarkness += (_targetSkyDarkness - _skyDarkness) * lerpRate;
    _cloudDensity += (_targetCloudDensity - _cloudDensity) * lerpRate;

    final targetPalette = SkyPalette.forWeather(_currentType);
    _currentPalette = SkyPalette.lerp(_currentPalette, targetPalette, lerpRate);

    // Dynamic lightning flashes during monsoon
    if (_currentType == WeatherType.monsoon) {
      _lightningCooldown -= dt;
      if (_lightningCooldown <= 0.0) {
        _lightningFlash = 1.0;
        _lightningCooldown = 3.5 + _rnd.nextDouble() * 5.0; // Next flash in 3.5-8.5s
      }
    } else {
      _lightningFlash = 0.0;
    }

    if (_lightningFlash > 0.0) {
      _lightningFlash = max(0.0, _lightningFlash - dt * 4.0); // Quick flash decay
    }
  }
}
