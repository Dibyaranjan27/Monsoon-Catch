import 'package:flame/components.dart';
import '../main.dart';

enum CharacterState { idle, casting, reeling, caught }

class CharacterPlaceholder extends SpriteGroupComponent<CharacterState> with HasGameReference<MonsoonGame> {
  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Position the character on the left bank
    // Increased size to make the character look better
    size = Vector2(300, 300); 
    position = Vector2(game.size.x * 0.02, game.size.y * 0.55 - 200);

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
    // Adjusted percentages based on the visual bounding box of the sprites
    if (current == CharacterState.casting) {
      return absolutePosition + Vector2(size.x * 0.85, size.y * 0.25);
    } else if (current == CharacterState.caught || current == CharacterState.reeling) {
      return absolutePosition + Vector2(size.x * 0.7, size.y * 0.35);
    }
    return absolutePosition + Vector2(size.x * 0.75, size.y * 0.45); 
  }
}
