import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

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
