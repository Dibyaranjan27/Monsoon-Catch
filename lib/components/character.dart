import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../main.dart';

class CharacterPlaceholder extends PositionComponent with HasGameReference<MonsoonGame> {
  late RectangleComponent body;
  late RectangleComponent rod;

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Position the character on the left bank
    position = Vector2(game.size.x * 0.2, game.size.y * 0.55 - 50);

    // Character body placeholder (Pastel warm red/pink)
    body = RectangleComponent(
      size: Vector2(30, 50),
      paint: Paint()..color = const Color(0xFFEF8385), 
    );
    
    // Fishing rod pointing diagonally towards the water
    rod = RectangleComponent(
      position: Vector2(25, 10),
      size: Vector2(80, 4),
      angle: 0.3, // Pointing down slightly towards the right
      paint: Paint()..color = const Color(0xFF554433),
    );

    add(body);
    add(rod);
  }

  /// Calculates the tip of the rod so we can draw a line to the bobber later
  Vector2 getRodTipPosition() {
    // Basic trigonometry to find the tip based on angle and length
    // Absolute position relative to game space
    return absolutePosition + Vector2(25 + 80 * 0.955, 10 + 80 * 0.295); 
  }
}
