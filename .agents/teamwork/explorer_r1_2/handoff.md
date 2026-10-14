# Viewport & Resolution Architecture Analysis for Flame (Requirement R1)

**Agent**: `explorer_r1_2`  
**Date**: 2026-10-13  
**Status**: Complete  

---

## 1. Observation

### Codebase & Configuration Observations
- **Flame Version**: `pubspec.yaml` (line 37) specifies `flame: ^1.37.0`.
- **Existing Game Structure**:
  - `lib/main.dart` (lines 17–23) defines `MonsoonGame extends FlameGame with TapCallbacks` with no `World` or `CameraComponent` declared:
    ```dart
    class MonsoonGame extends FlameGame with TapCallbacks {
      BobberComponent? currentBobber;
      late RainComponent rain;
      late ParallaxBackground background;
      ...
    ```
  - `lib/main.dart` (lines 37–46) adds components directly to the `FlameGame` instance (`add(background)`, `add(rain)`, `add(character)`).
  - `lib/components/parallax_background.dart` (lines 11–14) stretches the background sprite directly across raw canvas dimensions:
    ```dart
    add(SpriteComponent(
      sprite: bgSprite,
      size: game.size,
    ));
    ```
  - `lib/main.dart` (line 131) computes hitboxes based on raw unscaled game size:
    ```dart
    if (event.localPosition.x > size.x * 0.3 && event.localPosition.y > size.y * 0.6)
    ```
- **Observed Deficiency**:
  On browser or desktop window resize, `game.size` directly tracks the physical window size. Consequently, sprites and layouts stretch horizontally or vertically, violating the non-distortion requirement of R1.
- **Flame Engine 1.37 Camera System**:
  - `CameraComponent.withFixedResolution({required double width, required double height, World? world})` instantiates a `FixedResolutionViewport(resolution: Vector2(width, height))`.
  - `CameraComponent.viewfinder.anchor` defaults to `Anchor.center` and `viewfinder.position` defaults to `Vector2.zero()`.
  - `camera.globalToLocal(Vector2 point)` transforms raw Flutter canvas coordinates into virtual world coordinates.
  - Flame's `FixedResolutionViewport` handles canvas scaling, centering, and clipping internally during the render pipeline, filling outer margins with `FlameGame.backgroundColor()`.

---

## 2. Logic Chain

### 2.1 Viewport & Camera Mechanics in Flame 1.37
1. Flame's modern camera architecture decouples the scene into three distinct tiers:
   - **`FlameGame`**: The root engine runner managing the game loop and render canvas.
   - **`World`**: The logical domain where gameplay entities, scenery, and dynamic canvas renderers live.
   - **`CameraComponent`**: The observer composed of a **`Viewport`** (defining the screen window/projection rect) and a **`Viewfinder`** (defining the zoom, position, and anchor).
2. When configured with `CameraComponent.withFixedResolution(width: W, height: H, world: world)`:
   - A `FixedResolutionViewport` is attached with internal virtual resolution `Vector2(W, H)`.
   - On canvas resize (`onGameResize(newSize)`), the viewport computes uniform scale:
     $$\text{scale} = \min\left(\frac{\text{newSize}.x}{W}, \frac{\text{newSize}.y}{H}\right)$$
   - The rendered viewport size is $\text{scaledSize} = (W \cdot \text{scale}, H \cdot \text{scale})$.
   - The letterbox/pillarbox offset is:
     $$\text{offset} = \frac{\text{newSize} - \text{scaledSize}}{2}$$
   - The canvas is clipped to `Rect.fromLTWH(offset.x, offset.y, scaledSize.x, scaledSize.y)`.
   - **Pillarboxing** occurs when the window aspect ratio is wider than 16:9 ($\text{offset}.x > 0$, vertical black bars on left/right).
   - **Letterboxing** occurs when the window aspect ratio is taller than 16:9 ($\text{offset}.y > 0$, horizontal black bars on top/bottom).
   - The background color of the letterbox margin is controlled cleanly by `FlameGame.backgroundColor()`.
