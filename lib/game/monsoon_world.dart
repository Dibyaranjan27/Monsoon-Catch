import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../components/bobber.dart';
import '../components/character.dart';
import '../components/environment/dynamic_environment.dart';
import '../components/fishing_line.dart';
import '../components/rain.dart';
import '../config/game_config.dart';
import '../logic/fishing_math.dart';
import '../models/weather_state.dart';
import 'monsoon_game.dart';

/// Logical world container hosting the dynamic procedural environment,
/// procedural character, physics-aware fishing line, bobber, rain, and HUD.
class MonsoonWorld extends World
    with TapCallbacks, HasGameReference<MonsoonGame> {
  final WeatherState weather;

  late final DynamicEnvironment environment;
  late final RainComponent rain;
  late final CharacterComponent character;
  late final FishingLineComponent fishingLine;
  late final TextComponent feedbackText;

  BobberComponent? currentBobber;
  final FishingMath math = FishingMath();

  double _timer = 0;
  int _nibblesRemaining = 0;
  bool _isFishing = false;
  double _autoResetTimer = 0;

  bool get isFishing => _isFishing;
  double get timer => _timer;
  int get nibblesRemaining => _nibblesRemaining;

  MonsoonWorld({WeatherState? weather})
      : weather = weather ?? WeatherState();

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // 1. Pure procedural dynamic environment (Priority 0)
    environment = DynamicEnvironment(
      size: GameConfig.virtualSize,
      weather: weather,
    );
    await add(environment);

    // 2. Weather-synchronized rain particle system (Priority 90)
    rain = RainComponent(weather: weather);
    await add(rain);

    // 3. Procedural pixel fisher character on riverbank platform (Priority 80)
    character = CharacterComponent(
      position: Vector2(118.0, 208.8),
    );
    await add(character);

    // 4. Physics-aware catenary/Bezier fishing line (Priority 78)
    fishingLine = FishingLineComponent(
      rodTipProvider: () => character.rodTipPosition,
      bobberPositionProvider: () => currentBobber?.position,
      tensionProvider: _getLineTension,
      windFactorProvider: () => weather.windSpeed,
      activeProvider: () => _isFishing && currentBobber != null,
    );
    await add(fishingLine);

    // 5. Instructions HUD Text (Priority 100)
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

  /// Evaluates normalized line tension tau in [0.0, 1.0].
  double _getLineTension() {
    if (!_isFishing || currentBobber == null) return 0.0;

    if (character.current == CharacterState.casting) {
      // Dynamic tension during whip and flight
      return (0.85 * (1.0 - character.castProgress) + 0.15).clamp(0.0, 1.0);
    } else if (character.current == CharacterState.reeling ||
        currentBobber!.state == BobberState.bite) {
      // Maximum tension under fish strike / reeling strain
      return 1.0;
    } else if (character.current == CharacterState.caught) {
      return 0.35;
    } else if (currentBobber!.state == BobberState.nibble) {
      return 0.40;
    }
    // Idle / floating: slack sag
    return 0.0;
  }

  /// Retracts the fishing line and cleanly resets all fishing entities atomically.
  void resetFishingState() {
    _isFishing = false;
    _timer = 0;
    _nibblesRemaining = 0;
    _autoResetTimer = 0;

    if (currentBobber != null) {
      currentBobber!.reset();
      remove(currentBobber!);
      currentBobber = null;
    }

    fishingLine.deactivate();
    character.resetToIdle();
  }

  /// Alias for clean retraction.
  void retractLine() => resetFishingState();

  /// Initiates a cast to [pos] within the water body.
  void castTo(Vector2 pos) {
    resetFishingState();

    _isFishing = true;
    feedbackText.text = 'Casting...';

    currentBobber = BobberComponent(position: pos, weather: weather);
    add(currentBobber!);
    fishingLine.activate();

    character.startCast(
      duration: 0.65,
    );

    currentBobber!.startCastTrajectory(
      from: character.rodTipPosition,
      to: pos,
      duration: 0.65,
      onTouchdown: () {
        feedbackText.text = 'Waiting for bite...';
        _nibblesRemaining = math.getNibbleCount();
        _timer = math.getWaitTime(rain.intensity);
      },
    );
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_autoResetTimer > 0) {
      _autoResetTimer -= dt;
      if (_autoResetTimer <= 0) {
        resetFishingState();
        feedbackText.text = 'Tap water to cast!';
      }
      return;
    }

    if (!_isFishing || currentBobber == null) return;

    if (currentBobber!.state == BobberState.floating ||
        currentBobber!.state == BobberState.nibble) {
      _timer -= dt;

      if (_timer <= 0) {
        if (_nibblesRemaining > 0) {
          // Trigger a nibble twitch
          _nibblesRemaining--;
          currentBobber!.changeState(BobberState.nibble);
          _timer = 0.8;
        } else {
          // Fish strikes! Heavy strain on rod
          currentBobber!.changeState(BobberState.bite);
          character.current = CharacterState.reeling;
          feedbackText.text = 'Fish on! Reel now!';
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
        _autoResetTimer = 0.8;
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
        _autoResetTimer = 1.8;
        return;
      } else if (_isFishing) {
        // Reeled too early
        currentBobber!.changeState(BobberState.missed);
        character.current = CharacterState.idle;
        feedbackText.text = 'Too early!';
        _isFishing = false;
        _autoResetTimer = 0.8;
        return;
      }
    }

    // Cast a new line: target must be inside the water body
    // Water starts at x >= 192 (0.30 W) and y >= 220 (~0.61 H)
    if (pos.x >= GameConfig.virtualWidth * 0.30 &&
        pos.y >= GameConfig.virtualHeight * 0.60 &&
        pos.x <= GameConfig.virtualWidth &&
        pos.y <= GameConfig.virtualHeight) {
      castTo(pos);
    } else {
      feedbackText.text = 'Tap the water to cast!';
    }
  }
}
