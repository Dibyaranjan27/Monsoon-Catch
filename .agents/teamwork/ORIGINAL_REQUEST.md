# Original User Request

## 2026-10-13T18:37:16Z

Build a standalone, cozy pixel-art fishing game in Flutter/Flame.
PHASE 1 EXECUTION CONSTRAINT: Implement ONLY Requirement R1 (Viewport & Dynamic Canvas Environment) for this run. Do not proceed to R2/R3 until R1 is completed, verified against its criteria, and reviewed by the user.

Working directory: c:\Users\Dibya\StudioProjects\monsoon_catch
Integrity mode: development

## Requirements (Phase 1 Scope)

### R1. Viewport & Dynamic Canvas Environment [CURRENT TARGET]
- Implement a fixed virtual resolution viewport with aspect ratio lock (letterboxing/scaling) in Flame/Flutter so visuals never stretch, warp, or distort across different browser or device sizes.
- Render a dynamic, procedural environment in code (layered gradient sky, floating procedural clouds, layered pine tree silhouettes, and animated water surface with wave/ripple simulation) that dynamically shifts with weather.
- Ensure the scene is completely code/canvas rendered without relying on static stretched background images.

### R2. Procedural Character, Rod & Physics-Aware Fishing Line [NEXT PHASE]
- (Paused - awaiting user review of R1)

### R3. Monsoon Fishing State Machine & Reflex Mechanic [FUTURE PHASE]
- (Paused - awaiting user review of R1)

### R4. Quality, Verification & Tooling Constraints
- Provide automated tests verifying the viewport calculations and dynamic environment renderers.
- Ensure the project builds cleanly for web (`flutter build web`) and passes `flutter analyze` with zero errors.
- If any Python companion scripts or backend tooling are utilized, they must run inside a virtual environment (`venv`).

## Acceptance Criteria (Phase 1 Target)

### Visual & Viewport Integrity
- [ ] Viewport maintains fixed aspect ratio and never stretches or warps sprites/canvas on window resize.
- [ ] Environment (sky, clouds, trees, water surface, bank) is rendered dynamically in code with fluid wave motion.
- [ ] Clean separation between water body, riverbank, and background layers.

### Verification & Stability
- [ ] `flutter test` runs and passes all automated unit tests.
- [ ] `flutter analyze` reports 0 errors and 0 warnings.
- [ ] Web target compiles successfully without errors (`flutter build web`).
- [ ] Execution stops and reports results after completing R1 for user review.


## 2026-10-14T18:42:01Z

Build a standalone, cozy pixel-art fishing game in Flutter/Flame.
PHASE 2 EXECUTION CONSTRAINT: Implement ONLY Requirement R2 (Procedural Character, Rod & Physics-Aware Fishing Line) for this run. Do not proceed to R3 until R2 is completed, verified against its criteria, and reviewed by the user.

Working directory: c:\Users\Dibya\StudioProjects\monsoon_catch
Integrity mode: development

## Requirements (Phase 2 Scope)

### R1. Viewport & Dynamic Canvas Environment [COMPLETED & VERIFIED]
- 640x360 fixed virtual viewport and dynamic procedural environment (sky, clouds, forest, bank, animated waves) are fully operational and verified with 67 passing tests.

### R2. Procedural Character, Rod & Physics-Aware Fishing Line [CURRENT TARGET]
- Model the fishing character, fishing rod, and bobber anchor points with exact mathematical precision within the 640x360 virtual coordinates on the riverbank.
- The character and rod must have distinct, expressive states:
  1. `idle`: character relaxed on riverbank holding rod angled upward.
  2. `casting`: dynamic casting arc with the rod whipping forward and line casting out into the pond.
  3. `reeling` / `strain`: rod flexed/bent downward under tension with the character bracing.
  4. `caught`: celebratory pose displaying the caught catch.
- The fishing line must originate strictly from the exact mathematical rod tip in all character states (no floating, detached, or misaligned line).
- The line must be rendered using a physics-aware bezier / catenary curve (slack sag when idle, taut tension curve when reeling/under bite, smooth cast trajectory).
- When a catch completes or a miss occurs, the fishing line and bobber must cleanly and immediately retract/reset without lingering canvas artifacts.

### R3. Monsoon Fishing State Machine & Reflex Mechanic [FUTURE PHASE]
- (Paused - awaiting user review of R2)

### R4. Quality, Verification & Tooling Constraints
- Provide automated unit tests verifying rod tip coordinates, line curvature math, state transitions, and retraction logic.
- Ensure the project passes `flutter test`, `flutter analyze` (0 errors, 0 warnings), and builds cleanly for web (`flutter build web`).
- If any Python companion scripts or backend tooling are utilized, they must run inside a virtual environment (`venv`).

## Acceptance Criteria (Phase 2 Target)
- [ ] Character sits naturally grounded on the riverbank in the 640x360 virtual coordinate space.
- [ ] Fishing line connects with pixel precision to the rod tip across all poses (idle, cast, strain/reeling, caught).
- [ ] Fishing line displays realistic bezier/catenary curve behavior (sagging when slack, straightening/taut under tension).
- [ ] Line and bobber immediately retract upon catch or miss with zero lingering line fragments.
- [ ] Smooth cast arc animation when casting into the water.
- [ ] `flutter test` passes all unit tests for character, rod tip math, and line physics.
- [ ] `flutter analyze` reports 0 issues.
- [ ] Web target compiles cleanly (`flutter build web`).
- [ ] Stop and report results after R2 is verified for user review before starting R3.
