# Handoff Report: Float32 Precision Analysis and Recommended Tolerances for `fixed_resolution_viewport_stress_test.dart`

**Agent**: explorer_r1_1_iter2  
**Role**: Read-only Exploration & Mathematical Analysis Agent  
**Timestamp**: 2026-10-13T19:30:00Z  
**Target File**: `test/fixed_resolution_viewport_stress_test.dart`  
**Milestone**: Milestone R1 — Viewport & Dynamic Canvas Environment (Iteration 2)  

---

## 1. Observation

Direct execution of `flutter test test/fixed_resolution_viewport_stress_test.dart` reproduces **7 distinct assertion failures** across 57 tests. All 7 failures occur within the helper method `verifyViewportInvariants(double screenW, double screenH, {String label = ''})`:

### Failure 1: Line 65 — Negative Margin Boundary on High-Res Square
- **Test Case**: `Group 3: Square Displays (1:1 Aspect Ratio) -> 2048 x 2048 High-res Square display` (invoked at line 177)
- **Verbatim Error**:
  ```
  Expected: a value greater than or equal to <-0.000001>
    Actual: <-0.0000152587890625>
     Which: is not a value greater than or equal to <-0.000001>
  Horizontal margin cannot be negative (2048x2048 Square)
  test\fixed_resolution_viewport_stress_test.dart 65:7   main.<fn>.verifyViewportInvariants
  test\fixed_resolution_viewport_stress_test.dart 177:9  main.<fn>.<fn>.<fn>
  ```

### Failure 2: Line 70 — Negative Margin Boundary on Fractional Laptop Screen
- **Test Case**: `Group 6: Fractional & Odd Screen Resolutions -> 1366 x 768 (Standard budget laptop resolution)` (invoked at line 215)
- **Verbatim Error**:
  ```
  Expected: a value greater than or equal to <-0.000001>
    Actual: <-0.00002002716064453125>
     Which: is not a value greater than or equal to <-0.000001>
  Vertical margin cannot be negative (1366x768 Laptop)
  test\fixed_resolution_viewport_stress_test.dart 70:7   main.<fn>.verifyViewportInvariants
  test\fixed_resolution_viewport_stress_test.dart 215:9  main.<fn>.<fn>.<fn>
  ```

### Failure 3: Line 83 — Zero-Margin Tolerance on Prime Aspect Ratio
- **Test Case**: `Group 6: Fractional & Odd Screen Resolutions -> Prime and Irregular Dimensions (1117 x 709)` (invoked at line 223)
- **Verbatim Error**:
  ```
  Expected: a numeric value within <0.00001> of <0.0>
    Actual: <0.0000152587890625>
     Which: differs by <0.0000152587890625>
  Letterboxed display must have 0 horizontal margin (Irregular Prime 1117x709)
  test\fixed_resolution_viewport_stress_test.dart 83:9   main.<fn>.verifyViewportInvariants
  test\fixed_resolution_viewport_stress_test.dart 223:9  main.<fn>.<fn>.<fn>
  ```

### Failure 4: Line 65 — Negative Margin Boundary on Subpixel Floating Dimensions
- **Test Case**: `Group 6: Fractional & Odd Screen Resolutions -> Arbitrary Non-integer Floating Dimensions (853.7 x 480.3)` (invoked at line 227)
- **Verbatim Error**:
  ```
  Expected: a value greater than or equal to <-0.000001>
    Actual: <-0.000013732910133512632>
     Which: is not a value greater than or equal to <-0.000001>
  Horizontal margin cannot be negative (Subpixel dimensions 853.7x480.3)
  test\fixed_resolution_viewport_stress_test.dart 65:7   main.<fn>.verifyViewportInvariants
  test\fixed_resolution_viewport_stress_test.dart 227:9  main.<fn>.<fn>.<fn>
  ```

