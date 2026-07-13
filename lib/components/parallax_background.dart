import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../main.dart';

class ParallaxBackground extends PositionComponent with HasGameReference<MonsoonGame> {
  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Sky Background
    add(RectangleComponent(
      size: Vector2(game.size.x, game.size.y * 0.6),
      paint: Paint()..color = const Color(0xFFC7E2E0), 
    ));

    // Moving Clouds using user's pixel_cloud sprite
    add(MovingCloud(position: Vector2(50, 40), speed: 10));
    add(MovingCloud(position: Vector2(250, 80), speed: 15));
    add(MovingCloud(position: Vector2(500, 30), speed: 8));

    // Distant Trees / Opposite Bank Landmass
    add(RectangleComponent(
      position: Vector2(0, game.size.y * 0.5),
      size: Vector2(game.size.x, game.size.y * 0.1),
      paint: Paint()..color = const Color(0xFF8BA698), 
    ));

    // Distant Trees using user's tree sprite
    for (int i = 0; i < 5; i++) {
      add(TreeComponent(position: Vector2(game.size.x * 0.2 + (i * 180), game.size.y * 0.5 - 80)));
    }

    // Water Surface
    add(RectangleComponent(
      position: Vector2(0, game.size.y * 0.6),
      size: Vector2(game.size.x, game.size.y * 0.4),
      paint: Paint()..color = const Color(0xFF7CA6AA), 
    ));

    // Foreground Bank where Character stands
    add(RectangleComponent(
      position: Vector2(0, game.size.y * 0.55),
      size: Vector2(game.size.x * 0.35, game.size.y * 0.45),
      paint: Paint()..color = const Color(0xFF5E7F6E), 
    ));
  }
}

class MovingCloud extends SpriteComponent with HasGameReference<MonsoonGame> {
  final double speed;

  MovingCloud({required Vector2 position, required this.speed}) : super(position: position);

  @override
  Future<void> onLoad() async {
    sprite = await game.loadSprite('cloud.png');
    size = Vector2(100, 50);
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.x -= speed * dt;
    if (position.x + size.x < 0) {
      position.x = game.size.x;
    }
  }
}

class TreeComponent extends SpriteComponent with HasGameReference<MonsoonGame> {
  TreeComponent({required Vector2 position}) : super(position: position);

  @override
  Future<void> onLoad() async {
    sprite = await game.loadSprite('tree.png');
    size = Vector2(80, 100);
  }
}