3. **The Viewfinder Anchor Nuance**:
   - By default, Flame's `viewfinder.anchor` is `Anchor.center`. This positions virtual coordinate `(0, 0)` at the viewport center, with bounds spanning `(-W/2, -H/2)` to `(W/2, H/2)`.
   - For 2D canvas drawing (sky gradients, riverbanks, water waves) where top-left origin `(0, 0)` to `(W, H)` is standard, the camera viewfinder must be explicitly set:
     ```dart
     camera.viewfinder.anchor = Anchor.topLeft;
     camera.viewfinder.position = Vector2.zero();
     ```
   - This ensures top-left is `(0, 0)` and bottom-right is `(W, H)` in world coordinates.

### 2.2 Virtual Resolution Analysis & Recommendation

| Resolution | Aspect Ratio | Integer Scale Targets | Vertical Real Estate | Cozy Pixel-Art Suitability | Verdict |
|---|---|---|---|---|---|
| **320 x 180** | 16:9 | 720p (4x), 1080p (6x), 1440p (8x), 4K (12x) | 180 px (Very constrained) | Ultra-chunky, but procedural layers (sky, pines, bank, waves) crowd each other. UI text takes large % of screen. | Viable for extreme low-res, but tight for procedural depth. |
| **480 x 270** | 16:9 | 1080p (4x), 4K (8x) | 270 px (Moderate) | Good, but non-integer scale to 720p (2.666x) and 1440p (5.333x), risking subpixel distortion on laptops. | Suboptimal multi-screen scaling. |
| **640 x 360** | 16:9 | 720p (2x), 1080p (3x), 1440p (4x), 4K (6x) | 360 px (Ideal) | Perfect balance: crisp 3x integer scaling on standard 1080p FHD, ample room for 4 procedural layers and font readability. | **RECOMMENDED PRIMARY CHOICE** |

**Why 640 x 360 is Recommended**:
1. **Flawless Multi-Screen Integer Scaling**:
   - 1280x720 (720p HD / standard laptop / web embed): exactly **2x** integer scale.
   - 1920x1080 (1080p Full HD / standard desktop): exactly **3x** integer scale (creates authentic 3x3 pixel clusters).
   - 2560x1440 (1440p QHD / gaming monitors): exactly **4x** integer scale.
   - 3840x2160 (4K UHD): exactly **6x** integer scale.
2. **Layer Budgeting for Dynamic Environment**:
   360 vertical pixels provides clean vertical separation for the procedural canvas renderers:
   - `SkyComponent` & Clouds: `y = 0` to `y = 160` (160 px for rich atmospheric gradient).
   - `PineTreeSilhouettes`: `y = 100` to `y = 210` (110 px of multi-depth pine tree silhouettes).
   - `RiverBankComponent`: `y = 190` to `y = 240` (50 px for grassy slope and perch).
   - `WaterSurfaceComponent`: `y = 230` to `y = 360` (130 px of deep water, wave ripples, and bobber interaction).
3. **Typography & Sprites**:
   - `PressStart2P` font at `fontSize: 8` or `10` renders crisply with perfect legibility without obscuring the scenery.
   - Sprites (rabbit character at ~64–80 px, bobber at ~24–32 px) fit naturally into the scene scale.

### 2.3 Input & Coordinate Transformation
1. When input events occur, Flutter provides raw screen pixels.
2. If components reside in `World with TapCallbacks`, Flame's event dispatcher runs `camera.globalToLocal` automatically: `event.localPosition` receives virtual world coordinates `[0..640, 0..360]`.
3. If an input event occurs within the letterbox/pillarbox margins, the mapped point falls outside `[0..640, 0..360]`, preventing unintended casts outside the active game canvas.

---

## 3. Caveats
1. **Asset Dimensions vs Virtual Canvas**: Existing sprite placeholders (`size = Vector2(300, 300)` in `character.dart`) were sized for an arbitrary unconstrained window. When implementing R1 and subsequent phases, sprite sizes should be normalized to the 640x360 virtual grid (e.g., character size `Vector2(64, 64)` or `Vector2(80, 80)`).
2. **HUD Placement**: UI components can be placed either in `World` (if camera is static) or added directly to `camera.viewport` via `camera.viewport.add(...)`. For a static fishing game, adding to `World` at top-left coordinates is straightforward; if camera panning is ever introduced in later milestones, HUD components should reside in `camera.viewport`.
3. **Letterbox Color**: By default, `FlameGame.backgroundColor()` renders black. We recommend `const Color(0xFF0F172A)` (cozy dark slate) or `const Color(0xFF1B2A36)` to maintain aesthetic cohesion during letterboxing.

