import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config/game_config.dart';
import '../game/monsoon_game.dart';
import '../models/weather_state.dart';

enum RainIntensity { light, medium, heavy }

class RainComponent extends PositionComponent
    with HasGameReference<MonsoonGame> {
  final WeatherState? weather;
  RainIntensity intensity = RainIntensity.light;

  final Random _rnd = Random();
  double _timeSinceLastDrop = 0;

  RainComponent({this.weather})
      : super(
          size: GameConfig.virtualSize,
          priority: GameConfig.priorityRain,
        );

  double get _dropInterval {
    if (weather != null) {
      if (weather!.rainIntensity <= 0.05) return 999.0;
      return (0.15 / (weather!.rainIntensity * 6.0 + 0.1)).clamp(0.012, 0.20);
    }

    switch (intensity) {
      case RainIntensity.light:
        return 0.1;
      case RainIntensity.medium:
        return 0.05;
      case RainIntensity.heavy:
        return 0.01;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Sync enum intensity from weather model if available
    if (weather != null) {
      if (weather!.rainIntensity >= 0.65) {
        intensity = RainIntensity.heavy;
      } else if (weather!.rainIntensity >= 0.25) {
        intensity = RainIntensity.medium;
      } else {
        intensity = RainIntensity.light;
      }

      // If virtually dry, don't accumulate rain drops
      if (weather!.rainIntensity <= 0.05) {
        return;
      }
    }

    _timeSinceLastDrop += dt;
    final interval = _dropInterval;

    while (_timeSinceLastDrop > interval) {
      _timeSinceLastDrop -= interval;
      _spawnDrop();
    }
  }

  void _spawnDrop() {
    final startX = _rnd.nextDouble() * (GameConfig.virtualWidth + 100.0) - 20.0;
    final windFactor = weather?.windSpeed ?? 0.3;
    final drop = RainDrop(
      position: Vector2(startX, -15),
      windSpeed: windFactor,
    );
    add(drop);
  }
}

class RainDrop extends RectangleComponent {
  final double speed;
  final double windSpeed;

  RainDrop({
    required Vector2 position,
    this.windSpeed = 0.3,
  })  : speed = 420.0 + Random().nextDouble() * 180.0,
        super(
          position: position,
          size: Vector2(1.5, 12),
          paint: Paint()..color = const Color(0x99BAE6FD),
        );

  @override
  void update(double dt) {
    super.update(dt);
    // Drift with wind
    position.x -= (windSpeed * 70.0) * dt;
    position.y += speed * dt;

    if (position.y > GameConfig.virtualHeight + 20.0 || position.x < -30.0) {
      removeFromParent();
    }
  }
}
