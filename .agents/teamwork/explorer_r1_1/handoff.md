# Handoff Report: Requirement R1 Exploration & Architecture Assessment

**Agent**: explorer_r1_1  
**Timestamp**: 2026-10-13T18:49:00Z  
**Target Milestone**: Requirement R1 (Viewport & Dynamic Canvas Environment)  
**Integrity Mode**: Development (Read-only exploration)

---

## 1. Observation

### 1.1 Pubspec & Dependencies
- **File**: `c:\Users\Dibya\StudioProjects\monsoon_catch\pubspec.yaml`
  - SDK constraint: `sdk: ^3.11.4` (Line 22)
  - Dependencies:
    - `flutter`: `sdk: flutter` (Line 31)
    - `cupertino_icons: ^1.0.8` (Line 36)
    - `flame: ^1.37.0` (Line 37)
    - `audioplayers: ^6.7.1` (Line 38)
  - Dev dependencies:
    - `flutter_test`: `sdk: flutter` (Line 41)
    - `flutter_lints: ^6.0.0` (Line 49)
  - Assets registered: `assets/images/` (Line 69) and font `assets/fonts/PressStart2P.ttf` (Lines 63-65).

### 1.2 Existing Project Files & Skeleton
- **`lib/main.dart`**:
  - Defines `MonsoonGame extends FlameGame with TapCallbacks` (Line 17).
  - Uses default Flame root coordinate system without configuring a `CameraComponent.withFixedResolution` or `World` (Lines 17-68).
  - Directly binds positions to `size.x` and `size.y`:
    - Line 50: `position: Vector2(size.x / 2, 50)`
    - Line 131: `if (event.localPosition.x > size.x * 0.3 && event.localPosition.y > size.y * 0.6)`
  - Adds `ParallaxBackground`, `RainComponent`, `CharacterPlaceholder`, `feedbackText` directly to `MonsoonGame` root (Lines 37-67).
- **`lib/components/parallax_background.dart`**:
  - Lines 10-14:
    ```dart
    final bgSprite = await game.loadSprite('pixel_background_forest_and_pond.png');
    add(SpriteComponent(
      sprite: bgSprite,
      size: game.size,
    ));
    ```
  - Loads a static 6,340,129-byte bitmap (`assets/images/pixel_background_forest_and_pond.png`) and stretches it to `game.size`.
  - Lines 17-19, 23-42: Adds `MovingCloud` instances using `assets/images/cloud.png`.
- **`lib/components/character.dart`**:
  - Uses `CharacterPlaceholder` with hardcoded dimensions `size = Vector2(300, 300); position = Vector2(game.size.x * 0.02, game.size.y * 0.55 - 200);` (Lines 13-14).
- **`lib/components/rain.dart`**:
  - `RainComponent` spawns `RainDrop` rectangle components (`size: Vector2(2, 15)`) across `game.size.x`.
- **`lib/components/bobber.dart`**:
  - Sprite component for bobber with Flame `MoveEffect` animations.
- **`lib/logic/fishing_math.dart`**:
  - Defines `FishingMath` calculating wait times and bite windows based on `RainIntensity`.
- **`test/fishing_math_test.dart`**:
  - 3 unit tests verifying `getWaitTime`, `getBiteWindow`, `getNibbleCount`.

### 1.3 Toolchain Verification Results
- **Command**: `flutter --version`
  - Output:
    ```
    Flutter 3.41.6 • channel stable • https://github.com/flutter/flutter.git
    Framework • revision db50e20168 (2026-03-25 16:21:00 -0700)
    Engine • hash 5cdd32777948fa7a648fac915f8da7120ac7e97a
    Tools • Dart 3.11.4 • DevTools 2.54.2
    ```
  - Exit code: 0
- **Command**: `flutter analyze`
  - Output: `Analyzing monsoon_catch... No issues found! (ran in 76.1s)`
  - Exit code: 0
- **Command**: `flutter test`
  - Output:
    ```
    00:00 +0: loading C:/Users/Dibya/StudioProjects/monsoon_catch/test/fishing_math_test.dart
    00:00 +0: FishingMath Tests getWaitTime should return shorter times in heavy rain
    00:00 +1: FishingMath Tests getBiteWindow should return narrower windows in heavy rain
    00:00 +2: FishingMath Tests getNibbleCount should return between 1 and 3
    00:00 +3: All tests passed!
    ```
  - Exit code: 0
- **Command**: `flutter build web`
  - Output:
    ```
    Compiling lib\main.dart for the Web...
    √ Built build\web (ran in 97.0s)
    ```
  - Exit code: 0