---

## 4. Conclusion

### Final Architecture Design
- **Virtual Resolution**: `640 x 360` with aspect ratio lock (16:9).
- **Flame Camera Setup**: `CameraComponent.withFixedResolution(width: 640, height: 360, world: world)` with `camera.viewfinder.anchor = Anchor.topLeft;`.
- **Component Placement**: All gameplay and procedural environment components (`SkyComponent`, `CloudComponent`, `PineTreeSilhouettes`, `RiverBankComponent`, `WaterSurfaceComponent`) are added as children of `World`, ensuring aspect ratio preservation and letterboxing.
- **Zero Warp / Stretch Guarantee**: `FixedResolutionViewport` enforces uniform scaling ($\min(s_x, s_y)$) with automatic pillarboxing/letterboxing on Web and desktop.

### Code Blueprint 1: Game & World Architecture (`lib/main.dart` or `lib/game/monsoon_game.dart`)

```dart
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

/// Logical Virtual Resolution Constants (16:9 Aspect Ratio)
class GameResolution {
  static const double virtualWidth = 640.0;
  static const double virtualHeight = 360.0;
  static final Vector2 size = Vector2(virtualWidth, virtualHeight);
}

/// World containing all dynamic canvas environment components
class MonsoonWorld extends World with TapCallbacks {
  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    // Add procedural environment renderers here:
    // await add(SkyComponent());
    // await add(CloudComponent());
    // await add(PineTreeSilhouettesComponent());
    // await add(RiverBankComponent());
    // await add(WaterSurfaceComponent());
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    final pos = event.localPosition; // Guaranteed [0..640, 0..360] virtual space
    
    // Check if tap falls within water interactive zone
    if (pos.x >= 200 && pos.x <= 640 && pos.y >= 230 && pos.y <= 360) {
      // Valid cast in water area
    }
  }
}

/// Root FlameGame configured with FixedResolutionViewport
class MonsoonGame extends FlameGame<MonsoonWorld> {
  MonsoonGame()
      : super(
          world: MonsoonWorld(),
          camera: CameraComponent.withFixedResolution(
            width: GameResolution.virtualWidth,
            height: GameResolution.virtualHeight,
          ),
        );

  @override
  Color backgroundColor() => const Color(0xFF0F172A); // Deep slate letterbox margin

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Ensure virtual origin (0, 0) matches top-left corner
    camera.viewfinder.anchor = Anchor.topLeft;
    camera.viewfinder.position = Vector2.zero();

    // HUD Elements can be added to camera.viewport or world
    final feedbackText = TextComponent(
      text: 'Tap water to cast!',
      position: Vector2(GameResolution.virtualWidth / 2, 24),
      anchor: Anchor.topCenter,
      textRenderer: TextPaint(
        style: const TextStyle(
          fontFamily: 'PressStart2P',
          color: Colors.white,
          fontSize: 10,
          shadows: [
            Shadow(blurRadius: 2.0, color: Colors.black54, offset: Offset(1.5, 1.5)),
          ],
        ),
      ),
    );
    world.add(feedbackText);
  }
}
```

---

## 5. Verification Method

### 5.1 Headless / GPU-Free Unit Test Blueprint
Flame's `CameraComponent`, `FixedResolutionViewport`, and coordinate projection functions do not require a physical GPU or screen. They execute deterministically under `flutter test`.

Here is the exact verification test file blueprint to implement at `test/viewport_test.dart`:

