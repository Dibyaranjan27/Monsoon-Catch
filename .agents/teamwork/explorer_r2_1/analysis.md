# Codebase & Environment Alignment Analysis: Character, Rod & Riverbank Anchoring

**Author**: Explorer 1 (`explorer_r2_1`)  
**Date**: 2026-10-14  
**Project**: Monsoon Catch (Flutter / Flame)  
**Milestone**: Release 2 (R2 — Procedural Character, Rod & Physics-Aware Fishing Line)  
**Scope Reference**: `.agents/teamwork/orchestrator_r2/SCOPE.md`  

---

## 1. Executive Summary

This investigation establishes the exact mathematical, geometrical, and architectural alignment between the completed R1 dynamic environment and the incoming R2 procedural character, rod, and physics-aware fishing line systems.

Key conclusions:
1. **Character Riverbank Anchor**: Ground elevation on the riverbank plateau is mathematically flat at $Y = 208.8\text{ px}$ from $X = 0.0$ to $X = 133.12\text{ px}$. The optimal character anchor point is $(X = 118.0\text{ px}, Y = 208.8\text{ px})$ with `Anchor.bottomCenter`, situating the fisher stably on the grassy turf ledge 15 px back from the downward shoreline slope.
2. **Water Surface Bounds & Bobber Resting Zone**: Water begins at $X = 192.0\text{ px}$ with mean waterline at $Y = 234.0\text{ px}$ (dynamic wave bounds $Y \in [223.8, 244.2]$ in peak monsoon). The safe, natural bobber casting zone in the 2.5D foreshortened pond is $X \in [225.0, 600.0\text{ px}]$ and $Y \in [234.0, 345.0\text{ px}]$.
3. **Component Hierarchy & Rendering Order**: All direct world children must follow strict priority z-ordering: `DynamicEnvironment` (priority 0, containing sky 10, clouds 20, forest 30-50, bank 60, water 70) $\to$ `BobberComponent` (priority 75) $\to$ `FishingLineComponent` (priority 78) $\to$ `CharacterComponent` (priority 80) $\to$ `RainComponent` (priority 90) $\to$ `feedbackText` (priority 100).
4. **Decoupling Line & Reset Lifecycle**: Fishing line rendering should be extracted from `MonsoonWorld.render()` into a dedicated `FishingLineComponent` to eliminate canvas bleeding, and an explicit `reset()` lifecycle method must be introduced to cleanly retract and remove the bobber upon catch/miss.

---

## 2. Existing Viewport & Environment Architecture

### 2.1 Viewport Configuration
- **Virtual Resolution**: $640.0 \times 360.0$ virtual pixels (16:9 fixed aspect ratio), defined in `lib/config/game_config.dart`.
- **Letterbox Color**: `Color(0xFF0F172A)` (deep slate).
- **Camera & Viewport Setup**: In `lib/game/monsoon_game.dart`:
  ```dart
  camera: CameraComponent.withFixedResolution(
    width: GameConfig.virtualWidth,
    height: GameConfig.virtualHeight,
  )
  camera.viewfinder.anchor = Anchor.topLeft;
  camera.viewfinder.position = Vector2.zero();
  ```
  - This ensures virtual origin $(0, 0)$ maps directly to the top-left of the viewport with zero offset.
  - Scale factor scales uniformly with letterboxing/pillarboxing across all display aspect ratios.

### 2.2 Environment Layers & Priority Hierarchy
In `lib/components/environment/dynamic_environment.dart`, the environment layers are mounted as children of `DynamicEnvironment` (world priority 0):