### 1.4 Flame 1.37.0 Engine Capabilities
- Located in Pub cache at `C:/Users/Dibya/AppData/Local/Pub/Cache/hosted/pub.dev/flame-1.37.0/lib/src/camera/`:
  - `FixedResolutionViewport(resolution: Vector2(width, height))` (`fixed_resolution_viewport.dart:18-22`):
    - Subclasses `FixedAspectRatioViewport` with `aspectRatio: resolution.x / resolution.y`.
    - Auto-scales using `min(scaleX, scaleY)` on resize (Line 46).
    - Preserves aspect ratio, centers content with letterboxing/pillarboxing, and handles coordinate transformation between screen and virtual space.
  - `CameraComponent.withFixedResolution(width: ..., height: ..., world: ...)` (`camera_component.dart:83-100`):
    - Built-in factory creating a `FixedResolutionViewport` and attaching it to a `World`.

---

## 2. Logic Chain

1. **Gap Analysis against Requirement R1**:
   - *Requirement R1.1*: "Implement a fixed virtual resolution viewport with aspect ratio lock (letterboxing/scaling) in Flame/Flutter so visuals never stretch, warp, or distort across different browser or device sizes."
     - *Finding*: `MonsoonGame` currently relies on raw `game.size` and lacks a `FixedResolutionViewport`. When resized to arbitrary browser aspect ratios, elements warp and reposition unpredictably.
   - *Requirement R1.2*: "Render a dynamic, procedural environment in code (layered gradient sky, floating procedural clouds, layered pine tree silhouettes, and animated water surface with wave/ripple simulation) that dynamically shifts with weather."
     - *Finding*: No procedural canvas environment exists. The current background (`ParallaxBackground`) loads `pixel_background_forest_and_pond.png` (a 6.3MB static image), violating Requirement R1.3.
   - *Requirement R1.3*: "Ensure the scene is completely code/canvas rendered without relying on static stretched background images."
     - *Finding*: `pixel_background_forest_and_pond.png` must be completely replaced by modular procedural canvas renderers.
   - *Requirement R1.4*: "Clean separation between water body, riverbank, and background layers."
     - *Finding*: Must be implemented with distinct z-ordered components: `SkyComponent` -> `CloudComponent` -> `PineForestComponent` -> `RiverBankComponent` -> `WaterSurfaceComponent`.

2. **Dependency & Toolchain Assessment**:
   - `flame: ^1.37.0` already includes `FixedResolutionViewport` and `CameraComponent.withFixedResolution`. No additional external packages are needed.
   - The Flutter SDK (3.41.6 / Dart 3.11.4) builds cleanly for Web, passes `flutter analyze` with 0 issues, and executes tests with 0 failures.

3. **Coordinate System & Resolution Choice**:
   - A virtual resolution of **640 x 360** (16:9 standard 360p) is ideal:
     - Exactly matches modern widescreen displays while offering retro cozy pixel-art scaling (2x integer scaling = 720p, 3x = 1080p, 4x = 1440p, 6x = 4K).
     - Provides ample canvas resolution for multi-layered sine wave surfaces, pine silhouettes, and procedural clouds without sub-pixel aliasing.
     - Anchoring the camera viewfinder at `Anchor.topLeft` maps the virtual world coordinates directly to `x ∈ [0, 640]` and `y ∈ [0, 360]`.

---

## 3. Caveats

- **Existing Phase 2/3 Placeholders**: The current `lib/components/character.dart`, `bobber.dart`, and fishing interaction in `main.dart` are pre-existing prototype code for Requirements R2 and R3. Per the Phase 1 execution constraint, R1 focuses strictly on the Viewport and Dynamic Canvas Environment. To maintain clean architecture, R1 should establish a modular environment hierarchy (`DynamicEnvironment`) in `World`, allowing character and bobber to easily attach in Phase 2 without cluttering R1.
- **Web CanvasKit vs HTML/WASM**: `flutter build web` defaulted to CanvasKit/WASM with dry run success. Procedural canvas operations (`drawPath`, `drawRect`, `drawRRect`, `drawVertices`, gradients) are fully supported across all Flutter web renderers.
- **No Caveats on Toolchain**: Flutter SDK and dependencies are fully verified and functional.

---

## 4. Conclusion & Architectural Recommendations

