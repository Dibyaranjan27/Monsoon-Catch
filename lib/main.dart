import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flame/components.dart';
import 'package:flame/text.dart';

import 'components/bobber.dart';
import 'components/rain.dart';
import 'components/parallax_background.dart';
import 'components/character.dart';
import 'logic/fishing_math.dart';

void main() {
  runApp(GameWidget(game: MonsoonGame()));
}

class MonsoonGame extends FlameGame with TapCallbacks {
  BobberComponent? currentBobber;
  late RainComponent rain;
  late ParallaxBackground background;
  late CharacterPlaceholder character;
  late TextComponent feedbackText;
  final FishingMath math = FishingMath();

  double _timer = 0;
  int _nibblesRemaining = 0;
  bool _isFishing = false;

  @override
  Color backgroundColor() => const Color(0xFF1B2A36);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    // 1. Background Layers
    background = ParallaxBackground();
    add(background);

    // 2. Weather
    rain = RainComponent();
    add(rain);

    // 3. Character
    character = CharacterPlaceholder();
    add(character);

    feedbackText = TextComponent(
      text: 'Tap to Cast!',
      position: Vector2(size.x / 2, 50),
      anchor: Anchor.topCenter,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(feedbackText);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_isFishing || currentBobber == null) return;

    if (currentBobber!.state == BobberState.floating || currentBobber!.state == BobberState.nibble) {
      _timer -= dt;
      
      if (_timer <= 0) {
        if (_nibblesRemaining > 0) {
          // Trigger a nibble
          _nibblesRemaining--;
          currentBobber!.changeState(BobberState.nibble);
          _timer = 0.8; // Wait 0.8 seconds until next action
        } else {
          // Time to bite!
          currentBobber!.changeState(BobberState.bite);
          _timer = math.getBiteWindow(rain.intensity);
        }
      } else if (currentBobber!.state == BobberState.nibble && _timer <= 0.4) {
         // Revert back to floating state in between nibbles
         currentBobber!.changeState(BobberState.floating);
      }
    } else if (currentBobber!.state == BobberState.bite) {
      _timer -= dt;
      if (_timer <= 0) {
        // Missed the fish!
        currentBobber!.changeState(BobberState.missed);
        feedbackText.text = 'Missed it!';
        _isFishing = false;
      }
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    
    // Check if we are currently interacting with an active bobber
    if (currentBobber != null) {
      if (currentBobber!.state == BobberState.bite) {
        // Caught the fish!
        currentBobber!.changeState(BobberState.caught);
        feedbackText.text = 'Caught!';
        _isFishing = false;
        return;
      } else if (_isFishing) {
        // Reeled in too early!
        currentBobber!.changeState(BobberState.missed);
        feedbackText.text = 'Too early!';
        _isFishing = false;
        return;
      }
    }

    // Cast a new line
    // Only allow casting into the water area (right side of the bank, bottom 40%)
    if (event.localPosition.x > size.x * 0.3 && event.localPosition.y > size.y * 0.6) {
      feedbackText.text = 'Waiting...';
      if (currentBobber != null) {
        remove(currentBobber!);
      }
      
      currentBobber = BobberComponent(position: event.localPosition);
      add(currentBobber!);
      
      // Start fishing sequence
      _isFishing = true;
      _nibblesRemaining = math.getNibbleCount();
      _timer = math.getWaitTime(rain.intensity);
      currentBobber!.changeState(BobberState.floating);
    } else {
      feedbackText.text = 'Tap the water to cast!';
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    
    // Draw the fishing line if a bobber exists
    if (currentBobber != null) {
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..strokeWidth = 1.0;
      
      final rodTip = character.getRodTipPosition();
      canvas.drawLine(
        Offset(rodTip.x, rodTip.y),
        Offset(currentBobber!.position.x, currentBobber!.position.y),
        paint,
      );
    }
  }
}