| Layer Component | Class | Size | Priority in `DynamicEnvironment` | Description |
|---|---|---|---|---|
| Sky | `SkyComponent` | $640 \times 360$ | `GameConfig.prioritySky` (10) | 4-stop procedural vertical linear gradient with lightning flash |
| Clouds | `CloudLayerComponent` | $640 \times 360$ | `GameConfig.priorityClouds` (20) | 5 wrapped procedural clouds drifting with wind speed |
| Pine Forest | `PineForestComponent` | $640 \times 360$ | `GameConfig.priorityFarPines` (30) | 3 ridge silhouettes: Far (30, baseY 208.8), Mid (40, baseY 223.2), Bank (50, baseY 234.0) |
| Riverbank | `RiverBankComponent` | $640 \times 360$ | `GameConfig.priorityRiverBank` (60) | Peat soil cross-section, grassy turf cap, shoreline foam line |
| Water Surface | `WaterSurfaceComponent` | $640 \times 360$ | `GameConfig.priorityWaterSurface` (70) | Multi-harmonic wave contour, 3-stop depth gradient, raindrop ripples |

---

## 3. Riverbank Geometry & Character Anchoring Point

### 3.1 Mathematical Geometry of `RiverBankComponent`
Extracted directly from `lib/components/environment/river_bank_component.dart` (lines 51–106):
- Total virtual dimensions: `size.x = 640.0`, `size.y = 360.0`.
- Riverbank width: $\text{bankWidth} = \text{size.x} \times 0.32 = 204.8\text{ px}$.
- Grassy plateau elevation: $\text{bankPlatformY} = \text{size.y} \times 0.58 = 208.8\text{ px}$.
- Water contact elevation: $\text{waterContactY} = \text{size.y} \times 0.65 = 234.0\text{ px}$.

#### Path Segment Breakdown:
1. **Grassy Turf Cap (`_turfPath`)**:
   - `moveTo(0, 208.8)`
   - `lineTo(133.12, 208.8)` (horizontal span: $X \in [0.0, 133.12]$ at $Y = 208.8$)
   - `cubicTo(167.936, 208.8, 151.552, 220.8, 180.224, 222.8)` (sloping turf lip down to $Y = 222.8$)
   - `lineTo(167.936, 226.8)`
   - `lineTo(0, 224.8)` (turf thickness is 16 px at left edge)
2. **Peat Soil Substrate (`_soilPath`)**:
   - Extends under the turf and drops down to the waterline contact at $(204.8, 234.0)$.
   - Fills down to viewport bottom $(204.8, 360.0) \to (0, 360.0)$.
3. **Shoreline Foam Strip**:
   - Line segment from `_foamStart = Offset(196.8, 234.0)` to `_foamEnd = Offset(208.8, 236.0)`.

```
Y (px)
 0 +-------------------------------------------------------------------------+
   | (Sky & Clouds)                                                          |
   |                                                                         |
150|                         Far/Mid Pines                                   |
   | [Flat Turf Plateau]                                                     |
208|=====================\ (Crest at X=133.12)                               |
   |                      \                                                  |
   |      Peat Soil        \ (Slope)            Waterline (Y=234.0)          |
234|                        \================================================|
   |                         (X=204.8)                                       |
   |                                            Water Body / Pond            |
360+-------------------------------------------------------------------------+
   0                   133.12    204.8                                     640
                                  X (px)
```

### 3.2 Evaluation of Existing `CharacterPlaceholder`
In `lib/components/character.dart`:
```dart
CharacterPlaceholder()
    : super(
        size: Vector2(80, 80),
        position: Vector2(35, 138),
        priority: GameConfig.priorityCharacter,
      );
```
- **Issues with existing placeholder**:
  1. `position` is $(35, 138)$ with default `Anchor.topLeft`. The bottom edge is at $138 + 80 = 218\text{ px}$, sinking $9.2\text{ px}$ beneath the turf platform ($Y = 208.8$).
  2. $X = 35$ is positioned $98\text{ px}$ back from the edge of the bank ($X = 133.12$). This causes the character to stand far back in the trees rather than perched near the river.
  3. The placeholder relies on bitmap sprites (`character_idle.png`, etc.) which violates R2's procedural canvas constraint.

### 3.3 Recommended Character Anchoring
- **Anchor Mode**: `Anchor.bottomCenter`.
- **Ground Coordinates**:
  $$\mathbf{P}_{\text{ground}} = (X = 118.0\text{ px},\; Y = 208.8\text{ px})$$
