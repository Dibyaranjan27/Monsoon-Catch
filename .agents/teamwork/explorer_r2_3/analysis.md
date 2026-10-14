# Analysis: Physics-Aware Fishing Line Math, Bobber Mechanics, Retraction Logic & Test Strategy

**Author**: Explorer 3 (`explorer_r2_3`)  
**Date**: 2026-10-14  
**Target Milestone**: Milestone R2 (Procedural Character, Rod & Physics-Aware Fishing Line)  
**Project Root**: `c:\Users\Dibya\StudioProjects\monsoon_catch`  

---

## 1. Executive Summary & Core Findings

1. **Fishing Line Physics Math**:
   - Hyperbolic catenary curves ($y = a \cosh(x/a)$) are computationally prohibitive for real-time Flutter/Flame canvas rendering due to transcendental Newton-Raphson solvers.
   - A **parameterized Cubic Bezier curve** achieves catenary-equivalent sag with hardware-accelerated Skia/Impeller path rendering (`path.cubicTo`), allowing independent control of rod-tip exit angle tangent, natural gravitational sag belly, and wind drift.
   - Sag depth follows a quadratic tension decay formula: $S(\tau, L_0) = S_{max}(L_0) \cdot (1 - \tau)^2$, where tension $\tau \in [0.0, 1.0]$. At full tension ($\tau = 1.0$), sag collapses to $0.0$, transitioning to a taut chord with high-frequency micro-vibration ($\omega \approx 32\text{ rad/s}, A \approx 1.2\text{ px}$) to convey fighting strain.

2. **Bobber Surface Mechanics & Procedural Rendering**:
   - The bobber must be refactored from a bitmap `SpriteComponent` (`bobber.png`) into a **100% procedural canvas component** (`PositionComponent` with `render(Canvas)`), matching R1 environment standards and eliminating async asset loading issues in headless unit tests.
   - The bobber's vertical coordinate dynamically anchors to the animated water surface calculated by `WaveGenerator.computeElevation(x, t, turbulence)` relative to baseline waterline $y = 234.0\text{ px}$.
   - Landing after cast triggers dual-ring concentric 2.5D foreshortened ripples ($r_y / r_x = 0.35$), integrating seamlessly with `WaterSurfaceComponent`.

3. **Retraction & Reset Logic**:
   - Lingering canvas fragments and ghost lines in the R1 prototype were caused by ad-hoc rendering in `MonsoonWorld.render()` and orphaned `BobberComponent` instances remaining in the component tree after `_isFishing` was cleared.
   - The solution introduces an isolated `FishingLineComponent` with strict lifecycle invariants (`isActive`, `rodTipPosition`, `bobberPosition`), an immediate atomic reset routine, and clear teardown of effects and timers.

4. **Test Suite Strategy**:
   - A 5-tier test architecture covering:
     1. Exact rod tip analytical coordinate validation across all 4 character poses.
     2. Pure mathematical unit tests for line curvature, sag monotonicity, taut chord limits, and NaN/infinity edge cases.
     3. Bobber water surface tracking and ripple physics tests.
     4. Retraction and canvas cleanup tests via `PictureRecorder`.
     5. Regression suite verifying the existing 67 R1 tests continue passing without alteration.

---

## 2. Baseline Architecture & Problem Identification

### 2.1 Existing Codebase Inspection
In Milestone R1, the dynamic environment established:
- **Virtual Viewport**: Fixed 640x360 resolution (`FixedResolutionViewport`, 16:9) anchored at `(0, 0)`.
- **Riverbank Platform**: Left-side bank occupies $x \in [0, 204.8]$ (`0.32 * W`). Platform surface is flat at $y = 208.8$ (`0.58 * H`) from $x = 0$ to $x \approx 133.12$.
- **Water Surface**: Water begins at $x \ge 192.0$ (`0.30 * W`) with waterline baseline at $y = 234.0$ (`0.65 * H`). Elevation is dynamically driven by `WaveGenerator.computeElevation(x, t, turbulence)`.
- **Existing Bobber & Character**:
  - `lib/components/bobber.dart`: Relies on `game.loadSprite('bobber.png')` with Flame `MoveEffect`s.
  - `lib/components/character.dart`: `CharacterPlaceholder` loads 4 PNGs (`character_idle.png`, etc.) and calculates rod tip via a static bounding box percentage.
  - `lib/game/monsoon_world.dart`: Lines 167–180 draw a single straight white line `canvas.drawLine()` between rod tip and bobber when `_isFishing` is true.

