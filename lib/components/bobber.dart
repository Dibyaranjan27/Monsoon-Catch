import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

import '../config/game_config.dart';
import '../game/monsoon_game.dart';

enum BobberState { floating, nibble, bite, caught, missed }

class BobberComponent extends SpriteComponent
    with HasGameReference<MonsoonGame> {
  BobberState state = BobberState.floating;
  late Vector2 originalPosition;

  BobberComponent({required Vector2 position})
      : super(
          position: position,
          anchor: Anchor.center,
          priority: GameConfig.priorityWaterSurface + 5,
        ) {
    originalPosition = position.clone();
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();
    sprite = await game.loadSprite('bobber.png');
    size = Vector2(24, 24);
  }

  void changeState(BobberState newState) {
    state = newState;
    removeAll(children.query<Effect>());

    switch (newState) {
      case BobberState.floating:
        // Slow bob up and down
        add(
          MoveEffect.by(
            Vector2(0, 4),
            EffectController(duration: 1.2, reverseDuration: 1.2, infinite: true),
          ),
        );
        break;
      case BobberState.nibble:
        // Quick jitter
        add(
          MoveEffect.by(
            Vector2(0, 4),
            EffectController(duration: 0.1, reverseDuration: 0.1, repeatCount: 2),
          ),
        );
        break;
      case BobberState.bite:
        // Pulled sharply underwater
        add(
          MoveEffect.to(
            originalPosition + Vector2(0, 12),
            EffectController(duration: 0.1),
          ),
        );
        break;
      case BobberState.caught:
        // Jump out of water
        add(
          MoveEffect.to(
            originalPosition - Vector2(0, 40),
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