- **Rationale**:
  - $X = 118.0$ places the character on the flat, solid turf platform ($0 \le X \le 133.12$), safely 15 px back from the steep slope.
  - $Y = 208.8$ aligns the character's feet / sitting seat directly with the grassy turf surface.
  - Facing direction: Rightwards ($+X$ axis toward the river).
  - When the character sits or stands at $X = 118$, their fishing rod extends over the edge ($X \approx 135$ to $190$), naturally projecting over the shoreline slope and out towards the water.

---

## 4. Water Surface Bounds & Bobber Resting Zone

### 4.1 Water Surface Geometry in `WaterSurfaceComponent`
Extracted from `lib/components/environment/water_surface_component.dart`:
- Waterline origin: $X_{\text{start}} = \text{size.x} \times 0.30 = 192.0\text{ px}$.
- Mean waterline elevation: $Y_{\text{base}} = \text{size.y} \times 0.65 = 234.0\text{ px}$.
- Horizontal extent: $X \in [192.0, 640.0\text{ px}]$.
- Vertical extent: $Y \in [Y_{\text{wave}}(x, t), 360.0\text{ px}]$.
- Linear gradient depth stops:
  - Stop 0.00 at $Y = 234.0$ (Surface color, e.g. `0xFF38A3A5` on clear day).
  - Stop 0.40 at $Y = 284.4$ (Mid-depth color, e.g. `0xFF22577A`).
  - Stop 1.00 at $Y = 360.0$ (Abyss color, e.g. `0xFF0F1E29`).

### 4.2 Wave Dynamics & Waterline Displacement
Wave elevation is computed by `WaveGenerator`:
$$Y(x, t) = 234.0 + \sum_{k=1}^3 A_k \cdot \text{turb} \cdot \sin\left(\frac{2\pi}{\lambda_k} x - \omega_k t + \phi_k\right)$$
- `theoreticalMaxAmplitude` $= 2.5 + 1.2 + 0.5 = 4.2\text{ px}$ per unit turbulence.
- Peak displacement ranges by weather:
  - **Clear Day** ($\text{turb} = 0.475$): Waterline bounds $Y \in [232.0, 236.0\text{ px}]$ ($\pm 2.0\text{ px}$).
  - **Monsoon Storm** ($\text{turb} = 2.44$): Waterline bounds $Y \in [223.8, 244.2\text{ px}]$ ($\pm 10.2\text{ px}$).

### 4.3 2.5D Foreshortened Perspective & Bobber Resting Zone
The pond surface represents a 2.5D perspective viewing plane spanning from the background waterline ($Y \approx 234$) to the foreground bottom edge ($Y = 360$). Raindrop impact ripples are spawned in $X \in [192.0, 640.0]$ and $Y \in [234.0, 349.2]$ with elliptical ratio $R_y / R_x = 0.35$.

#### Valid Bobber Landing Coordinates:
- **Horizontal Bounds ($X$)**:
  - $X_{\text{min}} = 225.0\text{ px}$ (20 px clear of the riverbank contact at $204.8$).
  - $X_{\text{max}} = 600.0\text{ px}$ (40 px margin before the screen edge at $640.0$).
  - Sweet spot / default cast target: $X \approx 320.0$ to $460.0\text{ px}$.
- **Vertical Bounds ($Y$)**:
  - $Y_{\text{min}} = 234.0\text{ px}$ (or dynamic waterline $234.0 + \Delta Y_{\text{wave}}$).
  - $Y_{\text{max}} = 340.0\text{ px}$ (20 px margin before bottom edge).
  - Sweet spot / default cast target: $Y \approx 260.0$ to $310.0\text{ px}$.

#### Bobber Rest & Wave Synchronization:
When floating at target $(X_B, Y_B)$, the bobber component should apply a gentle float bob:
$$Y_{\text{float}}(t) = Y_B + A_{\text{bob}} \sin(2.5 t)$$
During a bite, the bobber dips sharply downward:
$$Y_{\text{bite}} = Y_B + 10.0\text{ px}$$

---

## 5. Mathematical Modeling of Character States & Rod Tip