### 2.2 Critical Deficiencies in Current Implementation
| Component | Existing R1 Prototype | Required Milestone R2 Standard |
|---|---|---|
| **Fishing Line Math** | Flat `canvas.drawLine()` chord with 0 physics, 0 sag, 0 tension. | Physics-aware Cubic Bezier catenary curve with slack sag, taut tension, wind drift, and micro-vibration. |
| **Line Origin** | Rough percentage offset on character sprite (`size.x * 0.75`). | Exact mathematical coordinate tracking rod tip across all poses. |
| **Bobber Asset** | Bitmap sprite `bobber.png` loaded asynchronously. | Procedural canvas-rendered bobber (signal red/white float with brass eyelet and quill). |
| **Bobber Flotation** | Moves on a fixed y-plane via hardcoded Flame `MoveEffect`. | Dynamically rides actual water wave elevation $y_{water}(x, t)$ via `WaveGenerator`. |
| **Retraction / Reset** | Line disappears, but `currentBobber` stays alive in world until next cast; no retraction animation. | Atomic cleanup of line and bobber; zero lingering canvas fragments; instant or rapid snap retraction. |
| **Testing** | Only wait/bite window logic tested in `fishing_math_test.dart`. | Complete mathematical test suite for line physics, rod tip math, state invariants, and headless canvas rendering. |

---

## 3. Physics-Aware Fishing Line Math Formulation

### 3.1 Catenary vs. Bezier Mathematical Formulation
A flexible line suspended between two points $P_1 = (x_1, y_1)$ (rod tip) and $P_2 = (x_2, y_2)$ (bobber) with uniform linear mass density $\mu$ under gravity $g$ forms a catenary:
$$y(x) = a \cosh\left(\frac{x - x_0}{a}\right) + y_0, \quad a = \frac{T_H}{\mu g}$$
Where $T_H$ is horizontal tension. For asymmetric endpoints ($y_1 \neq y_2$), finding $a, x_0, y_0$ requires solving:
$$\sqrt{L^2 - (y_2 - y_1)^2} = 2a \sinh\left(\frac{x_2 - x_1}{2a}\right)$$
This transcendental equation requires iterative numerical methods (e.g. Newton-Raphson), which is inefficient at 60 FPS in Flutter.

#### The Cubic Bezier Catenary Approximation
A parabolic approximation is mathematically equivalent to the first-order Taylor expansion of $\cosh(u) \approx 1 + \frac{u^2}{2}$. A Cubic Bezier curve defined by 4 control points $P_1, C_1, C_2, P_2$:
$$B(t) = (1-t)^3 P_1 + 3(1-t)^2 t C_1 + 3(1-t) t^2 C_2 + t^3 P_2, \quad t \in [0, 1]$$

Let $\vec{D} = P_2 - P_1 = (\Delta x, \Delta y)$ and span distance $L_0 = \|\vec{D}\| = \sqrt{\Delta x^2 + \Delta y^2}$.
The chord trisection points are:
$$M_1 = P_1 + \frac{1}{3}\vec{D}, \quad M_2 = P_1 + \frac{2}{3}\vec{D}$$

We apply sag displacement $\vec{S} = (S_x, S_y)$ to these points:
$$C_1 = M_1 + \frac{4}{3} \vec{S} \cdot w_1$$
$$C_2 = M_2 + \frac{4}{3} \vec{S} \cdot w_2$$
Where $w_1 = 0.85$ and $w_2 = 1.15$ provide natural asymmetry: the line exits the high rod tip with stiffer slope and bellies out toward the water.
At midpoint $t = 0.5$:
$$B(0.5) = \frac{1}{8}P_1 + \frac{3}{8}C_1 + \frac{3}{8}C_2 + \frac{1}{8}P_2 = \frac{P_1 + P_2}{2} + \vec{S} \cdot \left(\frac{w_1 + w_2}{2}\right) = \vec{M} + \vec{S}$$
Since $\frac{w_1 + w_2}{2} = 1.0$, the midpoint sag is **exactly** equal to $\vec{S}$.

