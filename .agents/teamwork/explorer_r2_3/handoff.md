# Handoff Report: Physics-Aware Fishing Line Math, Bobber Mechanics, Retraction Logic & Test Strategy

**Agent**: Explorer 3 (`explorer_r2_3`)  
**Working Directory**: `c:\Users\Dibya\StudioProjects\monsoon_catch\.agents\teamwork\explorer_r2_3`  
**Parent Orchestrator**: `de9a7462-3e4e-461d-b92d-3c1ba7f60d19`  
**Date**: 2026-10-14  
**Type**: Hard Handoff (Investigation & Strategy Complete)  

---

## 1. Observation

1. **Existing Line Rendering in `MonsoonWorld`**:
   In `lib/game/monsoon_world.dart`, lines 167–180:
   ```dart
   // Render fishing line between rod tip and bobber
   if (currentBobber != null && _isFishing) {
     final linePaint = Paint()
       ..color = Colors.white.withValues(alpha: 0.65)
       ..strokeWidth = 1.0;

     final rodTip = character.getRodTipPosition();
     canvas.drawLine(
       Offset(rodTip.x, rodTip.y),
       Offset(currentBobber!.position.x, currentBobber!.position.y),
       linePaint,
     );
   }
   ```
   The existing fishing line is a basic straight `canvas.drawLine()` with no sag, no tension dynamics, no curvature, and no connection to character state.

2. **Crude Rod Tip Approximation in `CharacterPlaceholder`**:
   In `lib/components/character.dart`, lines 38–46:
   ```dart
   Vector2 getRodTipPosition() {
     if (current == CharacterState.casting) {
       return absolutePosition + Vector2(size.x * 0.85, size.y * 0.25);
     } else if (current == CharacterState.caught ||
         current == CharacterState.reeling) {
       return absolutePosition + Vector2(size.x * 0.70, size.y * 0.35);
     }
     return absolutePosition + Vector2(size.x * 0.75, size.y * 0.45);
   }
   ```
   The rod tip uses coarse box-fraction offsets rather than exact analytical trigonometry.

3. **Bobber Bitmap Dependency**:
   In `lib/components/bobber.dart`, line 27:
   ```dart
   sprite = await game.loadSprite('bobber.png');
   ```
   The bobber relies on an asynchronous image sprite load rather than procedural code-canvas rendering, violating the project standard established in R1 where all background and environment assets are procedurally rendered in canvas primitives.

4. **Orphaned Bobber & Ghost Line Risk on Retraction**:
   In `lib/game/monsoon_world.dart`, lines 104–110:
   ```dart
   // Missed the strike
   currentBobber!.changeState(BobberState.missed);
   character.current = CharacterState.idle;
   feedbackText.text = 'Missed it!';
   _isFishing = false;
   ```
   And line 125–127:
   ```dart
   feedbackText.text = 'Caught a fish!';
   _isFishing = false;
   return;
   ```
   When a catch or miss occurs, `_isFishing = false`, but `currentBobber` is **not removed** from the Flame world. It is only removed on line 147 when the player taps to cast again:
   ```dart
   if (currentBobber != null) {
     remove(currentBobber!);
   }
   ```
   This creates an orphaned bobber state and an abrupt line cutoff without any clean retraction animation or invariant guarantees.

5. **Existing Environment Dimensions & Water Physics**:
   - `lib/components/environment/river_bank_component.dart`, line 51–53:
     `bankWidth = size.x * 0.32` (~204.8 px at 640 width), `bankPlatformY = size.y * 0.58` (~208.8 px), `waterContactY = size.y * 0.65` (~234.0 px).
   - `lib/components/environment/water_surface_component.dart`, line 118:
     Waterline baseline is $y = \text{size.y} \times 0.65 = 234.0\text{ px}$. Elevation is determined by `WaveGenerator.computeElevation(x, t, turb)`.
   - `lib/components/environment/water_surface_component.dart`, lines 164–196:
     Procedural rain impact ripples expand with $r_y = r_x \times 0.35$ (foreshortened 2.5D perspective).

---

## 2. Logic Chain

1. **Selection of Cubic Bezier over Catenary**:
   - From Observation 1, the current line is a straight chord.
   - A true catenary $y = a \cosh((x - x_0)/a) + y_0$ requires solving a transcendental equation with Newton-Raphson iteration per frame, adding CPU latency.
   - Flutter's `Canvas` provides hardware-accelerated `path.cubicTo(c1x, c1y, c2x, c2y, endX, endY)`.
   - By setting control points $C_1 = M_1 + \frac{4}{3}\vec{S} \cdot 0.85$ and $C_2 = M_2 + \frac{4}{3}\vec{S} \cdot 1.15$ (where $M_1, M_2$ are chord trisection points and $\vec{S}$ is sag depth), the midpoint sag evaluates to exactly $\vec{S}$, matching catenary curvature with zero iterative overhead.
   - Dual control points allow the line to exit the rod tip along the rod's upward tangent before bending downward under gravity, which a single-control-point quadratic Bezier cannot achieve.

2. **Tension and Sag Mathematical Modeling**:
   - Monofilament fishing line elasticity dictates that sag must collapse quickly as tension increases.
   - By formulating $S_y(\tau, L_0) = \text{clamp}(L_0 \times 0.14, 4.0, 38.0) \times (1.0 - \tau)^2$, sag is smooth and bounded.
   - At $\tau = 0.0$ (idle), line droops by 14% of span ($20 - 35\text{ px}$).
   - At $\tau = 1.0$ (reeling/strain), sag collapses to $0.0$, forming a taut chord with high-frequency micro-vibration ($A_{vib} = 1.2\text{ px}, \omega = 32\text{ rad/s}$), providing immediate tactile visual feedback of fighting a fish.

