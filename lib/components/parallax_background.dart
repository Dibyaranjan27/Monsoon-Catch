import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../models/weather_state.dart';
import 'environment/dynamic_environment.dart';

/// Legacy adapter wrapping [DynamicEnvironment] ensuring 100% pure procedural
/// rendering without any reliance on static background images.
class ParallaxBackground extends PositionComponent {
  final WeatherState? weather;

  ParallaxBackground({this.weather, Vector2? size})
      : super(
          size: size ?? GameConfig.virtualSize,
          priority: 0,
        );

  @override
  Future<void> onLoad() async {
    super.onLoad();
    final effectiveWeather = weather ?? WeatherState();
    add(
      DynamicEnvironment(
        size: size,
        weather: effectiveWeather,
      ),
    );
  }
}