```
  P1 (Rod Tip)
    \
     \    C1
      '.   .
        '-.      C2
           '-._   .
               '--._
                    '-._
                        P2 (Bobber)
  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~ (Water Surface)
```

### 3.2 Tension and Sag Depth Equations
Let $\tau \in [0.0, 1.0]$ be the normalized tension parameter:
- $\tau = 0.0$: Fully slack (natural droop when resting).
- $\tau = 1.0$: Taut chord (reeling, bite strike).

1. **Maximum Sag Calculation**:
   $$S_{max}(L_0) = \text{clamp}(L_0 \times k_{sag}, S_{min}, S_{cap})$$
   - $k_{sag} = 0.14$ (14% of span)
   - $S_{min} = 4.0\text{ px}$
   - $S_{cap} = 38.0\text{ px}$ (prevents line dipping into riverbed at $y > 280$)

2. **Tension Sag Decay**:
   $$S_y(\tau, L_0) = S_{max}(L_0) \times (1.0 - \tau)^2$$
   The quadratic exponent $(1-\tau)^2$ produces realistic monofilament elasticity: sag diminishes rapidly as line takes up strain.

3. **Wind Drift Deflection**:
   Crosswinds in monsoon weather displace the lightweight monofilament horizontally:
   $$S_x = v_{wind} \times (1.0 - \tau) \times k_{wind}$$
   Where $v_{wind} \in [-1.0, 1.0]$ and $k_{wind} = 8.0\text{ px}$.

4. **Line Micro-Vibration Under Strain**:
   When $\tau \ge 0.75$, the line vibrates with high-frequency strumming:
   $$\vec{n}_{\perp} = \left(-\frac{\Delta y}{L_0}, \frac{\Delta x}{L_0}\right)$$
   $$A_{vib}(t, \tau) = A_{max} \cdot \frac{\tau - 0.75}{0.25} \cdot \sin(\omega_{vib} \cdot t)$$
   Where $A_{max} = 1.2\text{ px}$ and $\omega_{vib} = 32.0\text{ rad/s}$ (~5.1 Hz).
   This vector $A_{vib} \cdot \vec{n}_{\perp}$ is added to $C_1$ and $C_2$.

### 3.3 Dynamic Casting Arc Trajectory
During casting (`CharacterState.casting`), the bobber travels from rod release point $P_{release}$ to pond target $P_{target}$ over duration $T_{cast} = 0.65\text{ s}$.
Let normalized progress be $t = (t_{elapsed} / T_{cast}) \in [0, 1]$.
1. **Ballistic Bobber Flight**:
   $$x_b(t) = P_{release}.x + (P_{target}.x - P_{release}.x) \cdot \text{easeOutQuad}(t)$$
   $$y_b(t) = P_{release}.y + (P_{target}.y - P_{release}.y) \cdot t - 4 \cdot H_{arc} \cdot t \cdot (1 - t)$$
   Where $H_{arc} = 60.0\text{ px}$ (high parabolic lob).
2. **Dynamic Line Whipping Curve**:
   - For $t \in [0.0, 0.35]$ (forward rod whip): Tension is high ($\tau \approx 0.85$), line trails behind the rod tip with reverse curvature.
   - For $t \in [0.35, 0.85]$ (mid-air flight): Line unfurls, tension moderates ($\tau \approx 0.60$), following the bobber.
   - For $t \in [0.85, 1.0]$ (descent & water splashdown): Bobber decelerates into water, line goes slack ($\tau \to 0.10$), settling into gravitational catenary droop.