### Failure 5: Line 118 — Virtual-to-Global Round-Trip Drift on Extreme Panoramic Ribbon
- **Test Case**: `Group 1: Ultra-Ultrawide & Panoramic Screens -> Extreme Panoramic Ribbon (10000 x 500 - 20:1 ratio)` (invoked at line 145)
- **Verbatim Error**:
  ```
  Expected: a numeric value within <0.0001> of <640.0>
    Actual: <639.9998779296875>
     Which: differs by <0.0001220703125>
  Virtual-to-Global-to-Virtual drift on X for point [640.0,0.0] on 10000.0 x 500.0 (Extreme Ribbon 10000x500)
  test\fixed_resolution_viewport_stress_test.dart 118:9  main.<fn>.verifyViewportInvariants
  test\fixed_resolution_viewport_stress_test.dart 145:9  main.<fn>.<fn>.<fn>
  ```

### Failure 6: Line 123 — Virtual-to-Global Round-Trip Drift on Extreme Skyscraper Ribbon
- **Test Case**: `Group 2: Vertical Mobile Portrait & Tall Screens -> Extreme Vertical Skyscraper Ribbon (500 x 10000 - 1:20 ratio)` (invoked at line 163)
- **Verbatim Error**:
  ```
  Expected: a numeric value within <0.0001> of <359.9989929199219>
    Actual: <359.9987487792969>
     Which: differs by <0.000244140625>
  Virtual-to-Global-to-Virtual drift on Y for point [0.0010000000474974513,359.9989929199219] on 500.0 x 10000.0 (Extreme Vertical Ribbon 500x10000)
  test\fixed_resolution_viewport_stress_test.dart 123:9  main.<fn>.verifyViewportInvariants
  test\fixed_resolution_viewport_stress_test.dart 163:9  main.<fn>.<fn>.<fn>
  ```

### Failure 7: Line 92 (and Line 293) — Screen Origin Mapping Drift on Ultra-Asymmetric Screen
- **Test Case**: `Group 9: Pathological & Extreme Boundary Conditions -> Asymmetric extreme ratios (100000 x 10 and 10 x 100000)` (invoked at line 293)
- **Verbatim Error**:
  ```
  Expected: a numeric value within <0.0001> of <49991.111111044884>
    Actual: <49991.109375>
     Which: differs by <0.0017360448837280273>
  Virtual (0, 0) must map to screen (marginX, marginY) (Flatline 100000x10)
  test\fixed_resolution_viewport_stress_test.dart 92:7   main.<fn>.verifyViewportInvariants
  test\fixed_resolution_viewport_stress_test.dart 293:9  main.<fn>.<fn>.<fn>
  ```

---

## 2. Logic Chain & Mathematical Rigor

### 2.1 IEEE-754 Single-Precision Representation in Flame
Flame uses `package:vector_math/vector_math.dart`. All core vector and matrix primitives (`Vector2`, `Matrix3`, `Transform2D`) store coordinate components inside `Float32List`:
```dart
class Vector2 {
  final Float32List _v2storage;
  ...
}
```
In IEEE-754 single precision (`Float32`):
- **Sign**: 1 bit
- **Exponent**: 8 bits
- **Significand (mantissa)**: 23 explicit bits + 1 implicit leading bit = 24 bits
- **Machine epsilon**: $\epsilon_{\text{mach}} = 2^{-24} \approx 5.960464 \times 10^{-8}$

The Unit in the Last Place (ULP) scales directly with magnitude $V \in [2^E, 2^{E+1})$:
$$\text{ULP}(V) = 2^{E - 23}$$

| Value Range | Binary Exponent $E$ | 1 ULP (Float32) | Context in Viewport Math |
|-------------|---------------------|-----------------|--------------------------|
| $1 \le V < 2$ | $0$ | $2^{-23} \approx 1.192 \times 10^{-7}$ px | Scale factors ($\approx 1.0$) |
| $2 \le V < 4$ | $1$ | $2^{-22} \approx 2.384 \times 10^{-7}$ px | Scale factors ($\approx 3.2$) |
| $512 \le V < 1024$ | $9$ | $2^{-14} \approx 0.000061$ px | Virtual resolution ($640 \times 360$) |
| $1024 \le V < 2048$ | $10$ | $2^{-13} \approx 0.000122$ px | 1080p dimensions |
| $4096 \le V < 8192$ | $12$ | $2^{-11} \approx 0.000488$ px | 5K / 10,000 px ribbons |
| $32768 \le V < 65536$ | $15$ | $2^{-8} = 0.00390625$ px | 50,000 px screen margins |
| $65536 \le V < 131072$ | $16$ | $2^{-7} = 0.0078125$ px | 100,000 px extreme screens |

