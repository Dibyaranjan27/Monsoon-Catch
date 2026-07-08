import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../main.dart';

class ParallaxBackground extends PositionComponent with HasGameReference<MonsoonGame> {
  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Sky Background (Pastel mint green/blue)
    add(RectangleComponent(
      size: Vector2(game.size.x, game.size.y * 0.6),
      paint: Paint()..color = const Color(0xFFC7E2E0), 
    ));

    // Moving Clouds (Placeholder layer)
    add(MovingCloud(position: Vector2(50, 40), speed: 10));
    add(MovingCloud(position: Vector2(250, 80), speed: 15));
    add(MovingCloud(position: Vector2(500, 30), speed: 8));

    // Distant Trees / Opposite Bank
    add(RectangleComponent(
      position: Vector2(0, game.size.y * 0.5),
      size: Vector2(game.size.x, game.size.y * 0.1),
      paint: Paint()..color = const Color(0xFF8BA698), // Muted pastel green
    ));

    // Water Surface
    add(RectangleComponent(
      position: Vector2(0, game.size.y * 0.6),
      size: Vector2(game.size.x, game.size.y * 0.4),
      paint: Paint()..color = const Color(0xFF7CA6AA), // Water blue-green
    ));

    // Foreground Bank (Left side where character stands)
    add(RectangleComponent(
      position: Vector2(0, game.size.y * 0.55),
      size: Vector2(game.size.x * 0.3, game.size.y * 0.45),
      paint: Paint()..color = const Color(0xFF5E7F6E), // Darker ground color
    ));
  }
}

class MovingCloud extends RectangleComponent with HasGameReference<MonsoonGame> {
  final double speed;

  MovingCloud({required Vector2 position, required this.speed})
      : super(
          position: position,
          size: Vector2(80, 30),
          paint: Paint()..color = Colors.white.withValues(alpha: 0.8),
        );

  @override
  void update(double dt) {
    super.update(dt);
    position.x -= speed * dt;
    if (position.x + size.x < 0) {
      // Loop back to the right side of the screen
      position.x = game.size.x;
    }
  }
}
