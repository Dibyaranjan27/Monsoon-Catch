import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

enum BobberState { idle, floating, nibble, bite, caught, missed }

class BobberComponent extends CircleComponent {
  BobberState state = BobberState.idle;

  BobberComponent({required super.position})
      : super(
          radius: 8.0,
          anchor: Anchor.center,
          paint: Paint()..color = Colors.orange,
        );

  @override
  Future<void> onLoad() async {
    super.onLoad();
    _startIdleAnimation();
  }

  void _startIdleAnimation() {
    removeAll(children.whereType<MoveEffect>());
    add(
      MoveEffect.by(
        Vector2(0, 4),
        EffectController(
          duration: 1.0,
          alternate: true,
          infinite: true,
        ),
      ),
    );
  }

  void changeState(BobberState newState) {
    if (state == newState) return;
    state = newState;

    removeAll(children.whereType<MoveEffect>());

    switch (state) {
      case BobberState.idle:
      case BobberState.floating:
        paint.color = Colors.orange;
        _startIdleAnimation();
        break;
      case BobberState.nibble:
        paint.color = Colors.yellow;
        // Fast small jitters
        add(
          MoveEffect.by(
            Vector2(0, 3),
            EffectController(duration: 0.1, alternate: true, repeatCount: 3),
          ),
        );
        break;
      case BobberState.bite:
        paint.color = Colors.red;
        // Pulled sharply under water
        add(
          MoveEffect.by(
            Vector2(0, 12),
            EffectController(duration: 0.1, alternate: false),
          ),
        );
        break;
      case BobberState.caught:
        paint.color = Colors.green;
        // Jumps out of water
        add(
          MoveEffect.by(
            Vector2(0, -30),
            EffectController(duration: 0.2, alternate: true, repeatCount: 1),
          ),
        );
        break;
      case BobberState.missed:
        paint.color = Colors.grey;
        // Sad float back to center
        _startIdleAnimation();
        break;
    }
  }
}