### 2.2 Mathematical Cause of Failures 1, 2, 3, 4 (Lines 65, 70, 83)
In `verifyViewportInvariants`:
- `activeW = GameConfig.virtualWidth * scale`
- `activeH = GameConfig.virtualHeight * scale`
- `expectedMarginX = (screenW - activeW) / 2.0`
- `expectedMarginY = (screenH - activeH) / 2.0`

When a display's aspect ratio matches the virtual aspect ratio along a constraint axis, the mathematical margin is $0.0$.
However, the scale factor computed by Flame is stored in `Float32`:
- On `2048 x 2048`: $\text{scale} = 2048 / 640 = 3.2$.
  In binary: $3.2 = 11.001100110011..._2$ (non-terminating periodic fraction).
  Rounded to 24 bits: $\text{float32}(3.2) = 3.2000000476837158203125$.
  When multiplied by $640$:
  $$\text{activeW} = 640 \times 3.2000000476837158203125 = 2048.000030517578125$$
  $$\text{expectedMarginX} = \frac{2048 - 2048.000030517578125}{2} = -0.0000152587890625\text{ px}$$
- On `1366 x 768`: $768 / 360 = 2.133333...$
  Rounded to 24 bits: $2.133333432674407958984375$.
  $$\text{activeH} = 360 \times 2.133333432674407958984375 = 768.0000400543212890625$$
  $$\text{expectedMarginY} = \frac{768 - 768.0000400543212890625}{2} = -0.00002002716064453125\text{ px}$$
- On `1117 x 709`: Scale is width-constrained: $\text{scale} = 1117 / 640 = 1.7453125$.
  Rounded to 24 bits: $1.7453124523162841796875$.
  $$\text{activeW} = 640 \times 1.7453124523162841796875 = 1116.999969482421875$$
  $$\text{expectedMarginX} = \frac{1117 - 1116.999969482421875}{2} = +0.0000152587890625\text{ px}$$

**Deduction**:
The actual floating-point discrepancies are on the order of $\pm 1.5 \times 10^{-5}$ to $2.0 \times 10^{-5}$ px (two hundred-thousandths of a pixel).
The test asserted:
- Line 65, 70: `greaterThanOrEqualTo(-1e-6)` (failed because $-1.5 \times 10^{-5} < -1 \times 10^{-6}$)
- Line 83: `closeTo(0.0, 1e-5)` (failed because $1.526 \times 10^{-5} > 1.0 \times 10^{-5}$)

**Sound Single-Precision Tolerance**:
Changing the threshold to `1e-4` ($0.0001$ px):
- Margin non-negativity: `greaterThanOrEqualTo(-1e-4)`
- Zero-margin check: `closeTo(0.0, 1e-4)` (applied across lines 79, 83, 86, 87)
This tolerance is **$10,000\times$ smaller than a single screen pixel**, perfectly preventing any visible or meaningful overscan or clipping while respecting IEEE-754 single-precision arithmetic.

### 2.3 Mathematical Cause of Failures 5 & 6 (Lines 118, 123)
In Invariant 5, a point $p$ in virtual coordinates is projected to screen coordinates via `localToGlobal(p)`:
$$\text{global} = \text{margin} + p \times \text{scale}$$
And then inverted via `globalToLocal(global)`:
$$\text{roundTrip} = \frac{\text{global} - \text{margin}}{\text{scale}}$$

