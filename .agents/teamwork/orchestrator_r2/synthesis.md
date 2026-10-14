# Synthesis: Requirement R2 (Procedural Character, Rod & Physics-Aware Fishing Line)

## 1. Executive Summary & Architectural Decisions
Milestone R2 transitions Monsoon Catch from static bitmap placeholders and crude approximations to a 100% code-driven procedural physics and character simulation within the fixed 640x360 virtual viewport.

### Unified Architectural Decisions
1. **Procedural Character (`ProceduralCharacterComponent`)**:
   - Anchored on riverbank platform at `(X = 118.0, Y = 208.8)` (`Anchor.bottomCenter`).
   - 100% Canvas vector rendered (straw hat, peach skin, forest teal poncho, articulated arms, leather boots). Zero PNG bitmap dependencies.
   - 4 expressive poses driven by `FishingState { idle, casting, reeling, caught }`.
2. **Procedural Rod & Exact Tip Tracking**:
   - Rod rendered as cubic Bezier curve originating from character hand $P_0$.
   - Analytical tip coordinate function $P_{\text{tip}}$ exposed via `Vector2 get rodTipPosition`.
   - Poses:
     - `idle`: Rod angled up at 45°, tip at $(167.67, 153.88)$.
     - `casting`: Dynamic 4-phase whip arc over $t \in [0, 1]$ (windup tip $(91.15, 139.23)$, release tip $(189.10, 165.58)$).
     - `reeling` / `strain`: Braced-back pose (-18°), rod bent down toward water in heavy parabolic bow, tip at $(164.59, 192.63)$ (38.75 px downward flex) with micro-jitter.
     - `caught`: Triumphant hop, rod held high at 78°, tip at $(141.23, 125.86)$ with dangling catch.
3. **Physics-Aware Fishing Line (`FishingLineComponent`)**:
   - Line origin bound strictly to `rodTipPosition` ($\Delta = 0.0\text{ px}$, zero detachment/floating).
   - Cubic Bezier catenary approximation:
     - Sag depth $S_y(\tau, L) = \text{clamp}(L \times 0.14, 4.0, 38.0) \times (1.0 - \tau)^2$.
     - $\tau = 0.0$ (idle): smooth downward slack sag.
     - $\tau = 1.0$ (reeling): taut tension chord with subtle micro-vibration.
     - Cast trajectory: dynamic line arc tracking bobber cast.
4. **Procedural Bobber (`ProceduralBobberComponent`)**:
   - 100% procedural vector canvas rendering (red/white buoy, dark stripe, yellow quill). Zero bitmap sprites.
   - Floating elevation synchronized to `WaveGenerator` at waterline $Y = 234.0\text{ px}$.
   - 2.5D concentric landing ripples ($r_y / r_x = 0.35$).
5. **Deterministic Retraction & Reset**:
   - `atomicResetFishing()` or `retractLine()` cleanly deactivates line, removes bobber, cancels timers, and snaps character to `idle` with zero lingering canvas artifacts.
6. **Z-Ordering**:
   - WaterSurface (70) < Bobber (75) < FishingLine (78) < Character (80) < Rain (90) < HUD (100).
7. **Verification Requirements**:
   - Minimum 4 dedicated test suites for rod tip math, line curvature, state transitions, and retraction cleanup.
   - `flutter test` must pass all tests with 0 failures (R1 + R2).
   - `flutter analyze` must report 0 issues.
   - `flutter build web` must compile cleanly.

## 2. File Ownership & Plan for Worker
The Worker (`worker_r2`) will own and modify:
- `lib/components/character.dart`: Replace `CharacterPlaceholder` with procedural `ProceduralCharacterComponent` and state controller.
- `lib/components/fishing_rod.dart` (or integrated in character): Rod bending math and tip calculation.
- `lib/components/bobber.dart`: Replace bitmap bobber with procedural `ProceduralBobberComponent` synchronized with wave elevation.
- `lib/components/fishing_line.dart`: New `FishingLineComponent` implementing cubic Bezier catenary physics.
- `lib/game/monsoon_world.dart`: Update world wiring, Z-ordering, cast/reel state hooks, and atomic retraction logic.
- `lib/config/game_config.dart`: Add priorities (`priorityBobber = 75`, `priorityFishingLine = 78`).
- `test/character_rod_tip_test.dart`: Unit tests for rod tip math and poses.
- `test/fishing_line_math_test.dart`: Unit tests for line curvature and tension decay.
- `test/fishing_retraction_test.dart`: Unit tests for state transitions and zero-artifact retraction.
- `test/bobber_mechanics_test.dart`: Unit tests for procedural bobber and wave tracking.