### 5.1 Analytical Rod Tip Formulation
To strictly fulfill the requirement that the fishing line originates from the exact rod tip with zero floating or misaligned canvas artifacts, the rod tip must be an explicit mathematical function of:
1. Ground anchor $\mathbf{P}_{\text{ground}} = (118.0, 208.8)$.
2. Character state $S \in \{\text{idle}, \text{casting}, \text{reeling}, \text{caught}\}$.
3. Animation time / progress parameter $t \in [0.0, 1.0]$.

### 5.2 State Coordinate Parameters (Base $\mathbf{P}_{\text{ground}} = (118.0, 208.8)$)

| State | Character Pose | Hand Position $(X_H, Y_H)$ | Rod Angle ($\theta$) | Rod Path / Flex Geometry | Rod Tip Position $(X_T, Y_T)$ | Line Tension |
|---|---|---|---|---|---|---|
| **`idle`** | Relaxed on grassy bank | $(128.0, 186.0)$ | $-45^\circ$ upward | Straight / subtle sag ($L = 60$) | $(170.4, 143.6)$ | $0.0$ (slack sag) |
| **`casting`** (arc $t \in [0, 1]$) | Whip forward arc | $(134.0, 188.0)$ | $-18^\circ$ forward | Dynamic flex curve bowing backwards | $(192.9, 168.8)$ | Dynamic ($0.5 \to 0.2$) |
| **`reeling`** / **`strain`** | Braced backwards | $(124.0, 188.0)$ | $-30^\circ$ at base | Parabolic downward bend (tip tangent $+35^\circ$) | $(168.0, 182.0)$ | $1.0$ (taut line) |
| **`caught`** | Celebratory upright | $(126.0, 172.0)$ | $-75^\circ$ raised | Upward slight curve | $(141.0, 116.0)$ | Retracted / dangling catch |

#### Analytical Rod Geometry:
- **Rod Base**: Starts at character hand $(X_H, Y_H)$.
- **Rod Body**: Rendered via `canvas.drawPath` using a quadratic/cubic bezier from $(X_H, Y_H)$ to $(X_T, Y_T)$:
  - In `idle`: Control point along chord with 1 px gravity sag.
  - In `reeling`: Parabolic bend with control point pulled forward and downward:
    $\mathbf{P}_{\text{ctrl}} = (X_H + 35, Y_H - 25)$.
  - In `casting`: Control point pulled backward against cast direction to represent rod flex inertia.

---

## 6. Physics-Aware Fishing Line Math

### 6.1 Catenary / Bezier Approximation
The fishing line connects rod tip $\mathbf{P}_T = (X_T, Y_T)$ to bobber $\mathbf{P}_B = (X_B, Y_B)$.

A quadratic bezier curve provides an exact parabolic approximation to the catenary curve:
$$\mathbf{B}(u) = (1 - u)^2 \mathbf{P}_T + 2(1 - u)u \mathbf{P}_C + u^2 \mathbf{P}_B \quad (u \in [0, 1])$$

The control point $\mathbf{P}_C$ is calculated analytically:
$$\mathbf{P}_{\text{mid}} = \frac{\mathbf{P}_T + \mathbf{P}_B}{2}$$
$$\text{sagAmount} = \text{maxSag} \times (1.0 - \text{tension}) \times \min\left(1.0, \frac{\|\mathbf{P}_B - \mathbf{P}_T\|}{200.0}\right)$$
$$\mathbf{P}_C = \left(X_{\text{mid}} + \Delta X_{\text{wind}},\; Y_{\text{mid}} + \text{sagAmount}\right)$$

Where:
- $\text{maxSag} \approx 28.0\text{ px}$.
- $\text{tension} \in [0.0, 1.0]$:
  - At $\text{tension} = 0.0$ (`idle`): $\text{sagAmount} = 28.0\text{ px}$ (full catenary slack).
  - At $\text{tension} = 1.0$ (`reeling`): $\text{sagAmount} = 0.0\text{ px}$ ($\mathbf{P}_C = \mathbf{P}_{\text{mid}}$, degenerating to a straight taut line).
- Wind deflection: $\Delta X_{\text{wind}} = \text{windSpeed} \times 8.0 \times (1.0 - \text{tension})$.