### 3.4 Pure Dart Implementation Design: `FishingLineMath`
```dart
class FishingLineMath {
  FishingLineMath._();

  static const double kSagFactor = 0.14;
  static const double kMinSag = 4.0;
  static const double kMaxSag = 38.0;
  static const double kVibrationFrequency = 32.0; // rad/s
  static const double kMaxVibrationAmplitude = 1.2; // px

  /// Computes the two Cubic Bezier control points C1 and C2 connecting
  /// rodTip (p1) to bobber (p2).
  static BezierControlPoints computeControlPoints({
    required Offset p1,
    required Offset p2,
    required double tension,
    double windFactor = 0.0,
    double time = 0.0,
  }) {
    final safeTension = tension.clamp(0.0, 1.0);
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final span = sqrt(dx * dx + dy * dy);

    // Degenerate zero-length span protection
    if (span < 1e-4) {
      return BezierControlPoints(c1: p1, c2: p2);
    }

    // 1. Trisection base points
    final m1 = Offset(p1.dx + dx / 3.0, p1.dy + dy / 3.0);
    final m2 = Offset(p1.dx + (2.0 * dx) / 3.0, p1.dy + (2.0 * dy) / 3.0);

    // 2. Gravitational sag
    final maxSag = (span * kSagFactor).clamp(kMinSag, kMaxSag);
    final sagY = maxSag * pow(1.0 - safeTension, 2);
    final sagX = windFactor * (1.0 - safeTension) * 8.0;

    // 3. High-tension vibration
    double vibX = 0.0;
    double vibY = 0.0;
    if (safeTension > 0.75) {
      final vibTensionScale = (safeTension - 0.75) / 0.25;
      final vibAmp = kMaxVibrationAmplitude * vibTensionScale * sin(kVibrationFrequency * time);
      // Unit normal: (-dy / span, dx / span)
      vibX = (-dy / span) * vibAmp;
      vibY = (dx / span) * vibAmp;
    }

    // 4. Asymmetric catenary weighting (0.85 near tip, 1.15 near bobber)
    final c1 = Offset(
      m1.dx + (4.0 / 3.0) * sagX * 0.85 + vibX,
      m1.dy + (4.0 / 3.0) * sagY * 0.85 + vibY,
    );
    final c2 = Offset(
      m2.dx + (4.0 / 3.0) * sagX * 1.15 + vibX,
      m2.dy + (4.0 / 3.0) * sagY * 1.15 + vibY,
    );

    return BezierControlPoints(c1: c1, c2: c2);
  }
}

class BezierControlPoints {
  final Offset c1;
  final Offset c2;
  const BezierControlPoints({required this.c1, required this.c2});
}
```

---

## 4. Bobber Anchor Mechanics & Water Surface Physics

### 4.1 Water Surface Tracking with `WaveGenerator`
The bobber must never hover above or sink below the animated wave surface when resting in `floating` state.
The baseline waterline is at $y_{base} = 234.0\text{ px}$.
Given bobber horizontal position $x_b$ and global game time $t$:
$$y_{water}(t) = y_{base} + \text{waveGenerator.computeElevation}(x_b, t, \text{weather.waveTurbulence})$$
The resting bobber center coordinate is:
$$y_{bobber}(t) = y_{water}(t) + y_{stateOffset}(t)$$
Where $y_{stateOffset}(t)$ reflects buoyancy and fish interaction states:

| Bobber State | Vertical Displacement $y_{stateOffset}$ | Antenna / Float Angle $\theta$ | Description |
|---|---|---|---|
| `floating` | $-2.0 + 0.6 \sin(2.5 t)$ px | $\frac{\partial y_{water}}{\partial x} \approx 0.06 \cos(2.0 t)$ rad | Gentle buoyancy equilibrium; rocks with wave slope. |
| `nibble` | $-2.0 + 3.5 \cdot \|\sin(18.0 t)\| \cdot e^{-2.0 t_{nib}}$ px | $\pm 0.20 \sin(24.0 t)$ rad | Sharp, erratic vertical twitch; generates micro-ripples. |
| `bite` | $+11.0 + 1.2 \sin(12.0 t)$ px | $-0.35$ rad (~$-20^\circ$) toward rod | Submerged underwater under heavy fish pull. |
| `caught` | $-45.0 \cdot \sin(\pi \cdot t_{progress})$ px | $+0.40$ rad | Soars upward out of water alongside the fish catch. |
| `airborne` | Ballistic flight $y_b(t)$ | Tangent to flight velocity vector | Dynamic cast trajectory. |
| `retracted` | Hidden / $0$ size | $0$ rad | Completely inactive and unrendered. |