3. **Procedural Bobber & Wave Synchronization**:
   - From Observation 3, `bobber.png` introduces an external asset dependency.
   - Refactoring to a procedural `PositionComponent` using `Canvas.drawOval` (red top hemisphere, white bottom hemisphere, dark band, indicator quill) removes all asset dependencies, enabling headless unit testing without asset bundle mocking.
   - From Observation 5, water baseline is $y = 234.0\text{ px}$ with multi-harmonic waves from `WaveGenerator`.
   - By setting $y_{bobber}(t) = 234.0 + \text{waveGenerator.computeElevation}(x_b, t, \text{turb}) + y_{offset}$, the bobber stays anchored to the animated water surface across all weather conditions.
   - On cast impact, triggering a concentric elliptical ripple ($r_y / r_x = 0.35$) mirrors `WaterSurfaceComponent._RainRipple`, providing cohesive visual feedback.

4. **Retraction & Invariant Logic**:
   - From Observation 4, orphaned `BobberComponent`s and ad-hoc line drawing cause ghost lines.
   - Moving line rendering to a dedicated `FishingLineComponent` with an `isActive` guard ensures that when `isActive == false`, `render(canvas)` immediately returns with 0 draw calls.
   - Introducing `atomicResetFishing()` enforces:
     1. Cancellation of all active timers (`_castTimer`, `_nibbleTimer`, `_biteTimer`).
     2. Immediate detachment of `currentBobber?.removeFromParent()` and nulling reference.
     3. Line deactivation (`fishingLine.deactivate()`), resetting `_cachedPath`.
     4. Character state reset to `CharacterState.idle`.
   - This guarantees zero lingering canvas fragments or orphaned components under all conditions, including rapid repeated taps.

5. **Test Strategy Formulation**:
   - Requirements demand strict unit testing for rod tip math, line curvature, state transitions, and retraction.
   - By structuring 4 focused test files (`character_rod_tip_test.dart`, `fishing_line_math_test.dart`, `bobber_mechanics_test.dart`, `fishing_retraction_test.dart`) and headless canvas verification via `PictureRecorder`, all criteria can be verified automatically.

---

## 3. Caveats

1. **Character Component Boundary**:
   Explorer 2 is designing the procedural character rendering and rod tip analytical function. Explorer 3's line math assumes an analytical function `Vector2 get rodTipPosition` is exposed by `CharacterComponent`. Decoupling via the `RodTipProvider` interface prevents blocking dependencies.
2. **Animation Duration Constants**:
   Cast duration is modeled at $T_{cast} = 0.65\text{ s}$ and retraction snap at $0.15\text{ s}$. These values provide fluid feel but can be tuned during final gameplay polish without affecting the underlying mathematical formulas.
3. **No Code Written to `lib/` or `test/`**:
   In strict accordance with the read-only exploration constraint, all designs, mathematical formulations, and test suites are specified in analysis and handoff documents.

---

## 4. Conclusion

1. **Mathematical Fishing Line Engine**:
   Use a parameterized Cubic Bezier curve with trisection control points, quadratic tension decay $S(\tau) = S_{max}(1-\tau)^2$, wind drift offset, and micro-vibration perturbation under $\tau > 0.75$.
2. **Procedural Bobber & Wave Anchor**:
   Replace bitmap `bobber.png` with a procedural vector bobber anchored to $y = 234.0 + \text{waveGenerator.computeElevation}(x, t, turb)$, complete with 2.5D concentric landing ripples.
3. **Deterministic Retraction Architecture**:
   Encapsulate fishing line in `FishingLineComponent` with atomic reset logic that immediately frees bobber components, clears line paths, and resets character state.
4. **Automated Test Architecture**:
   Implement 4 modular test suites validating analytical rod tip coordinates, line curvature monotonicity and limits, bobber wave tracking, and zero-artifact canvas retraction, ensuring 100% compliance and zero regression against R1.

---

## 5. Verification Method

### 5.1 Independent Verification Instructions
To verify the findings and mathematical formulations:
1. **Inspect Analysis Report**:
   Read `c:\Users\Dibya\StudioProjects\monsoon_catch\.agents\teamwork\explorer_r2_3\analysis.md` for complete formulas, algorithms, and ASCII diagrams.
2. **Review Code References**:
   - `lib/game/monsoon_world.dart` (lines 104–110, 125–127, 146–149, 167–180) to confirm orphaned bobbers and flat line rendering.
   - `lib/components/bobber.dart` (line 27) to confirm bitmap asset dependency.
   - `lib/components/character.dart` (lines 38–46) to confirm crude rod tip approximation.
   - `lib/components/environment/water_surface_component.dart` (line 118, 164–196) to confirm waterline baseline $y = 234.0$ and 2.5D ripple aspect ratio $0.35$.
3. **Test Suite Execution (when implementing)**:
   - Run `flutter test` to execute all unit tests.
   - Run `flutter analyze` to ensure 0 errors and 0 warnings.
   - Run `flutter build web` to ensure clean web compilation.
4. **Invalidation Conditions**:
   - If a true catenary hyperbolic solver can be executed in Dart with fewer CPU cycles than `path.cubicTo` (empirically false on GPU-accelerated canvas).
   - If the waterline baseline is changed from $y = 234.0$ in R1 (would break existing R1 wave tests).
