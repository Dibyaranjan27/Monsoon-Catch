import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/effects.dart';

void main() {
  runApp(GameWidget(game: MonsoonGame()));
}

class MonsoonGame extends FlameGame with TapCallbacks {
  BobberComponent? currentBobber;

  @override
  Color backgroundColor() => const Color(0xFF1B2A36); // Moody deep-water color

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    
    // Remove existing bobber if there is one
    if (currentBobber != null) {
      remove(currentBobber!);
    }
    
    // Add new bobber at tap location
    currentBobber = BobberComponent(position: event.localPosition);
    add(currentBobber!);
  }
}

class BobberComponent extends CircleComponent {
  BobberComponent({required super.position})
      : super(
          radius: 8.0,
          anchor: Anchor.center,
          paint: Paint()..color = Colors.orange,
        );

  @override
  Future<void> onLoad() async {
    super.onLoad();
    add(
      MoveEffect.by(
        Vector2(0, 4), // Move down by 4 pixels
        EffectController(
          duration: 1.0, // Over 1 second
          alternate: true, // And then move back up
          infinite: true, // Repeat forever
        ),
      ),
    );
  }
}
