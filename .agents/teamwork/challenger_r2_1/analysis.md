# Empirical Analysis: Mathematical Models, Coordinates & Casting Continuity

- **Author**: Challenger 1 (`challenger_r2_1`)
- **Role**: Critic / Specialist (Empirical Verification & Stress-Testing)
- **Target**: Milestone R2 (Procedural Character, Rod Tip Math, Physics-Aware Fishing Line)
- **Date**: 2026-10-14T19:21:00Z
- **Test Harness**: `test/empirical_rod_line_stress_test.dart` (17 tests, 100% passing)
- **Total Project Test Suite**: 129 tests passing, 0 analyzer issues, clean web build (`flutter build web`)

---

## 1. Executive Summary

We conducted adversarial empirical stress-testing against the mathematical models, spatial coordinate derivations, kinematic continuity, and physics calculations introduced in Milestone R2.

All empirical hypotheses and constraints passed with zero defects:
1. **Analytical Rod Tip Coordinates**: Match exact trigonometric and parametric formulations across all 4 poses (`idle`, `casting`, `reeling`, `caught`).
2. **C0 Kinematic Continuity in Casting**: Verified across 10,000 sub-intervals on $t \in [0, 1]$ and strictly at piece-wise boundaries ($t = 0.25, 0.65, 0.85$); zero coordinate jumps, zero discontinuities ($\Delta < 10^{-4}\text{ px}$), zero NaNs.
3. **Rod Flex Deflection Under Strain**: Downward deflection under strain strictly exceeds $35.0\text{ px}$ ($36.75\text{ px} \le \Delta y \le 40.75\text{ px}$) relative to idle across all time phases of breathing bob and 14 Hz micro-jitter.
4. **Caught Pose Elevation**: Rod tip in celebratory caught pose is elevated by $28.02\text{ px}$ to $31.52\text{ px}$ above idle baseline ($y_{\text{idle}} - y_{\text{caught}} > 25.0\text{ px}$).
5. **Zero Line-to-Tip Floating Invariant**: Euclidean distance $\|\mathbf{P}_{\text{line\_start}} - \mathbf{P}_{\text{rodTip}}\| \equiv 0.0\text{ px}$ under all conditions, poses, and timestamps.
6. **Numerical Stability & Pathological Input Protection**: Zero division by zero, non-negative radicals, and clean sanitization under zero span ($P_1 = P_2$), microscopic spans ($10^{-7}\text{ px}$), astronomical spans ($10^6\text{ px}$), NaN, and $\pm\infty$.

---

## 2. Mathematical Rigor & Empirical Verification

### 2.1 Character Grounding & Rod Tip Analytical Formulas
Ground anchor platform: $(gx, gy) = (118.0, 208.8)$ with `Anchor.bottomCenter`.
Rod blank length: $L = 48.0\text{ px}$.

| Pose | Base Hand Anchor $P_0$ | Rod Tip Analytical Formula | Sampled Coordinates $(X, Y)$ | Empirical Test Result |
|---|---|---|---|---|
| `idle` | $(gx + 14, gy - 22.8 + \text{bob})$ where $\text{bob} = 0.8\sin(2\pi t / 2.4)$ | $tx = P_0.x + 48\cos(42^\circ)$<br>$ty = P_0.y - 48\sin(42^\circ)$ | $(167.671, 153.882 \pm 0.8)$ | **PASS** (241 time samples) |
| `casting` ($t=0.25$) | Windup apex: $(122.0, 176.0)$ | $\theta = 130^\circ$, smoothstep angle | $(91.146, 139.230)$ | **PASS** (Extrema verified) |
| `casting` ($t=0.65$) | Release flick: $(144.0, 182.0)$ | $\theta = 20^\circ$, chord $= 48.0$ | $(189.105, 165.583)$ | **PASS** (Extrema verified) |
| `reeling` / `strain` | Braced back: $(gx + 6, gy - 24.8) = (124.0, 184.0)$ | $chord = 41.5, \theta = -12^\circ$<br>$+ \text{jitter}(14\text{ Hz})$ | $(164.59 \pm 0.6, 192.63 \pm 1.2)$ | **PASS** (200 time samples) |
| `caught` | Triumphant: $(128.0, 172.0 + \text{hop})$ where $\text{hop} = -3.5\|\sin(4\pi t)\|$ | $tx = P_0.x + 48\cos(74^\circ)$<br>$ty = P_0.y - 48\sin(74^\circ)$ | $(141.231, 122.36 \text{ to } 125.86)$ | **PASS** (101 time samples) |

---

### 2.2 Continuity Analysis of Casting Whip Arc

The casting trajectory is defined by a 4-phase piece-wise parametric function $P(t) = (X(t), Y(t))$ for $t \in [0, 1]$:
- **Phase 1 ($t \in [0.0, 0.25)$)**: Back-cast windup using cubic smoothstep $s(\tau) = 3\tau^2 - 2\tau^3$ on angle $\theta \in [42^\circ, 130^\circ]$.
- **Phase 2 ($t \in [0.25, 0.65)$)**: Forward power whip from $130^\circ$ to $20^\circ$ with inertial lag flex $\Delta\theta = 46^\circ\sin(\pi\tau)$ and dynamic rod compression chord $c(\tau) = 48.0 - 5.5\sin(\pi\tau)$.
- **Phase 3 ($t \in [0.65, 0.85)$)**: Tip snap and damped recoil $\Delta\theta = -12^\circ(1-\tau)\sin(2\pi\tau)$ settling to $25^\circ$.
- **Phase 4 ($t \in [0.85, 1.00]$)**: Return to idle $42^\circ$.

