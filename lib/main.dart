import 'package:flutter/material.dart';
import 'package:flame/game.dart';

import 'game/monsoon_game.dart';
import 'ui/weather_controls_overlay.dart';

export 'game/monsoon_game.dart';
export 'game/monsoon_world.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final game = MonsoonGame();

  runApp(
    MaterialApp(
      title: 'Monsoon Catch',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        backgroundColor: const Color(0xFF0F172A), // Deep slate letterbox background
        body: GameWidget<MonsoonGame>(
          game: game,
          overlayBuilderMap: {
            'WeatherControls': (context, game) =>
                WeatherControlsOverlay(game: game),
          },
          initialActiveOverlays: const ['WeatherControls'],
        ),
      ),
    ),
  );
}
