import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:math';

import '../main.dart';

enum RainIntensity { light, medium, heavy }

class RainComponent extends PositionComponent with HasGameReference<MonsoonGame> {
  RainIntensity intensity = RainIntensity.light;
  final Random _rnd = Random();
  double _timeSinceLastDrop = 0;

  double get _dropInterval {
    switch (intensity) {
      case RainIntensity.light: return 0.1;
      case RainIntensity.medium: return 0.05;
      case RainIntensity.heavy: return 0.01;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _timeSinceLastDrop += dt;

    while (_timeSinceLastDrop > _dropInterval) {
      _timeSinceLastDrop -= _dropInterval;
      _spawnDrop();
    }
  }

  void _spawnDrop() {
    // Spawn drop anywhere along the top width of the screen
    final startX = _rnd.nextDouble() * game.size.x;
    final drop = RainDrop(Vector2(startX, -20));
    add(drop);
  }
}

class RainDrop extends RectangleComponent with HasGameReference<MonsoonGame> {
  final double speed;

  RainDrop(Vector2 position)
      : speed = 400.0 + Random().nextDouble() * 200.0,
        super(
          position: position,
          size: Vector2(2, 15),
          paint: Paint()..color = Colors.lightBlueAccent.withValues(alpha: 0.5),
        );

  @override
  void update(double dt) {
    super.update(dt);
    position.y += speed * dt;
    
    // Remove the drop when it falls off the bottom of the screen
    if (position.y > game.size.y) {
      removeFromParent();
    }
  }
}
