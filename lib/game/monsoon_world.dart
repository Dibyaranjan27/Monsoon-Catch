import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../components/bobber.dart';
import '../components/character.dart';
import '../components/environment/dynamic_environment.dart';
import '../components/rain.dart';
import '../config/game_config.dart';
import '../logic/fishing_math.dart';
import '../models/weather_state.dart';
import 'monsoon_game.dart';

/// Logical world container hosting the dynamic procedural environment,
/// character, rain, and interactive fishing elements.
class MonsoonWorld extends World
    with TapCallbacks, HasGameReference<MonsoonGame> {
  final WeatherState weather;

  late final DynamicEnvironment environment;
  late final RainComponent rain;
  late final CharacterPlaceholder character;
  late final TextComponent feedbackText;

  BobberComponent? currentBobber;
  final FishingMath math = FishingMath();

  double _timer = 0;
  int _nibblesRemaining = 0;
  bool _isFishing = false;

  MonsoonWorld({WeatherState? weather})
      : weather = weather ?? WeatherState();

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // 1. Pure procedural dynamic environment (zero static bitmaps)
    environment = DynamicEnvironment(
      size: GameConfig.virtualSize,
      weather: weather,
    );
    await add(environment);

    // 2. Weather-synchronized rain particle system
    rain = RainComponent(weather: weather);
    await add(rain);

    // 3. Pixel fisher character on left bank perch
    character = CharacterPlaceholder();
    await add(character);

    // 4. Instructions HUD Text (positioned within 640x360 virtual space)
    feedbackText = TextComponent(
      text: 'Tap water to cast!',
      position: Vector2(GameConfig.virtualWidth / 2, 22),
      anchor: Anchor.topCenter,
      priority: GameConfig.priorityHud,
      textRenderer: TextPaint(
        style: const TextStyle(
          fontFamily: 'PressStart2P',
          color: Colors.white,
          fontSize: 10,
          shadows: [
            Shadow(
              blurRadius: 2.0,
              color: Colors.black87,
              offset: Offset(1.5, 1.5),
            ),
          ],
        ),
      ),
    );
    await add(feedbackText);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_isFishing || currentBobber == null) return;

    if (currentBobber!.state == BobberState.floating ||
        currentBobber!.state == BobberState.nibble) {
      _timer -= dt;

      if (_timer <= 0) {
        if (_nibblesRemaining > 0) {
          // Trigger a nibble jitter
          _nibblesRemaining--;
          currentBobber!.changeState(BobberState.nibble);
          _timer = 0.8;
        } else {
          // Fish strikes! Narrow bite window
          currentBobber!.changeState(BobberState.bite);
          character.current = CharacterState.reeling;
          _timer = math.getBiteWindow(rain.intensity);
        }
      } else if (currentBobber!.state == BobberState.nibble && _timer <= 0.4) {
        currentBobber!.changeState(BobberState.floating);
      }
    } else if (currentBobber!.state == BobberState.bite) {
      _timer -= dt;
      if (_timer <= 0) {
        // Missed the strike
        currentBobber!.changeState(BobberState.missed);
        character.current = CharacterState.idle;
        feedbackText.text = 'Missed it!';
        _isFishing = false;
      }
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    final pos = event.localPosition;

    // Check interaction with active bobber
    if (currentBobber != null) {
      if (currentBobber!.state == BobberState.bite) {
        // Successful catch!
        currentBobber!.changeState(BobberState.caught);
        character.current = CharacterState.caught;
        feedbackText.text = 'Caught a fish!';
        _isFishing = false;
        return;
      } else if (_isFishing) {
        // Reeled too early
        currentBobber!.changeState(BobberState.missed);
        character.current = CharacterState.idle;
        feedbackText.text = 'Too early!';
        _isFishing = false;
        return;
      }
    }

    // Cast a new line: target must be inside the water body
    // Water starts at x >= 192 (0.30 W) and y >= 220 (~0.61 H)
    if (pos.x >= GameConfig.virtualWidth * 0.30 &&
        pos.y >= GameConfig.virtualHeight * 0.60 &&
        pos.x <= GameConfig.virtualWidth &&
        pos.y <= GameConfig.virtualHeight) {
      feedbackText.text = 'Waiting for bite...';

      if (currentBobber != null) {
        remove(currentBobber!);
      }

      currentBobber = BobberComponent(position: pos);
      add(currentBobber!);

      _isFishing = true;
      _nibblesRemaining = math.getNibbleCount();
      _timer = math.getWaitTime(rain.intensity);
      currentBobber!.changeState(BobberState.floating);
      character.current = CharacterState.idle;
    } else {
      feedbackText.text = 'Tap the water to cast!';
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Render fishing line between rod tip and bobber
    if (currentBobber != null && _isFishing) {
      final linePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.65)
        ..strokeWidth = 1.0;

      final rodTip = character.getRodTipPosition();
      canvas.drawLine(
        Offset(rodTip.x, rodTip.y),
        Offset(currentBobber!.position.x, currentBobber!.position.y),
        linePaint,
      );
    }
  }
}
