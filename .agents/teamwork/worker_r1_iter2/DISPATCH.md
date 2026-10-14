## 2026-10-13T19:28:36Z
You are worker_r1_iter2, an implementation worker.
Your working directory is: c:\Users\Dibya\StudioProjects\monsoon_catch\.agents\teamwork\worker_r1_iter2
Project root: c:\Users\Dibya\StudioProjects\monsoon_catch

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

MANDATORY INPUTS:
- Read c:\Users\Dibya\StudioProjects\monsoon_catch\.agents\teamwork\ORIGINAL_REQUEST.md before starting work.
- Read c:\Users\Dibya\StudioProjects\monsoon_catch\.agents\teamwork\orchestrator_r1\SCOPE.md.
- Read c:\Users\Dibya\StudioProjects\monsoon_catch\.agents\teamwork\explorer_r1_1_iter2\handoff.md.
- Read c:\Users\Dibya\StudioProjects\monsoon_catch\.agents\teamwork\explorer_r1_2_iter2\handoff.md.
- Read c:\Users\Dibya\StudioProjects\monsoon_catch\.agents\teamwork\explorer_r1_3_iter2\handoff.md.

YOUR TASK:
Apply the exact fixes and performance refactorings for Iteration 2:

1. Static Analysis Cleanliness:
   - In `test/environment_stress_test.dart`: Remove `import 'dart:math';` at line 1 to eliminate the unused import warning.

2. Test Suite Precision Calibration:
   - In `test/fixed_resolution_viewport_stress_test.dart`: Apply the exact before/after replacements documented in `explorer_r1_2_iter2/handoff.md § 4.2` and `explorer_r1_1_iter2/handoff.md` to align assertion tolerances to IEEE-754 Float32 limits (`-1e-4`, `1e-4`, `0.005`, `0.001`).

3. Environment Performance Refactoring:
   - Apply the complete drop-in blueprints from `explorer_r1_3_iter2/handoff.md § 4` to:
     * `lib/components/environment/river_bank_component.dart` (precompute and cache static paths `_soilPath`, `_turfPath`, `_rimPath`, and reuse paint instances).
     * `lib/components/environment/water_surface_component.dart` (reuse `_waterPath` and `_crestPath` via `.reset()`, cache `_cachedWaterShader`, and share `_sharedRipplePaint`).

4. Independent Toolchain Verification:
   - Run `flutter analyze` -> MUST report 0 issues, 0 warnings, 0 errors across the entire repository.
   - Run `flutter test` -> MUST pass 100% of all tests (67/67 tests passing).
   - Run `flutter build web` -> MUST compile cleanly with exit code 0.

OUTPUT REQUIREMENTS:
- Write your progress updates to c:\Users\Dibya\StudioProjects\monsoon_catch\.agents\teamwork\worker_r1_iter2\progress.md.
- Write your final handoff report to c:\Users\Dibya\StudioProjects\monsoon_catch\.agents\teamwork\worker_r1_iter2\handoff.md with all command outputs and verification evidence.
- Send a message to orchestrator (db28d72e-a68b-48dc-8d59-a662d180aa4e) when done.
