## 2026-10-13T18:50:15Z
[Message] timestamp=2026-10-13T18:50:15Z sender=db28d72e-a68b-48dc-8d59-a662d180aa4e priority=MESSAGE_PRIORITY_HIGH content=You are worker_r1, an implementation worker.
Your working directory is: c:\Users\Dibya\StudioProjects\monsoon_catch\.agents\teamwork\worker_r1
Project root: c:\Users\Dibya\StudioProjects\monsoon_catch

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

MANDATORY INPUTS:
- Read c:\Users\Dibya\StudioProjects\monsoon_catch\.agents\teamwork\ORIGINAL_REQUEST.md before starting work.
- Read c:\Users\Dibya\StudioProjects\monsoon_catch\.agents\teamwork\orchestrator_r1\SCOPE.md
- Read c:\Users\Dibya\StudioProjects\monsoon_catch\.agents\teamwork\orchestrator_r1\synthesis.md
- Read c:\Users\Dibya\StudioProjects\monsoon_catch\.agents\teamwork\explorer_r1_1\handoff.md
- Read c:\Users\Dibya\StudioProjects\monsoon_catch\.agents\teamwork\explorer_r1_2\handoff.md
- Read c:\Users\Dibya\StudioProjects\monsoon_catch\.agents\teamwork\explorer_r1_3\handoff.md and c:\Users\Dibya\StudioProjects\monsoon_catch\.agents\teamwork\explorer_r1_3\blueprints.md

YOUR TASK:
Implement Requirement R1 (Viewport & Dynamic Canvas Environment) for Monsoon Catch:

1. Viewport & Resolution Architecture:
   - Configure Flame with virtual resolution 640 x 360 (16:9 aspect ratio) using CameraComponent.withFixedResolution and MonsoonWorld.
   - Set camera.viewfinder.anchor = Anchor.topLeft so virtual origin (0, 0) matches top-left.
   - Set backgroundColor to Color(0xFF0F172A) for letterboxing/pillarboxing.
   - Ensure all visual scenery components reside within World, completely eliminating canvas stretching or warping on window resize.

2. Pure Procedural Canvas Environment (Zero static background images):
   - Completely eliminate reliance on pixel_background_forest_and_pond.png and cloud.png.
   - Implement lib/models/weather_state.dart: reactive weather model (Clear Dawn/Day, Overcast, Monsoon Storm) driving parameters (rainIntensity, windSpeed, skyDarkness, cloudDensity, waveTurbulence).
   - Implement lib/components/environment/:
     * sky_component.dart: Procedural linear gradient sky with 4 stops dynamically interpolating between weather palettes.
     * cloud_component.dart: Procedural multi-puff clouds with 2-tone pixel-art shading, kinematic drifting and wrap-around.
     * pine_forest_component.dart: Layered pine tree silhouettes across far ridge, midground, and riverbank with atmospheric depth and fog blending.
     * river_bank_component.dart: Procedural bank/terrain cross-section on the left side (x <= 0.32 W) with turf and peat strata.
     * water_surface_component.dart: Animated procedural water surface with multi-harmonic sine wave simulation, weather turbulence scaling, depth gradient, foam crest, and rain ripple effects.
     * dynamic_environment.dart: Coordinator grouping all environment layers with strict z-ordering.
   - Connect dynamic environment to MonsoonGame/MonsoonWorld.
   - Implement lib/ui/weather_controls_overlay.dart: cozy HUD overlay allowing the user to switch weather conditions (Clear, Overcast, Monsoon) to observe dynamic environmental shifts in real time.

3. Automated Test Suite in test/:
   - test/viewport_test.dart: Headless tests verifying FixedResolutionViewport (640x360), uniform scaling on 1080p, ultrawide pillarboxing, portrait letterboxing, and coordinate transformations.
   - test/weather_state_test.dart: Tests verifying weather parameter transitions and color lerping.
   - test/wave_generator_test.dart: Tests verifying wave simulation determinism, non-NaN guarantees, and turbulence scaling.
   - test/dynamic_environment_test.dart: Tests verifying headless canvas rendering of procedural components via PictureRecorder.

4. Build and Verification:
   - Run `flutter test` and ensure all tests pass.
   - Run `flutter analyze` and ensure 0 errors and 0 warnings.
   - Run `flutter build web` and ensure clean web compilation.
   - Document all commands, outputs, and layout compliance in your handoff report.

SCOPE BOUNDARIES:
- Implement ONLY Requirement R1. Do NOT implement R2 (character rod/fishing line physics) or R3 (fishing reflex state machine).
- Maintain existing tests (test/fishing_math_test.dart).

OUTPUT REQUIREMENTS:
- Write your progress updates to c:\Users\Dibya\StudioProjects\monsoon_catch\.agents\teamwork\worker_r1\progress.md.
- Write your final handoff report to c:\Users\Dibya\StudioProjects\monsoon_catch\.agents\teamwork\worker_r1\handoff.md.
- Send a message to orchestrator (db28d72e-a68b-48dc-8d59-a662d180aa4e) when done.
