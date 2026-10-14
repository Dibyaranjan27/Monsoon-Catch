import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../game/monsoon_game.dart';

enum CharacterState { idle, casting, reeling, caught }

class CharacterPlaceholder
    extends SpriteGroupComponent<CharacterState>
    with HasGameReference<MonsoonGame> {
  CharacterPlaceholder()
      : super(
          size: Vector2(80, 80),
          position: Vector2(35, 138),
          priority: GameConfig.priorityCharacter,
        );

  @override
  Future<void> onLoad() async {
    super.onLoad();

    final idleSprite = await game.loadSprite('character_idle.png');
    final castingSprite = await game.loadSprite('character_casting.png');
    final reelingSprite = await game.loadSprite('character_reeling.png');
    final caughtSprite = await game.loadSprite('character_caught.png');

    sprites = {
      CharacterState.idle: idleSprite,
      CharacterState.casting: castingSprite,
      CharacterState.reeling: reelingSprite,
      CharacterState.caught: caughtSprite,
    };

    current = CharacterState.idle;
  }

  /// Calculates the tip of the rod to anchor the fishing line
  Vector2 getRodTipPosition() {
    if (current == CharacterState.casting) {
      return absolutePosition + Vector2(size.x * 0.85, size.y * 0.25);
    } else if (current == CharacterState.caught ||
        current == CharacterState.reeling) {
      return absolutePosition + Vector2(size.x * 0.70, size.y * 0.35);
    }
    return absolutePosition + Vector2(size.x * 0.75, size.y * 0.45);
  }
}