#### Boundary Limit Verification:
- At $t = 0.25$:
  $$\lim_{t \to 0.25^-} P(t) = (91.1462, 139.2299), \quad \lim_{t \to 0.25^+} P(t) = (91.1462, 139.2299) \implies \|\Delta\| = 0.000000\text{ px}$$
- At $t = 0.65$:
  $$\lim_{t \to 0.65^-} P(t) = (189.1052, 165.5830), \quad \lim_{t \to 0.65^+} P(t) = (189.1052, 165.5830) \implies \|\Delta\| = 0.000000\text{ px}$$
- At $t = 0.85$:
  $$\lim_{t \to 0.85^-} P(t) = (187.5028, 161.7143), \quad \lim_{t \to 0.85^+} P(t) = (187.5028, 161.7143) \implies \|\Delta\| = 0.000000\text{ px}$$
- At $t = 1.00$:
  $$P(1.0) = (167.6709, 153.8817) \equiv P_{\text{idle}}(0.0)$$

#### Empirical Step Delta & Velocity Bounding:
- 10,000 uniform samples across $[0, 1]$ ($\Delta t = 10^{-4}$):
  * Maximum step delta: $\|\Delta P\|_{\text{max}} = 0.098\text{ px} < 0.15\text{ px}$.
  * Maximum normalized velocity: $v_{\text{max}} = 981.5\text{ px/s}$.
  * Zero discontinuities, zero sudden jumps, zero NaN / non-finite coordinates.

---

### 2.3 Rod Flex Strain Deflection ($> 35\text{ px}$ Requirement)

- **Idle Baseline Y**: $y_{\text{idle}}(t) = 153.882 + 0.8\sin(2\pi t / 2.4) \in [153.082, 154.682]$.
- **Strain Tip Y**: $y_{\text{strain}}(t) = 192.628 + 1.2\sin(28\pi t + \pi/4) \in [191.428, 193.828]$.
- **Downward Deflection**:
  $$\Delta y = y_{\text{strain}} - y_{\text{idle}}$$
  * Minimum downward drop (worst-case phase alignment): $191.428 - 154.682 = \mathbf{36.746\text{ px}} > 35.0\text{ px}$.
  * Nominal downward drop: $192.628 - 153.882 = \mathbf{38.746\text{ px}}$.
  * Maximum downward drop: $193.828 - 153.082 = \mathbf{40.746\text{ px}}$.
- **Empirical result**: Across 120 time intervals testing cross-phase combinations, $\Delta y > 35.0\text{ px}$ was true with 100% compliance.

---

### 2.4 Line Origin Binding Invariant ($0.0\text{ px}$ Delta)

The system ensures that the rendered fishing line starts exactly at the rod tip:
1. `FishingLineComponent` receives `rodTipProvider: () => character.rodTipPosition`.
2. Path begins at `_linePath.moveTo(p1.dx, p1.dy)` where `p1 = Offset(rodTip.x, rodTip.y)`.
3. In `FishingLineMath.evaluateCubicBezier(...)`, at $t = 0.0$, the Bernstein polynomial yields:
   $$B(0) = 1 \cdot P_1 + 0 \cdot C_1 + 0 \cdot C_2 + 0 \cdot P_2 = P_1$$
4. In `CharacterComponent.render(canvas)`, Flame translates to the bottom-center anchor, and the rod canvas curve terminates at $p_3 = \text{tipWorld} - \text{position}$. In screen coordinates, this renders precisely at `tipWorld`.
5. Therefore, $\|\mathbf{P}_{\text{line\_start}} - \mathbf{P}_{\text{rodTip}}\| \equiv \mathbf{0.000000\text{ px}}$.

---

### 2.5 Numerical Stability & Stress Harness Results

| Test Scenario | Input Vector | Expected Behavior | Observed Result | Status |
|---|---|---|---|---|
| Zero Distance Span | $P_1 = (167.67, 153.88), P_2 = (167.67, 153.88)$ | Degenerate protection, returns $C_1 = C_2 = P_1$, no $\frac{0}{0}$ | $C_1 = P_1, C_2 = P_1$ | **PASS** |
| Sub-pixel Span | Span $= 1.41 \times 10^{-6}\text{ px}$ | Returns endpoints safely, no infinite gradient | All coords finite | **PASS** |
| Giant Distance Span | $P_2.x = 1,000,167.67$ ($L = 10^6\text{ px}$) | Sag clamped by $kMaxSag = 38.0\text{ px}$ | $\text{Sag} = 38.00\text{ px}$ | **PASS** |
| Reversed Geometry | Bobber behind or above rod ($dx < 0, dy < 0$) | Safe vector algebra without negative square root | All coords finite | **PASS** |
| Corrupted / NaN Inputs | $P_1 = (\text{NaN}, \text{NaN})$, $\tau = \text{NaN}$ | Sanitization fallback to $(0, 0)$ and $\tau = 0.0$ | All outputs finite | **PASS** |
| Infinite Inputs | $P_1 = (\infty, -\infty)$, $\tau = \infty$ | Clamped and sanitized | All outputs finite | **PASS** |
| Parameter Out-of-Bounds | $t = -10.0$ and $t = +10.0$ in Bezier | Clamped to $0.0$ and $1.0$ respectively | Exact endpoints | **PASS** |

---

## 3. Overall Verification Status

- Automated Unit & Stress Tests: 129 passed / 0 failed.
- Static Analysis (`flutter analyze`): 0 issues (0 errors, 0 warnings).
- Web Target Compilation (`flutter build web`): Successful (exit code 0).