### 4.1 Recommended Code Layout for lib/
```
lib/
├── config/
│   └── game_config.dart                  # Virtual resolution constants (640x360), aspect ratio (16:9), layer priorities
├── models/
│   └── weather_state.dart                # WeatherState model & notifier (condition: clear/overcast/monsoon, rainIntensity, windSpeed, overcast, waveHeight)
├── logic/
│   ├── wave_generator.dart               # Pure math wave simulation utility (multi-sine wave summation, crest calculation)
│   └── fishing_math.dart                 # Preserved existing reflex/timing logic
├── components/
│   ├── environment/
│   │   ├── dynamic_environment.dart      # Coordinator component grouping all environment layers
│   │   ├── sky_component.dart            # Procedural gradient sky reacting dynamically to WeatherState
│   │   ├── cloud_component.dart          # Procedural drifting clouds (multi-tiered, weather-tinted, auto-wrapping)
│   │   ├── pine_forest_component.dart    # Multi-layered parallax pine tree silhouettes with atmospheric depth
│   │   ├── river_bank_component.dart     # Pixel-styled riverbank/terrain cross-section and shoreline
│   │   └── water_surface_component.dart  # Animated procedural water body with sine/cosine waves, ripples & depth gradient
│   ├── rain.dart                         # WeatherState-reactive rain particle component
│   ├── character.dart                    # Preserved/adapted for R2
│   └── bobber.dart                       # Preserved/adapted for R2
├── game/
│   ├── monsoon_game.dart                 # FlameGame subclass configuring CameraComponent.withFixedResolution(640, 360) and MonsoonWorld
│   └── monsoon_world.dart                # World container hosting DynamicEnvironment and interactive entities
├── ui/
│   └── weather_controls_overlay.dart     # Flutter HUD overlay with cozy buttons/slider to toggle weather states
└── main.dart                             # Clean entry point hosting GameWidget with letterbox background color & HUD overlays
```

### 4.2 Recommended Test Suite Layout for test/
```
test/
├── fishing_math_test.dart                # Existing tests (preserved)
├── viewport_test.dart                    # Tests verifying FixedResolutionViewport calculations, aspect ratio lock, and letterboxing math
├── weather_state_test.dart               # Tests verifying weather parameter transitions, color lerping, and clamping
├── wave_generator_test.dart              # Unit tests for wave height calculation, ensuring continuity and zero NaN/inf values
└── dynamic_environment_test.dart         # Flame component tests verifying mounting, sizing (640x360), and child layer ordering
```

### 4.3 Proposed Implementation Steps for Builder Agent
1. **Create `lib/config/game_config.dart`**: Define virtual resolution (`Vector2(640, 360)`), aspect ratio (`16 / 9`), and component priority/z-indices.
2. **Create `lib/models/weather_state.dart`**: Implement `WeatherState` with weather conditions (`clear`, `overcast`, `monsoon`), reactive parameters (`rainIntensity`, `windSpeed`, `overcast`, `waveAmplitude`), and lerp transitions.
3. **Create `lib/logic/wave_generator.dart`**: Pure Dart wave calculation for water simulation.
4. **Create `lib/components/environment/`**:
   - `sky_component.dart`: Canvas linear gradient sky modulated by `WeatherState`.
   - `cloud_component.dart`: Procedural cloud geometry with drift and wrap.
   - `pine_forest_component.dart`: Procedural layered pine tree silhouettes (distant misty mountains, mid pine silhouettes, near forest).
   - `river_bank_component.dart`: Left-side embankment with grass, layered damp peat earth, and shoreline foam.
   - `water_surface_component.dart`: Multi-layer water surface with wave displacement path and depth gradient fill.
   - `dynamic_environment.dart`: Ties all environment components together.
5. **Update `lib/game/monsoon_game.dart` & `monsoon_world.dart`**:
   - Initialize `FlameGame` with `CameraComponent.withFixedResolution(width: 640, height: 360, world: MonsoonWorld())`.
   - Set `camera.viewfinder.anchor = Anchor.topLeft;`.
   - Set background letterbox color to `#0D151D`.
6. **Update `lib/ui/weather_controls_overlay.dart`**: Provide interactive weather switcher (Clear / Overcast / Monsoon) so the user can easily observe and verify dynamic environment shifts.
7. **Write Unit & Component Tests in `test/`**:
   - Verify viewport math and letterboxing across 16:9, 4:3, and 9:16 aspect ratios.
   - Verify `WeatherState` transitions.
   - Verify `WaveGenerator` determinism and bounds.
8. **Run Verification Commands**:
   - `flutter test`
   - `flutter analyze`
   - `flutter build web`

---

## 5. Verification Method

To verify these findings independently:

1. **Static Analysis**:
   ```bash
   flutter analyze
   ```
   *Expected outcome*: `No issues found!`.

2. **Automated Unit Tests**:
   ```bash
   flutter test
   ```
   *Expected outcome*: `All tests passed!`.

3. **Web Build Target**:
   ```bash
   flutter build web
   ```
   *Expected outcome*: Clean compilation producing `build/web` with exit code 0.

4. **Code Inspection**:
   - Inspect `lib/components/parallax_background.dart:10-14` to confirm static background image dependency.
   - Inspect `lib/main.dart:17-68` to confirm missing fixed-resolution camera and viewport setup.
   - Inspect Flame's `FixedResolutionViewport` at `C:\Users\Dibya\AppData\Local\Pub\Cache\hosted\pub.dev\flame-1.37.0\lib\src\camera\viewports\fixed_resolution_viewport.dart` to confirm built-in letterboxing support.

### Invalidation Conditions
- Flame SDK version changed from 1.37.0 to an incompatible major version.
- Flutter SDK broken or cannot compile web targets.
