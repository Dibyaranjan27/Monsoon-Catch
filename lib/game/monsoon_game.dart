import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../config/game_config.dart';
import '../models/weather_state.dart';
import 'monsoon_world.dart';

/// Root Flame game configured with FixedResolutionViewport (640x360)
/// and letterbox background color Color(0xFF0F172A).
class MonsoonGame extends FlameGame<MonsoonWorld> {
  final WeatherState weather;

  MonsoonGame._({
    required this.weather,
    required MonsoonWorld world,
  }) : super(
          world: world,
          camera: CameraComponent.withFixedResolution(
            width: GameConfig.virtualWidth,
            height: GameConfig.virtualHeight,
          ),
        );

  factory MonsoonGame({WeatherState? weatherState}) {
    final state = weatherState ?? WeatherState();
    final world = MonsoonWorld(weather: state);
    return MonsoonGame._(weather: state, world: world);
  }

  @override
  Color backgroundColor() => GameConfig.letterboxColor;

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Set camera viewfinder anchor to Anchor.topLeft so virtual origin (0, 0)
    // maps directly to top-left of the viewport.
    camera.viewfinder.anchor = Anchor.topLeft;
    camera.viewfinder.position = Vector2.zero();
  }
}
