import 'package:flame/components.dart';

import '../../models/weather_state.dart';
import 'cloud_component.dart';
import 'pine_forest_component.dart';
import 'river_bank_component.dart';
import 'sky_component.dart';
import 'water_surface_component.dart';

/// Top-level coordinator component grouping all procedural canvas environment layers
/// with strict z-order priorities and unified weather state management.
class DynamicEnvironment extends PositionComponent {
  final WeatherState weather;

  late final SkyComponent sky;
  late final CloudLayerComponent clouds;
  late final PineForestComponent forest;
  late final RiverBankComponent riverBank;
  late final WaterSurfaceComponent waterSurface;

  DynamicEnvironment({
    required Vector2 size,
    required this.weather,
  }) : super(size: size, priority: 0);

  @override
  Future<void> onLoad() async {
    super.onLoad();

    sky = SkyComponent(size: size, weather: weather);
    clouds = CloudLayerComponent(size: size, weather: weather);
    forest = PineForestComponent(size: size, weather: weather);
    riverBank = RiverBankComponent(size: size, weather: weather);
    waterSurface = WaterSurfaceComponent(size: size, weather: weather);

    await add(sky);
    await add(clouds);
    await add(forest);
    await add(riverBank);
    await add(waterSurface);
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Tick the weather model transitions and lightning timers
    weather.update(dt);
  }
}
