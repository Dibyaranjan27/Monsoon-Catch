import 'package:flame/components.dart';
import '../main.dart';

class ParallaxBackground extends PositionComponent with HasGameReference<MonsoonGame> {
  @override
  Future<void> onLoad() async {
    super.onLoad();

    // The beautiful main background
    final bgSprite = await game.loadSprite('pixel_background_forest_and_pond.png');
    add(SpriteComponent(
      sprite: bgSprite,
      size: game.size,
    ));

    // Moving Clouds for some life
    add(MovingCloud(position: Vector2(50, 40), speed: 10));
    add(MovingCloud(position: Vector2(250, 80), speed: 15));
    add(MovingCloud(position: Vector2(500, 30), speed: 8));
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