### 6.2 Casting Trajectory
During casting ($t_{\text{cast}} \in [0.0, 1.0]$):
- Bobber flies along a parabolic arc:
  $$X_B(t) = \text{lerp}(X_T, X_{\text{target}}, t)$$
  $$Y_B(t) = \text{lerp}(Y_T, Y_{\text{target}}, t) - 4 \cdot h_{\text{arc}} \cdot t(1 - t)$$
  with arc peak height $h_{\text{arc}} \approx 45.0\text{ px}$.
- The line dynamically connects the moving rod tip to the airborne bobber.

---

## 7. Retraction, Reset & Game Loop Integration

### 7.1 Existing Lifecycle Issues
In `lib/game/monsoon_world.dart`:
```dart
if (currentBobber != null && _isFishing) {
  // render line
}
```
When `_isFishing` is set to `false` (on catch or miss):
1. The line instantly stops rendering.
2. The bobber component remains in `MonsoonWorld` children list indefinitely until another tap occurs.
3. During this time, the bobber sits floating (or jumped) in the pond with no line connected to the rod tip.

### 7.2 Recommended Clean Lifecycle
1. Introduce an explicit `resetFishingState()` method:
   - Sets character state back to `idle`.
   - Removes active `BobberComponent` from `MonsoonWorld`.
   - Clears active fishing line path.
   - Resets state flags.
2. For caught fish:
   - Play brief celebratory animation (character in `caught` state, rod raised high, fish dangling at end of short line).
   - After brief timer (e.g. 1.2s), call `resetFishingState()`.
3. For missed strike:
   - Bobber and line snap back immediately, clearing canvas artifacts.

---

## 8. Flame Component Hierarchy & Z-Order Priority Recommendations

To ensure zero visual clipping and clean layering without disturbing R1 components:

```
MonsoonGame
  └── CameraComponent.withFixedResolution(640, 360)
        └── MonsoonWorld
              ├── DynamicEnvironment [priority: 0]
              │     ├── SkyComponent [priority: 10]
              │     ├── CloudLayerComponent [priority: 20]
              │     ├── PineForestComponent [priority: 30]
              │     │     ├── Far Pines [priority: 30]
              │     │     ├── Mid Pines [priority: 40]
              │     │     └── Bank Trees [priority: 50]
              │     ├── RiverBankComponent [priority: 60]
              │     └── WaterSurfaceComponent [priority: 70]
              ├── BobberComponent [priority: 75]
              ├── FishingLineComponent [priority: 78]
              ├── CharacterComponent [priority: 80]
              ├── RainComponent [priority: 90]
              └── feedbackText (HUD) [priority: 100]
```

### Layer Rationale:
- **RiverBank (60) < WaterSurface (70)**: Water surface overlaps the muddy shoreline foam cleanly.
- **WaterSurface (70) < Bobber (75)**: Bobber float sits on top of water surface.
- **Bobber (75) & FishingLine (78) < Character (80)**: Character's body and arm render over the rod base and line attachment, ensuring the line connects from inside the rod tip without showing behind-character artifacts.
- **Character (80) < Rain (90)**: Raindrops fall in front of character and riverbank, creating authentic environmental depth.
- **Rain (90) < HUD (100)**: Instructions and UI text are always unobstructed.

---

## 9. Verification & Architectural Checkpoints

1. **Non-Regression Verification**:
   - Run `flutter test` — all existing 67 tests must remain passing.
   - Run `flutter analyze` — 0 errors, 0 warnings.
   - Run `flutter build web` — compile cleanly.
2. **Mathematical Invariant Verification**:
   - Ground check: Character feet must satisfy $Y = 208.8\text{ px}$ when anchored at riverbank plateau.
   - Line connection check: Distance $\|\mathbf{P}_{\text{lineStart}} - \mathbf{P}_{\text{rodTip}}\| \equiv 0.0\text{ px}$ across all states.
   - Taut line check: When $\text{tension} = 1.0$, maximum deviation of quadratic bezier from chord line $\equiv 0.0\text{ px}$.
   - Reset check: Calling `reset()` ensures `world.children.whereType<BobberComponent>()` is empty.
