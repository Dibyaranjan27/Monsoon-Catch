import 'dart:math' as math;
import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monsoon_catch/config/game_config.dart';
import 'package:monsoon_catch/game/monsoon_game.dart';

void main() {
  group('FixedResolutionViewport Adversarial Stress Tests', () {
    late MonsoonGame game;

    setUp(() async {
      game = MonsoonGame();
      await game.onLoad();
    });

    test('Verification of FixedResolutionViewport properties and baseline setup', () {
      expect(game.camera.viewport, isA<FixedResolutionViewport>());
      final viewport = game.camera.viewport as FixedResolutionViewport;
      expect(viewport.resolution.x, equals(GameConfig.virtualWidth));
      expect(viewport.resolution.y, equals(GameConfig.virtualHeight));
      expect(GameConfig.virtualWidth / GameConfig.virtualHeight, closeTo(16.0 / 9.0, 1e-9));
      expect(game.camera.viewfinder.anchor, equals(Anchor.topLeft));
      expect(game.camera.viewfinder.position, equals(Vector2.zero()));
    });

    // Helper function to verify all core mathematical invariants for any arbitrary screen resolution
    void verifyViewportInvariants(double screenW, double screenH, {String label = ''}) {
      game.onGameResize(Vector2(screenW, screenH));
      final viewport = game.camera.viewport as FixedResolutionViewport;

      // Invariant 1: Uniform Scaling (isotropic, never independent x/y)
      expect(
        viewport.scale.x,
        equals(viewport.scale.y),
        reason: 'Scale must be strictly uniform for $screenW x $screenH ($label). Found x=${viewport.scale.x}, y=${viewport.scale.y}',
      );

      final double scale = viewport.scale.x;
      final double expectedScale = math.min(
        screenW / GameConfig.virtualWidth,
        screenH / GameConfig.virtualHeight,
      );

      expect(
        scale,
        closeTo(expectedScale, 1e-6),
        reason: 'Scale factor must strictly match min(screenW/640, screenH/360) for $screenW x $screenH ($label)',
      );

      // Invariant 2: Active Render Area Aspect Ratio Lock
      final double activeW = GameConfig.virtualWidth * scale;
      final double activeH = GameConfig.virtualHeight * scale;
      final double activeAspect = activeW / activeH;
      expect(
        activeAspect,
        closeTo(16.0 / 9.0, 1e-6),
        reason: 'Active render area aspect ratio must remain strictly 16:9 ($label)',
      );

      // Invariant 3: Symmetrical Letterbox / Pillarbox Margins
      final double expectedMarginX = (screenW - activeW) / 2.0;
      final double expectedMarginY = (screenH - activeH) / 2.0;

      // Realistic Float32 tolerances: Flame Vector2 coordinates are single-precision Float32List
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

      if (screenW / screenH > (16.0 / 9.0) + 1e-5) {
        // Wider than 16:9 -> Pillarboxed (horizontal margins > 0, vertical margin == 0)
        expect(expectedMarginX, greaterThan(0.0), reason: 'Pillarbox width must be positive ($label)');
        expect(expectedMarginY, closeTo(0.0, 1e-4), reason: 'Pillarboxed display must have 0 vertical margin ($label)');
      } else if (screenW / screenH < (16.0 / 9.0) - 1e-5) {
        // Taller than 16:9 -> Letterboxed (vertical margins > 0, horizontal margin == 0)
        expect(expectedMarginY, greaterThan(0.0), reason: 'Letterbox height must be positive ($label)');
        expect(expectedMarginX, closeTo(0.0, 1e-4), reason: 'Letterboxed display must have 0 horizontal margin ($label)');
      } else {
        // Exact 16:9 -> 0 margins
        expect(expectedMarginX, closeTo(0.0, 1e-4), reason: 'Exact 16:9 must have 0 horizontal margin ($label)');
        expect(expectedMarginY, closeTo(0.0, 1e-4), reason: 'Exact 16:9 must have 0 vertical margin ($label)');
      }

      // Invariant 4: Virtual Origin & Corners correctly map to active viewport bounds
      // Note: At 100,000 px screen coordinates, 1 Float32 ULP is ~0.003 px; 0.005 px ensures Float32 compatibility.
      final screenOrigin = game.camera.localToGlobal(Vector2.zero());
      expect(screenOrigin.x, closeTo(expectedMarginX, 0.005), reason: 'Virtual (0, 0) must map to screen (marginX, marginY) ($label)');
      expect(screenOrigin.y, closeTo(expectedMarginY, 0.005), reason: 'Virtual (0, 0) must map to screen (marginX, marginY) ($label)');

      final screenBottomRight = game.camera.localToGlobal(Vector2(GameConfig.virtualWidth, GameConfig.virtualHeight));
      expect(screenBottomRight.x, closeTo(screenW - expectedMarginX, 0.005), reason: 'Virtual (640, 360) must map to screen (screenW - marginX, screenH - marginY) ($label)');
      expect(screenBottomRight.y, closeTo(screenH - expectedMarginY, 0.005), reason: 'Virtual (640, 360) must map to screen (screenW - marginX, screenH - marginY) ($label)');

      final screenCenter = game.camera.localToGlobal(Vector2(GameConfig.virtualWidth / 2, GameConfig.virtualHeight / 2));
      expect(screenCenter.x, closeTo(screenW / 2.0, 0.005), reason: 'Virtual center must map to screen center ($label)');
      expect(screenCenter.y, closeTo(screenH / 2.0, 0.005), reason: 'Virtual center must map to screen center ($label)');

      // Invariant 5: Exact Bidirectional Coordinate Round-Trip with Zero Drift
      // Note: Flame Vector2 coordinates are single-precision Float32List.
      // At standard resolutions (<= 10,000px), 5 milli-pixels (0.005) rigorously bounds precision.
      // At pathological scales (> 10,000px with 10,000:1 ratios), 1 Float32 ULP (~0.004) magnified by 1/scale (36)
      // requires 0.1 px (~1/6400th of virtual width).
      final double roundTripTolerance = (screenW > 10000 || screenH > 10000) ? 0.1 : 0.005;

      final List<Vector2> samplePoints = [
        Vector2(0, 0),
        Vector2(GameConfig.virtualWidth, 0),
        Vector2(0, GameConfig.virtualHeight),
        Vector2(GameConfig.virtualWidth, GameConfig.virtualHeight),
        Vector2(GameConfig.virtualWidth / 2, GameConfig.virtualHeight / 2),
        Vector2(123.456, 78.910),
        Vector2(0.001, 359.999),
        Vector2(639.999, 0.001),
      ];

      for (final p in samplePoints) {
        final global = game.camera.localToGlobal(p);
        final roundTrip = game.camera.globalToLocal(global);
        expect(
          roundTrip.x,
          closeTo(p.x, roundTripTolerance),
          reason: 'Virtual-to-Global-to-Virtual drift on X for point $p on $screenW x $screenH ($label)',
        );
        expect(
          roundTrip.y,
          closeTo(p.y, roundTripTolerance),
          reason: 'Virtual-to-Global-to-Virtual drift on Y for point $p on $screenW x $screenH ($label)',
        );
      }
    }

    group('1. Ultra-Ultrawide & Panoramic Screens', () {
      test('32:9 Super Ultrawide (3840 x 1080)', () {
        verifyViewportInvariants(3840, 1080, label: '32:9 Super Ultrawide 3840x1080');
      });

      test('32:9 5K Super Ultrawide (5120 x 1440)', () {
        verifyViewportInvariants(5120, 1440, label: '32:9 Dual QHD 5120x1440');
      });

      test('21:9 Standard Ultrawide (3440 x 1440)', () {
        verifyViewportInvariants(3440, 1440, label: '21:9 WQHD 3440x1440');
      });

      test('Extreme Panoramic Ribbon (10000 x 500 - 20:1 ratio)', () {
        verifyViewportInvariants(10000, 500, label: 'Extreme Ribbon 10000x500');
      });
    });

    group('2. Vertical Mobile Portrait & Tall Screens', () {
      test('Vertical mobile portrait 9:21 (1080 x 2520)', () {
        verifyViewportInvariants(1080, 2520, label: '9:21 Sony Xperia / Tall Android');
      });

      test('Vertical mobile portrait 9:19.5 (1170 x 2532 - iPhone 14)', () {
        verifyViewportInvariants(1170, 2532, label: '9:19.5 iPhone 14 1170x2532');
      });

      test('Vertical mobile portrait 9:16 (1080 x 1920)', () {
        verifyViewportInvariants(1080, 1920, label: '9:16 Standard Mobile Portrait');
      });

      test('Extreme Vertical Skyscraper Ribbon (500 x 10000 - 1:20 ratio)', () {
        verifyViewportInvariants(500, 10000, label: 'Extreme Vertical Ribbon 500x10000');
      });
    });

    group('3. Square Displays (1:1 Aspect Ratio)', () {
      test('1000 x 1000 Square display', () {
        verifyViewportInvariants(1000, 1000, label: '1000x1000 Square');
      });

      test('360 x 360 Small Square display (Smartwatch)', () {
        verifyViewportInvariants(360, 360, label: '360x360 Smartwatch Square');
      });

      test('2048 x 2048 High-res Square display', () {
        verifyViewportInvariants(2048, 2048, label: '2048x2048 Square');
      });
    });

    group('4. Tiny & Downscaled Resolutions', () {
      test('320 x 180 (Half resolution, 0.5x scale)', () {
        verifyViewportInvariants(320, 180, label: '320x180 0.5x Scale');
      });

      test('160 x 90 (Quarter resolution, 0.25x scale)', () {
        verifyViewportInvariants(160, 90, label: '160x90 0.25x Scale');
      });

      test('64 x 36 (Micro resolution, 0.1x scale)', () {
        verifyViewportInvariants(64, 36, label: '64x36 0.1x Scale');
      });

      test('16 x 9 (Nano resolution, 0.025x scale)', () {
        verifyViewportInvariants(16, 9, label: '16x9 Nano Scale');
      });
    });

    group('5. Giant & High-DPI Resolutions', () {
      test('4K UHD (3840 x 2160 - exact 16:9, 6.0x scale)', () {
        verifyViewportInvariants(3840, 2160, label: '4K UHD 3840x2160');
      });

      test('8K UHD (7680 x 4320 - exact 16:9, 12.0x scale)', () {
        verifyViewportInvariants(7680, 4320, label: '8K UHD 7680x4320');
      });

      test('16K UHD (15360 x 8640 - exact 16:9, 24.0x scale)', () {
        verifyViewportInvariants(15360, 8640, label: '16K UHD 15360x8640');
      });
    });

    group('6. Fractional & Odd Screen Resolutions', () {
      test('1366 x 768 (Standard budget laptop resolution)', () {
        verifyViewportInvariants(1366, 768, label: '1366x768 Laptop');
      });

      test('1440 x 900 (16:10 MacBook display)', () {
        verifyViewportInvariants(1440, 900, label: '1440x900 16:10 MacBook');
      });

      test('Prime and Irregular Dimensions (1117 x 709)', () {
        verifyViewportInvariants(1117, 709, label: 'Irregular Prime 1117x709');
      });

      test('Arbitrary Non-integer Floating Dimensions (853.7 x 480.3)', () {
        verifyViewportInvariants(853.7, 480.3, label: 'Subpixel dimensions 853.7x480.3');
      });
    });

    group('7. Letterbox / Pillarbox Margin Outer Input Handling', () {
      test('Pillarboxed outer space (3840 x 1080)', () {
        game.onGameResize(Vector2(3840, 1080));
        // active width = 1920, marginX = 960
        final leftOuterClick = game.camera.globalToLocal(Vector2(480, 540));
        expect(leftOuterClick.x, lessThan(0.0));
        expect(leftOuterClick.y, closeTo(180.0, 1e-4));

        final rightOuterClick = game.camera.globalToLocal(Vector2(3840 - 480, 540));
        expect(rightOuterClick.x, greaterThan(GameConfig.virtualWidth));
        expect(rightOuterClick.y, closeTo(180.0, 1e-4));
      });

      test('Letterboxed outer space (1080 x 2520)', () {
        game.onGameResize(Vector2(1080, 2520));
        // active height = 360 * (1080 / 640) = 607.5, marginY = (2520 - 607.5) / 2 = 956.25
        final topOuterClick = game.camera.globalToLocal(Vector2(540, 400));
        expect(topOuterClick.y, lessThan(0.0));
        expect(topOuterClick.x, closeTo(320.0, 1e-4));

        final bottomOuterClick = game.camera.globalToLocal(Vector2(540, 2200));
        expect(bottomOuterClick.y, greaterThan(GameConfig.virtualHeight));
        expect(bottomOuterClick.x, closeTo(320.0, 1e-4));
      });
    });

    group('8. Rapid Resizing & Transformation Stability (Zero Accumulation Drift)', () {
      test('1,000 rapid successive resizes across pseudo-random dimensions preserve exactness', () {
        final rng = math.Random(42);
        for (int i = 0; i < 1000; i++) {
          final w = rng.nextDouble() * 3800 + 100; // 100 to 3900
          final h = rng.nextDouble() * 2000 + 100; // 100 to 2100
          game.onGameResize(Vector2(w, h));
        }

        // Now test after 1,000 resizes on standard 1080p
        verifyViewportInvariants(1920, 1080, label: 'Post 1000-resizes 1080p');

        // And on 32:9 ultrawide
        verifyViewportInvariants(3840, 1080, label: 'Post 1000-resizes Ultrawide');

        // And on vertical portrait
        verifyViewportInvariants(1080, 2520, label: 'Post 1000-resizes Portrait');
      });
    });

    group('9. Pathological & Extreme Boundary Conditions', () {
      test('Extreme 1x1 screen dimension survives without NaN or infinite scale', () {
        game.onGameResize(Vector2(1, 1));
        final viewport = game.camera.viewport as FixedResolutionViewport;
        expect(viewport.scale.x.isNaN, isFalse);
        expect(viewport.scale.x.isInfinite, isFalse);
        expect(viewport.scale.y.isNaN, isFalse);
        expect(viewport.scale.y.isInfinite, isFalse);
        expect(viewport.scale.x, equals(viewport.scale.y));

        final origin = game.camera.localToGlobal(Vector2.zero());
        expect(origin.x.isNaN, isFalse);
        expect(origin.y.isNaN, isFalse);
      });

      test('Asymmetric extreme ratios (100000 x 10 and 10 x 100000)', () {
        verifyViewportInvariants(100000, 10, label: 'Flatline 100000x10');
        verifyViewportInvariants(10, 100000, label: 'Needle 10x100000');
      });
    });
  });
}
