import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

import '../main.dart';

enum BobberState { floating, nibble, bite, caught, missed }

class BobberComponent extends SpriteComponent with HasGameReference<MonsoonGame> {
  BobberState state = BobberState.floating;
  late Vector2 originalPosition;

  BobberComponent({required Vector2 position})
      : super(
          position: position,
          anchor: Anchor.center,
        ) {
    originalPosition = position.clone();
  }

  @override
  Future<void> onLoad() async {
    sprite = await game.loadSprite('bobber.png');
    size = Vector2(40, 40); // Base size for the sprite
  }

  void changeState(BobberState newState) {
    state = newState;
    removeAll(children.query<Effect>());

    switch (newState) {
      case BobberState.floating:
        // Slow bob up and down
        add(
          MoveEffect.by(
            Vector2(0, 5),
            EffectController(duration: 1.5, reverseDuration: 1.5, infinite: true),
          ),
        );
        break;
      case BobberState.nibble:
        // Quick jitter
        add(
          MoveEffect.by(
            Vector2(0, 5),
            EffectController(duration: 0.1, reverseDuration: 0.1, repeatCount: 2),
          ),
        );
        break;
      case BobberState.bite:
        // Pulled sharply underwater
        add(
          MoveEffect.to(
            originalPosition + Vector2(0, 15),
            EffectController(duration: 0.1),
          ),
        );
        break;
      case BobberState.caught:
        // Jump out of water
        add(
          MoveEffect.to(
            originalPosition - Vector2(0, 50),
            EffectController(duration: 0.5, curve: Curves.easeOutQuad),
          ),
        );
        break;
      case BobberState.missed:
        // Return to float position sadly
        add(
          MoveEffect.to(
            originalPosition,
            EffectController(duration: 0.5),
          ),
        );
        break;
    }
  }
}