### 4.2 Procedural Canvas Bobber Rendering (Zero Asset Dependency)
Instead of relying on `bobber.png`, the bobber is rendered via procedural vector graphics:
- **Dimensions**: Oval float measuring $12\text{ px} \times 16\text{ px}$.
- **Top Hemisphere**: High-visibility signal coral red (`Color(0xFFE63946)`), with a white specular highlight dot (`Offset(-2, -3)`).
- **Bottom Hemisphere**: Crisp porcelain white (`Color(0xFFF1FAEE)`) with subtle submerged shadow tint (`Color(0xFFA8DADC)`).
- **Equatorial Band**: Dark slate seam (`Color(0xFF1D3557)`), stroke width $1.0\text{ px}$.
- **Quill Antenna**: Yellow/red indicator pin ($6\text{ px}$ height, $1.5\text{ px}$ width) protruding from top center.
- **Submerged Water Masking**: When submerged during `bite`, the bottom hemisphere is shaded with a water tint overlay (`Color(0x661D3557)`).

```
          [!] Quill Tip (Yellow/Red)
           |
        .-----.
       /   *   \   <-- Top Dome: Signal Red with highlight dot
      +=========+  <-- Equator Seam: Dark Slate Band
       \       /   <-- Bottom Dome: Porcelain White
        '-----'
           O       <-- Brass Eyelet / Line Attachment
```

### 4.3 Landing Splash & Ripple Integration
When the bobber completes casting ($t_{cast} = 1.0$), it impacts the water at $(x_b, y_{water})$.
A splash event is triggered:
1. **Concentric Elliptical Ripples**:
   - Modeled after `WaterSurfaceComponent._RainRipple`, using the 2.5D foreshortened aspect ratio $r_y = r_x \times 0.35$.
   - Primary Ring: Max radius $22\text{ px}$, duration $0.70\text{ s}$.
   - Secondary Ring: Max radius $14\text{ px}$, delay $0.08\text{ s}$, duration $0.60\text{ s}$.
   - Alpha fade: $\alpha(t) = 0.85 \cdot (1 - t/T_{max})$.
2. **Droplet Spray Particles**:
   - 4 miniature procedural water spray beads launched upward ($\Delta x \in [-8, 8], \Delta y \in [-12, -4]$) with gravity $g = 98\text{ px/s}^2$ and lifetime $0.25\text{ s}$.

---

## 5. Retraction & Reset Invariant Logic

### 5.1 Root Causes of Lingering Canvas Fragments
In R1, several architectural issues permitted ghost lines and lingering artifacts:
1. **Ad-Hoc Line Rendering**: `canvas.drawLine` was called in `MonsoonWorld.render()` based solely on `if (currentBobber != null && _isFishing)`. If `currentBobber` was destroyed or recreated asynchronously without updating `_isFishing`, or if an exception interrupted `onTapDown`, state became desynchronized.
2. **Orphaned Bobber Components**: On catch or miss, `_isFishing` was set to `false`, but `currentBobber` was **not removed** from the Flame world until the *next* cast tap occurred! During that interval, `currentBobber` was floating in limbo.
3. **Interrupted Cast Tween**: If a player tapped during an in-flight cast, multiple `BobberComponent` instances were added simultaneously to the component tree.

### 5.2 Strict Retraction Invariants & State Machine
We establish the following formal invariants:
- **Invariant 1 (Line Inactivity)**: If `fishingLine.isActive == false`, `fishingLine.render(canvas)` is a no-op (zero draw calls, empty path).
- **Invariant 2 (Bobber Singularity)**: At most **one** `BobberComponent` can ever exist in `MonsoonWorld`. Any active bobber must be explicitly detached before a new one is allocated.
- **Invariant 3 (Atomic Retraction)**: On `resetFishing()`, all timers are cancelled, the bobber is removed from parent, the line is deactivated and cleared, and the character is set to `idle`.

