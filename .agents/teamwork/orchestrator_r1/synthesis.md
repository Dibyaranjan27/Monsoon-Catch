# Synthesis: Milestone R1 — Viewport & Dynamic Canvas Environment

## Consensus Findings
1. **Virtual Resolution & Viewport**:
   - Exact resolution: **640 x 360** (16:9 aspect ratio).
   - Flame 1.37 setup: `CameraComponent.withFixedResolution(width: 640, height: 360, world: world)` with `camera.viewfinder.anchor = Anchor.topLeft;`.
   - Letterbox color: `Color(0xFF0F172A)` (deep slate).
   - All visual components reside within `World` (e.g. `MonsoonWorld`), ensuring uniform scaling, automatic clipping, and letterboxing/pillarboxing.

2. **Procedural Environment Architecture (Replacing static images)**:
   - Remove dependency on `pixel_background_forest_and_pond.png` and `cloud.png`.
   - `SkyComponent`: 4-stop vertical linear gradient interpolating across Clear Dawn, Clear Day, Overcast, Monsoon Storm.
   - `CloudComponent`: Multi-puff procedural geometry with 2-tone pixel-art shading, kinematic drift, and horizontal wrap-around.
   - `PineForestComponent`: Procedural compound paths of 3-5 tiered pine trees across far ridge, mid ridge, and bank foreground with fog blending.
   - `RiverBankComponent`: Cross-section terrain on left ($x \in [0, 0.32 W]$) with peat soil, green grass cap, and shoreline foam.
   - `WaterSurfaceComponent`: Multi-harmonic sine wave simulation ($y(x,t) = y_{\text{base}} + \sum A_k \sin(...)$) with weather turbulence, foam crest, and rain impact ripples.
   - `DynamicEnvironment`: Coordinator component grouping all environment layers with correct z-order priorities.
   - `WeatherState`: Reactive model with smooth transitions between Clear, Overcast, and Monsoon.
   - `WeatherControlsOverlay`: Flutter UI HUD allowing live interactive switching of weather to observe dynamic shifts.

3. **Code Layout & File Ownership for Worker**:
   - Worker owns:
     - `lib/config/game_config.dart`
     - `lib/models/weather_state.dart`
     - `lib/logic/wave_generator.dart`
     - `lib/components/environment/sky_component.dart`
     - `lib/components/environment/cloud_component.dart`
     - `lib/components/environment/pine_forest_component.dart`
     - `lib/components/environment/river_bank_component.dart`
     - `lib/components/environment/water_surface_component.dart`
     - `lib/components/environment/dynamic_environment.dart`
     - `lib/components/parallax_background.dart` (refactored or replaced by dynamic environment)
     - `lib/game/monsoon_game.dart` and `lib/game/monsoon_world.dart` (or `lib/main.dart`)
     - `lib/ui/weather_controls_overlay.dart`
     - `lib/main.dart`
     - `test/viewport_test.dart`
     - `test/weather_state_test.dart`
     - `test/wave_generator_test.dart`
     - `test/dynamic_environment_test.dart`

4. **Verification Requirements**:
   - `flutter test` passes 100% of tests.
   - `flutter analyze` reports 0 issues.
   - `flutter build web` compiles cleanly.