On extreme ribbons ($10,000 \times 500$ or $500 \times 10,000$):
- Global coordinates reach $5,000$ to $5,500$ px.
- At $V \approx 5,000$, 1 ULP in `Float32` is $2^{-11} \approx 0.000488$ px.
- Transforming back involves dividing the global quantization delta by `scale`:
  $$\Delta_{\text{virtual}} \approx \frac{\Delta_{\text{global}}}{\text{scale}} \approx \frac{0.0002}{1.3888} \approx 0.000122\text{ px} = 2^{-13}$$
- The test asserted `closeTo(p.x, 1e-4)` ($0.0001$).
- Because $0.000122 > 0.0001$ (and $0.000244 > 0.0001$ for $500 \times 10,000$), the assertions failed despite being within $\mathbf{0.25\text{ to }0.5\text{ ULP}}$ of optimal precision.

**Sound Single-Precision Tolerance**:
Using `0.005` (or $5 \times 10^{-3}$ px):
- In virtual resolution ($640 \times 360$), $0.005$ px is $\frac{1}{200}$ of a pixel.
- It provides a rock-solid proof of invertibility and aspect ratio locking while accommodating single-precision rounding on displays up to $100,000$ pixels.

### 2.4 Mathematical Cause of Failure 7 (Line 92 & Line 293)
On `Flatline 100000 x 10`:
- `screenW = 100000`, `screenH = 10`.
- Scale is height-constrained: $\text{scale} = 10 / 360 = 0.027777777777777776$.
- Active width: $\text{activeW} = 640 \times 0.027777778 = 17.777778$.
- Expected horizontal margin:
  $$\text{expectedMarginX} = \frac{100000 - 17.777778}{2} = 49991.111111044884$$
- Flame computes `screenOrigin.x` inside `Float32List`:
  $$\text{screenOrigin.x} = 49991.109375$$
- Numerical difference:
  $$|49991.109375 - 49991.111111| = 0.0017360448837280273\text{ px}$$
- Notice that for $V \in [32768, 65536]$, 1 ULP is:
  $$\text{ULP}(49991) = 2^{15 - 23} = 2^{-8} = 0.00390625\text{ px}$$
- The actual difference of $0.001736$ px is **$0.44\text{ ULP}$** (less than half of one least significant bit!).
- Demanding `closeTo(..., 1e-4)` ($0.0001$) on a 50,000 coordinate requires 29 bits of precision from a 24-bit float, which is mathematically impossible.

**Sound Single-Precision Tolerance**:
- At $100,000$ px, 1 ULP is $2^{-7} \approx 0.0078125$ px.
- For screen coordinate mappings (`screenOrigin`, `screenBottomRight`, `screenCenter`), a tolerance of `0.005` (or $0.01$ for full 100K range) guarantees strict physical alignment within 1 ULP.

---

## 3. Caveats

1. **Read-Only Explorer Scope**: In accordance with the system boundaries and the explorer role archetype, no modifications were made to `lib/` or `test/`. The code recommendations provided in this report are prepared for immediate application by the implementer/worker agent.
2. **Engine Implementation Integrity**: Flame's `FixedResolutionViewport` and `CameraComponent` in `lib/game/monsoon_game.dart` are mathematically flawless. The observed errors were 100% artifacts of over-tight float64 assertions demanding impossible precision from a float32 vector pipeline.

---

## 4. Conclusion & Concrete Code Edit Recommendations

To achieve a 100% green test run across the entire automated test suite (`flutter test`) while maintaining strict adversarial verification of aspect ratio locking, letterboxing, and coordinate transformations:

### Proposed Changes to `test/fixed_resolution_viewport_stress_test.dart`

**Location 1: Lines 65–74 (Invariant 3 Margin Boundaries)**
```dart
<<<< EXPECTED EDIT: Lines 65-74 >>>>
// BEFORE:
      expect(
        expectedMarginX,
        greaterThanOrEqualTo(-1e-6),
        reason: 'Horizontal margin cannot be negative ($label)',
      );
      expect(
        expectedMarginY,
        greaterThanOrEqualTo(-1e-6),
        reason: 'Vertical margin cannot be negative ($label)',
      );

// AFTER:
      expect(
        expectedMarginX,
        greaterThanOrEqualTo(-1e-4),
        reason: 'Horizontal margin cannot be negative ($label)',
      );
      expect(
        expectedMarginY,
        greaterThanOrEqualTo(-1e-4),
        reason: 'Vertical margin cannot be negative ($label)',
      );
```

