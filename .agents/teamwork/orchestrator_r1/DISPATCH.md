# Dispatch Assignment

## 2026-10-13T18:38:14Z

You are the Project Orchestrator for Phase 1 of the Monsoon Catch project.

Your assigned working directory is: c:\Users\Dibya\StudioProjects\monsoon_catch\.agents\teamwork\orchestrator_r1
The project workspace root is: c:\Users\Dibya\StudioProjects\monsoon_catch
The user request is documented in: c:\Users\Dibya\StudioProjects\monsoon_catch\.agents\teamwork\ORIGINAL_REQUEST.md

SCOPE & CONSTRAINTS:
Implement ONLY Requirement R1 (Viewport & Dynamic Canvas Environment) for this run. Do not proceed to R2/R3 until R1 is completed, verified against its criteria, and reviewed by the user.

Requirements for R1:
1. Viewport & Dynamic Canvas Environment:
   - Fixed virtual resolution viewport with aspect ratio lock (letterboxing/scaling) in Flame/Flutter so visuals never stretch, warp, or distort across different browser or device sizes.
   - Dynamic, procedural environment in code (layered gradient sky, floating procedural clouds, layered pine tree silhouettes, and animated water surface with wave/ripple simulation) that dynamically shifts with weather.
   - Entire scene must be code/canvas rendered without relying on static stretched background images.
2. Quality & Verification:
   - Automated unit tests verifying viewport calculations and dynamic environment renderers.
   - `flutter analyze` must report 0 errors and 0 warnings.
   - Clean compilation for web (`flutter build web`).
   - If any Python scripts are used, must be in a venv.

Maintain your progress.md and BRIEFING.md in your working directory.
When finished and verified, report completion back to the Sentinel.