### 5.3 Retraction Execution Flow
```
[User Action or Timeout]
       |
       +--> Catch Success / Miss / Cancellation
                 |
                 v
       +---------------------------------------------+
       | atomicResetFishing()                        |
       | 1. Cancel cast/nibble/bite timers           |
       | 2. fishingLine.deactivate()                 |
       |    -> path.reset()                          |
       |    -> isActive = false                      |
       | 3. currentBobber?.removeFromParent()        |
       |    -> currentBobber = null                  |
       | 4. character.setState(CharacterState.idle)  |
       | 5. feedbackText.text updated                |
       +---------------------------------------------+
                 |
                 v
       [Clean Riverbank & Water Surface - 0 Ghost Lines]
```

### 5.4 Edge Case Hardening
1. **Rapid Double-Tapping**: If user taps 10 times in 100 ms, each tap calls `atomicResetFishing()` before initiating the new cast. No orphan entities or stacked tweens can occur.
2. **Window / Viewport Resize During Cast**: The virtual resolution is locked at 640x360. Virtual coordinates are invariant to window resizing. The line math uses virtual coordinates exclusively.
3. **App Pause / Tab Backgrounding**: All timers use delta time `dt` from Flame's `update(dt)`. If the game pauses, timers freeze and resume deterministically without jump discontinuities.

---

## 6. Comprehensive Automated Test Suite Strategy

To satisfy Requirement R4 ("zero errors, passes all unit tests for character, rod tip math, line physics, and state transitions"), we structure the test suite into 4 dedicated test files plus 1 regression suite:

```
test/
├── character_rod_tip_test.dart       # Rod tip coordinates across all 4 poses
├── fishing_line_math_test.dart       # Curvature, tension, sag, vibration, edge cases
├── bobber_mechanics_test.dart        # Flotation, wave tracking, splash ripples
├── fishing_retraction_test.dart      # Atomic reset, zero lingering fragments, stress
└── r1_regression_test.dart           # Verifies all 67 R1 tests continue passing
```

### 6.1 Test Specification Matrix

| Test Suite | Test Case Description | Exact Assertion Criteria |
|---|---|---|
| **`character_rod_tip_test.dart`** | Rod tip in `idle` state | $x_{tip} \in [130, 160]$, $y_{tip} \in [150, 175]$. Angle with rod base $\approx 42^\circ - 48^\circ$. |
| | Rod tip in `casting(t)` | Continuous trajectory from backswing ($x \approx 110, y \approx 140$) to forward whip ($x \approx 175, y \approx 195$). $\|P(t+\Delta t) - P(t)\| < 3.0\text{ px}$. |
| | Rod tip in `reeling` / `strain` | Rod tip flexes downwards by $\ge 18\text{ px}$ compared to `idle`: $y_{tip}^{strain} - y_{tip}^{idle} \ge 18.0$. |
| | Rod tip in `caught` | Rod tip raised high: $y_{tip}^{caught} \le 145.0\text{ px}$ (highest elevation in all states). |
| | Rod tip riverbank grounding | $x_{tip} < 200.0\text{ px}$ (always remains over or near bank), $y_{tip} < 234.0\text{ px}$ (never underwater). |
| **`fishing_line_math_test.dart`** | Endpoint matching | $B(0) == P_1$ (rod tip) and $B(1) == P_2$ (bobber) for all inputs. |
| | Sag monotonicity with tension | For $\tau_1 < \tau_2 \implies S(\tau_1) \ge S(\tau_2)$. At $\tau = 0.0$, $S = S_{max}$. At $\tau = 1.0$, $S = 0.0$. |
| | Taut chord limit at $\tau = 1.0$ | Control points $C_1, C_2$ lie along chord $P_1 \to P_2$ within vibration tolerance. |
| | Non-NaN / finite bounds | Inputting `double.nan`, `double.infinity`, or zero-length span $P_1 == P_2$ returns finite coordinates without throwing. |
| | Wind deflection response | $S_x$ shifts along wind vector when slack ($\tau = 0$), collapses to $0.0$ when taut ($\tau = 1.0$). |
| | High-tension micro-vibration | Vibration amplitude is $0.0$ for $\tau \le 0.75$, increases linearly up to $1.2\text{ px}$ at $\tau = 1.0$. |
| **`bobber_mechanics_test.dart`** | Wave elevation tracking | In `floating` state, bobber $y$ equals $y_{water}(x, t) \pm 2.0\text{ px}$ for any $x \in [200, 600], t \in [0, 100]$. |
| | Bite strike immersion | In `bite` state, bobber $y$ is strictly greater than $y_{water} + 9.0\text{ px}$ (submerged). |
| | Procedural canvas render | Headless `render(canvas)` via `PictureRecorder` produces non-null picture with zero exceptions. |
| | Landing ripple creation | Water landing creates concentric ripples with positive lifetime and expanding radii. |
| **`fishing_retraction_test.dart`** | Zero canvas fragments on reset | When `resetFishing()` is called, `line.isActive == false`. `line.render(canvas)` produces 0 draw commands. |
| | Bobber removal on catch/miss | After miss or catch, `currentBobber` is removed from Flame parent and `currentBobber == null`. |
| | State machine reset to idle | Character state resets to `CharacterState.idle` upon retraction. |
| | Rapid spam stress test | 100 consecutive rapid `cast()` followed by immediate `reset()` cycles without memory leaks or orphans. |
| **`r1_regression_test.dart`** | Viewport & R1 environment | 640x360 fixed viewport, sky gradients, clouds, forest, riverbank, wave generator pass 100%. |

