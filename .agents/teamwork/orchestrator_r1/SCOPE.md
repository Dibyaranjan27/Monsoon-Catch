# Scope: Milestone R1 — Viewport & Dynamic Canvas Environment

## Architecture
- Flame Game engine running within Flutter application.
- CameraComponent with FixedResolutionViewport (or letterboxing/scaling viewport) ensuring aspect ratio preservation without distortion on any window/display resolution.
- Dynamic environment components:
  1. SkyComponent: procedural gradient rendering, dynamically reacting to weather parameters (clear, overcast, monsoon).
  2. CloudComponent: procedural floating clouds across sky layer.
  3. PineTreeSilhouettes: multi-layered parallax pine tree silhouettes with atmospheric depth.
  4. RiverBankComponent: terrain/bank rendering separating land and water.
  5. WaterSurfaceComponent: animated procedural water surface with wave/ripple simulation and depth gradient.
  6. WeatherState: model or notifier driving dynamic environment shifts.
- Zero reliance on static stretched background bitmaps — fully code/canvas rendered.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Fixed Virtual Resolution Viewport | Flame Camera with letterboxing/scaling ensuring non-stretched rendering | M1 (R1) | ORIGINAL_REQUEST §R1 |
| 2 | Procedural Gradient Sky | Dynamic gradient sky rendering shifting with weather | M1 (R1) | ORIGINAL_REQUEST §R1 |
| 3 | Floating Procedural Clouds | Procedural cloud rendering and floating motion across sky | M1 (R1) | ORIGINAL_REQUEST §R1 |
| 4 | Layered Pine Tree Silhouettes | Background and midground pine tree silhouettes for depth | M1 (R1) | ORIGINAL_REQUEST §R1 |
| 5 | Animated Water Surface & Waves | Wave/ripple simulation with dynamic water layers | M1 (R1) | ORIGINAL_REQUEST §R1 |
| 6 | Weather Parameter Shift | Dynamic parameter-driven shift in environment colors/atmosphere | M1 (R1) | ORIGINAL_REQUEST §R1 |
| 7 | Automated Unit & Component Tests | Tests verifying viewport math, scaling, and canvas renderers | M1 (R1) | ORIGINAL_REQUEST §R4 |
| 8 | Build and Analysis Quality | 0 errors/warnings on `flutter analyze`, clean `flutter build web` | M1 (R1) | ORIGINAL_REQUEST §R4 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | M1: Viewport & Dynamic Canvas Environment | Viewport, Canvas Renderers, Tests, Web Build | none | IN_PROGRESS |

## Interface Contracts
### Viewport ↔ Game World
- Virtual resolution (e.g. 320x180 or 640x360 for pixel-art cozy game, aspect ratio 16:9).
- CameraComponent with FixedResolutionViewport / FixedAspectRatioViewport.
### WeatherState ↔ Environment Renderers
- Weather parameters (e.g. rainIntensity, windSpeed, skyDarkness, cloudDensity).
- Renderers listen to or read weather state to modulate gradient colors, wave frequency/amplitude, and cloud drift.