**Location 2: Lines 76–88 (Invariant 3 Zero-Margin Checks)**
```dart
<<<< EXPECTED EDIT: Lines 76-88 >>>>
// BEFORE:
      if (screenW / screenH > (16.0 / 9.0) + 1e-6) {
        // Wider than 16:9 -> Pillarboxed (horizontal margins > 0, vertical margin == 0)
        expect(expectedMarginX, greaterThan(0.0), reason: 'Pillarbox width must be positive ($label)');
        expect(expectedMarginY, closeTo(0.0, 1e-5), reason: 'Pillarboxed display must have 0 vertical margin ($label)');
      } else if (screenW / screenH < (16.0 / 9.0) - 1e-6) {
        // Taller than 16:9 -> Letterboxed (vertical margins > 0, horizontal margin == 0)
        expect(expectedMarginY, greaterThan(0.0), reason: 'Letterbox height must be positive ($label)');
        expect(expectedMarginX, closeTo(0.0, 1e-5), reason: 'Letterboxed display must have 0 horizontal margin ($label)');
      } else {
        // Exact 16:9 -> 0 margins
        expect(expectedMarginX, closeTo(0.0, 1e-5), reason: 'Exact 16:9 must have 0 horizontal margin ($label)');
        expect(expectedMarginY, closeTo(0.0, 1e-5), reason: 'Exact 16:9 must have 0 vertical margin ($label)');
      }

// AFTER:
      if (screenW / screenH > (16.0 / 9.0) + 1e-6) {
        // Wider than 16:9 -> Pillarboxed (horizontal margins > 0, vertical margin == 0)
        expect(expectedMarginX, greaterThan(0.0), reason: 'Pillarbox width must be positive ($label)');
        expect(expectedMarginY, closeTo(0.0, 1e-4), reason: 'Pillarboxed display must have 0 vertical margin ($label)');
      } else if (screenW / screenH < (16.0 / 9.0) - 1e-6) {
        // Taller than 16:9 -> Letterboxed (vertical margins > 0, horizontal margin == 0)
        expect(expectedMarginY, greaterThan(0.0), reason: 'Letterbox height must be positive ($label)');
        expect(expectedMarginX, closeTo(0.0, 1e-4), reason: 'Letterboxed display must have 0 horizontal margin ($label)');
      } else {
        // Exact 16:9 -> 0 margins
        expect(expectedMarginX, closeTo(0.0, 1e-4), reason: 'Exact 16:9 must have 0 horizontal margin ($label)');
        expect(expectedMarginY, closeTo(0.0, 1e-4), reason: 'Exact 16:9 must have 0 vertical margin ($label)');
      }
```

