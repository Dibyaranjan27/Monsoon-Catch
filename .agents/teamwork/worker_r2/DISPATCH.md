## 2026-10-14T18:56:32Z
You are the Worker (identity: worker_r2).
Working directory: c:\Users\Dibya\StudioProjects\monsoon_catch\.agents\teamwork\worker_r2
Project root: c:\Users\Dibya\StudioProjects\monsoon_catch
Original user request file: c:\Users\Dibya\StudioProjects\monsoon_catch\.agents\teamwork\ORIGINAL_REQUEST.md
Scope document: c:\Users\Dibya\StudioProjects\monsoon_catch\.agents\teamwork\orchestrator_r2\SCOPE.md
Synthesis document: c:\Users\Dibya\StudioProjects\monsoon_catch\.agents\teamwork\orchestrator_r2\synthesis.md

Explorer analyses to read:
- c:\Users\Dibya\StudioProjects\monsoon_catch\.agents\teamwork\explorer_r2_1\analysis.md
- c:\Users\Dibya\StudioProjects\monsoon_catch\.agents\teamwork\explorer_r2_2\analysis.md
- c:\Users\Dibya\StudioProjects\monsoon_catch\.agents\teamwork\explorer_r2_3\analysis.md

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

MANDATORY FIRST STEP:
Read c:\Users\Dibya\StudioProjects\monsoon_catch\.agents\teamwork\ORIGINAL_REQUEST.md, SCOPE.md, synthesis.md, and the Explorer reports before writing any code.

FILE OWNERSHIP:
You exclusively own and may edit or create:
- lib/components/character.dart
- lib/components/fishing_line.dart
- lib/components/bobber.dart
- lib/config/game_config.dart
- lib/game/monsoon_world.dart
- test/character_rod_tip_test.dart
- test/fishing_line_math_test.dart
- test/fishing_retraction_test.dart
- test/bobber_mechanics_test.dart
- Any other new helper files in lib/components/ or test/ if needed for R2.
Do NOT modify existing R1 environment files (sky, cloud, pines, riverbank, water_surface) unless strictly required for clean interface wiring.

TASK INSTRUCTIONS:
1. Procedural Character:
   - Ground on riverbank platform at (118.0, 208.8) using Anchor.bottomCenter (or equivalent bottom-grounded anchor).
   - Render 100% procedurally with Canvas primitives (straw hat, peach face, forest teal poncho, articulated limbs, boots). Zero bitmap sprites!
   - Support 4 distinct expressive poses:
     * idle: relaxed stance, rod angled upward ~45°.
     * casting: dynamic 4-phase whip arc animation over progress t in [0, 1].
     * reeling / strain: braced backward lean (-18°), rod bent downward in heavy bow (38.75 px drop) under tension, subtle micro-jitter.
     * caught: triumphant hop, rod held high (78°), tip elevated, displaying caught catch.
2. Exact Mathematical Rod Tip:
   - Compute rod as a cubic/quadratic Bezier curve from character hand to tip.
   - Expose exact analytical coordinates via rodTipPosition property or method.
   - Zero floating/misalignment guarantee: fishing line origin must bind strictly to rodTipPosition with 0.0 px delta.
3. Physics-Aware Fishing Line:
   - Implement FishingLineComponent.
   - Render using cubic Bezier curve catenary approximation:
     * Sag depth formula: S_y(tau, L) = clamp(L * 0.14, 4.0, 38.0) * (1.0 - tau)^2.
     * tau = 0.0 (slack/idle): natural downward sag.
     * tau = 1.0 (strain/reeling): taut straight chord with micro-vibration.
     * Casting: dynamic arc tracking bobber cast trajectory.
4. Procedural Bobber:
   - Render 100% procedurally with Canvas primitives (red/white float, dark band, yellow quill). Zero bitmap sprites!
   - Float on water surface synchronized with WaveGenerator elevation at baseline y = 234.0 px.
   - 2.5D concentric landing ripples on cast touchdown.
5. Retraction / Reset Logic:
   - Implement atomic reset (resetFishingState / retractLine) that cancels active timers, immediately removes bobber, clears line path, and snaps character to idle with zero lingering canvas fragments or ghost lines.
6. Automated Unit Tests:
   - Implement unit tests covering rod tip coordinates across poses, line curvature math, state transitions, bobber wave tracking, and retraction cleanup.
7. Verification:
   - Run `flutter test` — ensure 100% pass (all new tests + existing 67 tests).
   - Run `flutter analyze` — ensure 0 errors, 0 warnings.
   - Run `flutter build web` — ensure clean web build.
   - Document commands, outputs, and passing proof in handoff.md.