---

## 7. Concrete Implementation Design & Component Contracts

### 7.1 Proposed Component Structure
To cleanly separate concerns without cluttering `MonsoonWorld.render()`, we propose:
1. `FishingLineComponent extends Component`:
   - Holds reference to rod tip position provider (`Vector2 Function()`).
   - Holds reference to bobber position provider (`Vector2? Function()`).
   - Owns `_cachedPath`, `_linePaint`, and invokes `FishingLineMath.computeControlPoints(...)`.
   - Priority: `GameConfig.priorityCharacter + 1` (renders in front of riverbank and character arm, but behind HUD).
2. `ProceduralBobberComponent extends PositionComponent`:
   - Replaces old `BobberComponent`.
   - Procedural rendering via `Canvas.drawOval` and `Canvas.drawArc`.
   - Wave elevation synchronization via `WaveGenerator`.
   - Priority: `GameConfig.priorityWaterSurface + 5`.
3. `CharacterComponent extends PositionComponent`:
   - Procedural rendering of fisher on bank ($x \approx 105, y \approx 208.8$).
   - Exposes exact analytical `Vector2 get rodTipPosition`.

### 7.2 Interface Contracts
```dart
abstract class RodTipProvider {
  Vector2 get rodTipPosition;
}

abstract class BobberTargetProvider {
  Vector2? get bobberPosition;
  bool get isBobberActive;
}
```

This interface decouples `FishingLineComponent` from the internal details of `CharacterComponent` and `ProceduralBobberComponent`, enabling 100% isolated headless unit testing with mock providers!

---

## 8. Summary of Recommendations for Implementation Team

1. **Adopt Cubic Bezier over Quadratic Bezier**: The dual control points ($C_1, C_2$) allow natural tangent alignment at the rod tip and parabolic catenary droop into the water.
2. **Eliminate All Bitmap Sprites in Bobber**: Render the bobber purely via `Canvas` primitives to maintain the project's zero-bitmap architecture and enable instant headless testing.
3. **Encapsulate Fishing Line in Its Own Flame Component**: Move line rendering out of `MonsoonWorld.render()` into a dedicated `FishingLineComponent` with strict `isActive` guards.
4. **Implement Deterministic Atomic Reset**: Ensure `atomicResetFishing()` cleans up all timers, removes the bobber, resets the line path, and transitions the character to idle.
5. **Run the 5-Tier Test Suite**: Guarantee mathematical determinism, non-NaN safety, and zero regression against R1.