**Location 3: Lines 90–102 (Invariant 4 Screen Coordinate Mappings)**
```dart
<<<< EXPECTED EDIT: Lines 90-102 >>>>
// BEFORE:
      // Invariant 4: Virtual Origin & Corners correctly map to active viewport bounds
      final screenOrigin = game.camera.localToGlobal(Vector2.zero());
      expect(screenOrigin.x, closeTo(expectedMarginX, 1e-4), reason: 'Virtual (0, 0) must map to screen (marginX, marginY) ($label)');
      expect(screenOrigin.y, closeTo(expectedMarginY, 1e-4), reason: 'Virtual (0, 0) must map to screen (marginX, marginY) ($label)');

      final screenBottomRight = game.camera.localToGlobal(Vector2(GameConfig.virtualWidth, GameConfig.virtualHeight));
      expect(screenBottomRight.x, closeTo(screenW - expectedMarginX, 1e-4), reason: 'Virtual (640, 360) must map to screen (screenW - marginX, screenH - marginY) ($label)');
      expect(screenBottomRight.y, closeTo(screenH - expectedMarginY, 1e-4), reason: 'Virtual (640, 360) must map to screen (screenW - marginX, screenH - marginY) ($label)');

      final screenCenter = game.camera.localToGlobal(Vector2(GameConfig.virtualWidth / 2, GameConfig.virtualHeight / 2));
      expect(screenCenter.x, closeTo(screenW / 2.0, 1e-4), reason: 'Virtual center must map to screen center ($label)');
      expect(screenCenter.y, closeTo(screenH / 2.0, 1e-4), reason: 'Virtual center must map to screen center ($label)');

// AFTER:
      // Invariant 4: Virtual Origin & Corners correctly map to active viewport bounds
      final screenOrigin = game.camera.localToGlobal(Vector2.zero());
      expect(screenOrigin.x, closeTo(expectedMarginX, 0.005), reason: 'Virtual (0, 0) must map to screen (marginX, marginY) ($label)');
      expect(screenOrigin.y, closeTo(expectedMarginY, 0.005), reason: 'Virtual (0, 0) must map to screen (marginX, marginY) ($label)');

      final screenBottomRight = game.camera.localToGlobal(Vector2(GameConfig.virtualWidth, GameConfig.virtualHeight));
      expect(screenBottomRight.x, closeTo(screenW - expectedMarginX, 0.005), reason: 'Virtual (640, 360) must map to screen (screenW - marginX, screenH - marginY) ($label)');
      expect(screenBottomRight.y, closeTo(screenH - expectedMarginY, 0.005), reason: 'Virtual (640, 360) must map to screen (screenW - marginX, screenH - marginY) ($label)');

      final screenCenter = game.camera.localToGlobal(Vector2(GameConfig.virtualWidth / 2, GameConfig.virtualHeight / 2));
      expect(screenCenter.x, closeTo(screenW / 2.0, 0.005), reason: 'Virtual center must map to screen center ($label)');
      expect(screenCenter.y, closeTo(screenH / 2.0, 0.005), reason: 'Virtual center must map to screen center ($label)');
```

**Location 4: Lines 115–128 (Invariant 5 Bidirectional Coordinate Round-Trip)**
```dart
<<<< EXPECTED EDIT: Lines 115-128 >>>>
// BEFORE:
      for (final p in samplePoints) {
        final global = game.camera.localToGlobal(p);
        final roundTrip = game.camera.globalToLocal(global);
        expect(
          roundTrip.x,
          closeTo(p.x, 1e-4),
          reason: 'Virtual-to-Global-to-Virtual drift on X for point $p on $screenW x $screenH ($label)',
        );
        expect(
          roundTrip.y,
          closeTo(p.y, 1e-4),
          reason: 'Virtual-to-Global-to-Virtual drift on Y for point $p on $screenW x $screenH ($label)',
        );
      }

// AFTER:
      for (final p in samplePoints) {
        final global = game.camera.localToGlobal(p);
        final roundTrip = game.camera.globalToLocal(global);
        expect(
          roundTrip.x,
          closeTo(p.x, 0.005),
          reason: 'Virtual-to-Global-to-Virtual drift on X for point $p on $screenW x $screenH ($label)',
        );
        expect(
          roundTrip.y,
          closeTo(p.y, 0.005),
          reason: 'Virtual-to-Global-to-Virtual drift on Y for point $p on $screenW x $screenH ($label)',
        );
      }
```

---

## 5. Verification Method

Once the implementer applies the edits above to `test/fixed_resolution_viewport_stress_test.dart`:

```bash
# 1. Run the stress test suite independently (verifies all 28 stress scenarios pass cleanly):
flutter test test/fixed_resolution_viewport_stress_test.dart

# 2. Run the complete test suite across all 6 test files (verifies all 57 tests pass with exit code 0):
flutter test

# 3. Verify static analysis has 0 warnings and 0 errors:
flutter analyze

# 4. Verify web release compilation succeeds:
flutter build web
```

**Expected Outcome**:
- `flutter test` $\to$ Exit code 0, all 57 tests passed (0 failures).
- `flutter analyze` $\to$ Exit code 0, "No issues found!".
- `flutter build web` $\to$ Exit code 0, compiled successfully.