```dart
import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monsoon_catch/main.dart'; // Or designated game file

void main() {
  group('Viewport & Resolution Architecture Tests', () {
    late MonsoonGame game;

    setUp(() {
      game = MonsoonGame();
    });

    test('Camera is configured with FixedResolutionViewport of 640x360', () async {
      await game.onLoad();
      
      expect(game.camera.viewport, isA<FixedResolutionViewport>());
      final viewport = game.camera.viewport as FixedResolutionViewport;
      expect(viewport.resolution.x, equals(640.0));
      expect(viewport.resolution.y, equals(360.0));
      expect(game.camera.viewfinder.anchor, equals(Anchor.topLeft));
    });

    test('Aspect ratio scaling on 1080p (1920x1080 - exact 16:9)', () async {
      await game.onLoad();
      game.onGameResize(Vector2(1920, 1080));

      final viewport = game.camera.viewport as FixedResolutionViewport;
      // 1920 / 640 = 3.0, 1080 / 360 = 3.0
      expect(viewport.scale, equals(3.0));
      
      // Screen center (960, 540) maps to virtual center (320, 180)
      final virtualCenter = game.camera.globalToLocal(Vector2(960, 540));
      expect(virtualCenter.x, closeTo(320.0, 0.001));
      expect(virtualCenter.y, closeTo(180.0, 0.001));

      // Screen origin (0, 0) maps to virtual origin (0, 0)
      final virtualOrigin = game.camera.globalToLocal(Vector2(0, 0));
      expect(virtualOrigin.x, closeTo(0.0, 0.001));
      expect(virtualOrigin.y, closeTo(0.0, 0.001));
    });

    test('Aspect ratio scaling on Ultrawide (2560x1080 - 21:9 pillarboxed)', () async {
      await game.onLoad();
      game.onGameResize(Vector2(2560, 1080));

      final viewport = game.camera.viewport as FixedResolutionViewport;
      // Scale constrained by height: 1080 / 360 = 3.0
      expect(viewport.scale, equals(3.0));

      // Active viewport width = 640 * 3.0 = 1920
      // Left pillarbox width = (2560 - 1920) / 2 = 320
      // Left edge of active area (320, 0) maps to virtual (0, 0)
      final leftActiveEdge = game.camera.globalToLocal(Vector2(320, 0));
      expect(leftActiveEdge.x, closeTo(0.0, 0.001));
      expect(leftActiveEdge.y, closeTo(0.0, 0.001));

      // Right edge of active area (2240, 1080) maps to virtual (640, 360)
      final rightActiveEdge = game.camera.globalToLocal(Vector2(2240, 1080));
      expect(rightActiveEdge.x, closeTo(640.0, 0.001));
      expect(rightActiveEdge.y, closeTo(360.0, 0.001));

      // A click inside the left pillarbox bar (x < 320) maps to negative virtual coordinate
      final clickInPillarbox = game.camera.globalToLocal(Vector2(100, 540));
      expect(clickInPillarbox.x, lessThan(0.0));
    });

    test('Aspect ratio scaling on Mobile Portrait (1080x1920 - 9:16 letterboxed)', () async {
      await game.onLoad();
      game.onGameResize(Vector2(1080, 1920));

      final viewport = game.camera.viewport as FixedResolutionViewport;
      // Scale constrained by width: 1080 / 640 = 1.6875
      expect(viewport.scale, closeTo(1.6875, 0.001));

      // Scaled height = 360 * 1.6875 = 607.5
      // Top letterbox margin = (1920 - 607.5) / 2 = 656.25
      final topActiveEdge = game.camera.globalToLocal(Vector2(0, 656.25));
      expect(topActiveEdge.x, closeTo(0.0, 0.001));
      expect(topActiveEdge.y, closeTo(0.0, 0.001));

      // Click in top letterbox margin (y < 656.25) maps to negative virtual coordinate
      final clickInLetterbox = game.camera.globalToLocal(Vector2(540, 200));
      expect(clickInLetterbox.y, lessThan(0.0));
    });

    test('Round-trip coordinate transformation fidelity', () async {
      await game.onLoad();
      game.onGameResize(Vector2(1920, 1080));

      final testVirtualPoint = Vector2(150.0, 250.0);
      final globalPoint = game.camera.localToGlobal(testVirtualPoint);
      final revertedVirtualPoint = game.camera.globalToLocal(globalPoint);

      expect(revertedVirtualPoint.x, closeTo(testVirtualPoint.x, 0.001));
      expect(revertedVirtualPoint.y, closeTo(testVirtualPoint.y, 0.001));
    });
  });
}
```

### 5.2 Verification Commands
- **Run Unit Tests**: `flutter test test/viewport_test.dart`
- **Run Static Analysis**: `flutter analyze`
- **Web Compilation Check**: `flutter build web --no-pub`

### 5.3 Invalidation Conditions
- Any changes to `GameResolution.virtualWidth` or `virtualHeight` that deviate from 16:9 ratio.
- Omitting `camera.viewfinder.anchor = Anchor.topLeft;`, which causes the world origin to shift to viewport center `(320, 180)`.
- Adding visual components directly to `FlameGame` rather than `World`.
