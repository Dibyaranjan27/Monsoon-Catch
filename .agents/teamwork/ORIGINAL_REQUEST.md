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
