import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monsoon_catch/config/game_config.dart';
import 'package:monsoon_catch/game/monsoon_game.dart';

void main() {
  group('Viewport & Resolution Architecture Tests', () {
    late MonsoonGame game;

    setUp(() {
      game = MonsoonGame();
    });

    test('Camera is configured with FixedResolutionViewport of 640x360', () async {
      await game.onLoad();

      expect(game.camera.viewport, isA<FixedResolutionViewport>());
      final viewport = game.camera.viewport as FixedResolutionViewport;
      expect(viewport.resolution.x, equals(640.0));
      expect(viewport.resolution.y, equals(360.0));
      expect(game.camera.viewfinder.anchor, equals(Anchor.topLeft));
      expect(game.backgroundColor(), equals(GameConfig.letterboxColor));
    });

    test('Aspect ratio scaling on 1080p (1920x1080 - exact 16:9)', () async {
      await game.onLoad();
      game.onGameResize(Vector2(1920, 1080));

      final viewport = game.camera.viewport as FixedResolutionViewport;
      // 1920 / 640 = 3.0, 1080 / 360 = 3.0
      expect(viewport.scale.x, equals(3.0));
      expect(viewport.scale.y, equals(3.0));

      // Screen center (960, 540) maps to virtual center (320, 180)
      final virtualCenter = game.camera.globalToLocal(Vector2(960, 540));
      expect(virtualCenter.x, closeTo(320.0, 0.001));
      expect(virtualCenter.y, closeTo(180.0, 0.001));

      // Screen origin (0, 0) maps to virtual origin (0, 0)
      final virtualOrigin = game.camera.globalToLocal(Vector2(0, 0));
      expect(virtualOrigin.x, closeTo(0.0, 0.001));
      expect(virtualOrigin.y, closeTo(0.0, 0.001));

      // Bottom-right corner (1920, 1080) maps to virtual (640, 360)
      final virtualBottomRight = game.camera.globalToLocal(Vector2(1920, 1080));
      expect(virtualBottomRight.x, closeTo(640.0, 0.001));
      expect(virtualBottomRight.y, closeTo(360.0, 0.001));
    });

    test('Aspect ratio scaling on Ultrawide (2560x1080 - 21:9 pillarboxed)', () async {
      await game.onLoad();
      game.onGameResize(Vector2(2560, 1080));

      final viewport = game.camera.viewport as FixedResolutionViewport;
      // Scale is height-constrained: 1080 / 360 = 3.0
      expect(viewport.scale.x, equals(3.0));
      expect(viewport.scale.y, equals(3.0));

      // Active viewport width = 640 * 3.0 = 1920
      // Left pillarbox width = (2560 - 1920) / 2 = 320
      // Left active edge (320, 0) maps to virtual (0, 0)
      final leftActiveEdge = game.camera.globalToLocal(Vector2(320, 0));
      expect(leftActiveEdge.x, closeTo(0.0, 0.001));
      expect(leftActiveEdge.y, closeTo(0.0, 0.001));

      // Right active edge (2240, 1080) maps to virtual (640, 360)
      final rightActiveEdge = game.camera.globalToLocal(Vector2(2240, 1080));
      expect(rightActiveEdge.x, closeTo(640.0, 0.001));
      expect(rightActiveEdge.y, closeTo(360.0, 0.001));

      // Clicks inside the left pillarbox bar (x < 320) map to negative virtual coordinate
      final clickInLeftPillarbox = game.camera.globalToLocal(Vector2(100, 540));
      expect(clickInLeftPillarbox.x, lessThan(0.0));

      // Clicks inside the right pillarbox bar (x > 2240) map to virtual coordinate > 640
      final clickInRightPillarbox = game.camera.globalToLocal(Vector2(2400, 540));
      expect(clickInRightPillarbox.x, greaterThan(640.0));
    });

    test('Aspect ratio scaling on Mobile Portrait (1080x1920 - 9:16 letterboxed)', () async {
      await game.onLoad();
      game.onGameResize(Vector2(1080, 1920));

      final viewport = game.camera.viewport as FixedResolutionViewport;
      // Scale is width-constrained: 1080 / 640 = 1.6875
      expect(viewport.scale.x, closeTo(1.6875, 0.001));
      expect(viewport.scale.y, closeTo(1.6875, 0.001));

      // Scaled height = 360 * 1.6875 = 607.5
      // Top letterbox margin = (1920 - 607.5) / 2 = 656.25
      final topActiveEdge = game.camera.globalToLocal(Vector2(0, 656.25));
      expect(topActiveEdge.x, closeTo(0.0, 0.001));
      expect(topActiveEdge.y, closeTo(0.0, 0.001));

      // Bottom active edge maps to virtual (640, 360)
      final bottomActiveEdge = game.camera.globalToLocal(Vector2(1080, 1920 - 656.25));
      expect(bottomActiveEdge.x, closeTo(640.0, 0.001));
      expect(bottomActiveEdge.y, closeTo(360.0, 0.001));

      // Clicks in top letterbox margin (y < 656.25) map to negative virtual coordinate
      final clickInTopLetterbox = game.camera.globalToLocal(Vector2(540, 200));
      expect(clickInTopLetterbox.y, lessThan(0.0));

      // Clicks in bottom letterbox margin map to virtual coordinate > 360
      final clickInBottomLetterbox = game.camera.globalToLocal(Vector2(540, 1800));
      expect(clickInBottomLetterbox.y, greaterThan(360.0));
    });

    test('Round-trip coordinate transformation fidelity', () async {
      await game.onLoad();
      game.onGameResize(Vector2(1920, 1080));

      final testVirtualPoints = [
        Vector2(0.0, 0.0),
        Vector2(320.0, 180.0),
        Vector2(640.0, 360.0),
        Vector2(150.5, 275.25),
      ];

      for (final virtualPoint in testVirtualPoints) {
        final globalPoint = game.camera.localToGlobal(virtualPoint);
        final revertedVirtualPoint = game.camera.globalToLocal(globalPoint);

        expect(revertedVirtualPoint.x, closeTo(virtualPoint.x, 0.001));
        expect(revertedVirtualPoint.y, closeTo(virtualPoint.y, 0.001));
      }
    });
  });
}
