import 'package:flame/components.dart';
import '../main.dart';

enum CharacterState { idle, casting, reeling, caught }

class CharacterPlaceholder extends SpriteGroupComponent<CharacterState> with HasGameReference<MonsoonGame> {
  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Position the character on the left bank
    position = Vector2(game.size.x * 0.1, game.size.y * 0.55 - 120);
    size = Vector2(150, 150); // Adjusted size to fit well on screen

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

  /// Calculates the tip of the rod so we can draw a line to the bobber later
  Vector2 getRodTipPosition() {
    // The rod tip position depends on the sprite and the state.
    // We approximate a point near the top-right of the sprite.
    return absolutePosition + Vector2(size.x * 0.8, size.y * 0.2); 
  }
}
