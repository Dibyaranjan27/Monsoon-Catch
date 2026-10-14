# Scope: Milestone R2 — Procedural Character, Rod & Physics-Aware Fishing Line

## Architecture
- Virtual 640x360 coordinate space anchored to riverbank defined in R1.
- Procedural character component/model:
  - Renders character body, head, arms, hat, and tackle box on riverbank using canvas primitives (path, rect, circle, arc, oval) without static image assets.
  - Expresses 4 distinct poses/states:
    1. `idle`: character relaxed on riverbank holding rod angled upward (~42°), breathing bob.
    2. `casting`: continuous 4-phase whip arc animation over progress t in [0, 1].
    3. `reeling` / `strain`: rod flexed/bent downward under tension (>35 px drop) with character bracing (-18°) and 14 Hz micro-jitter.
    4. `caught`: celebratory pose displaying the caught catch with rod held high (74°-78°) and radiating sparkles.
- Procedural fishing rod model:
  - Rod base anchored to character hand.
  - Rod curvature dynamically calculated via cubic Bezier geometry based on character state.
  - Exact mathematical rod tip coordinates calculated analytically as a function of character state and animation progress `t`.
- Bobber model & state:
  - 100% procedural vector buoy with red/white hemispheres, dark band, and quill.
  - Floating elevation synchronized with `WaveGenerator` at waterline baseline Y = 234.0 px.
  - 2.5D concentric landing ripples on touchdown.
- Physics-aware fishing line:
  - Line origin strictly at rod tip `(rodTip.x, rodTip.y)` with 0.0 px delta across all frames.
  - Line destination at bobber `(bobber.x, bobber.y)`.
  - Realistic curve: cubic Bezier catenary approximation with sag depth clamping, wind drift, and strain micro-vibration.
- Retraction / reset system:
  - Immediate clean retraction and state reset upon catch or miss without lingering canvas artifacts.
- Comprehensive test suite:
  - 129 passing automated tests verifying rod tip math, line curvature calculations, state machine transitions, and retraction logic.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Procedural Riverbank Character | Grounded character rendered via canvas on riverbank at (118.0, 208.8) | M2 (R2) | ORIGINAL_REQUEST §R2 |
| 2 | Expressive Character States | 4 distinct states: idle, casting, reeling/strain, caught | M2 (R2) | ORIGINAL_REQUEST §R2 |
| 3 | Procedural Fishing Rod & Flex Math | Dynamic cubic Bezier rod geometry with flex calculation | M2 (R2) | ORIGINAL_REQUEST §R2 |
| 4 | Exact Mathematical Rod Tip Tracking | Rod tip coordinate calculation with zero disconnect/floating (0.0 px delta) | M2 (R2) | ORIGINAL_REQUEST §R2 |
| 5 | Physics-Aware Fishing Line | Cubic Bezier catenary curve (slack sag, taut tension, cast arc) | M2 (R2) | ORIGINAL_REQUEST §R2 |
| 6 | Bobber Anchor & Cast Trajectory | Procedural bobber tracking WaveGenerator elevation with 2.5D ripples | M2 (R2) | ORIGINAL_REQUEST §R2 |
| 7 | Clean Retraction & Reset Logic | Zero-artifact immediate reset on catch/miss across 500+ stress cycles | M2 (R2) | ORIGINAL_REQUEST §R2 |
| 8 | Automated Tests & Verification | 129 passing tests, 0 analyzer issues, clean web build | M2 (R2) | ORIGINAL_REQUEST §R4 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | M2: Procedural Character, Rod & Physics Line | Character, Rod, Line Physics, States, Retraction, Tests, Web Build | M1 (Done) | DONE |

## Interface Contracts
### RiverBankComponent ↔ CharacterComponent
- Riverbank anchor coordinates: (118.0, 208.8) with Anchor.bottomCenter.
### Character & Rod ↔ FishingLineComponent
- Character state machine: `CharacterState { idle, casting, reeling, caught }`.
- Rod tip accessor: `Vector2 get rodTipPosition`, `Vector2 getRodTipPosition()`.
- Bobber position accessor: `Vector2 position`, `bool isActive`.
- Line tension/sag parameter: `double tension` (0.0 = completely slack with sag, 1.0 = taut straight chord).
### Game Loop / Controller ↔ Fishing System
- Trigger methods: `cast()`, `reel()`, `catchFish()`, `resetFishingState()`.
