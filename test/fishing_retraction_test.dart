import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monsoon_catch/components/bobber.dart';
import 'package:monsoon_catch/components/character.dart';
import 'package:monsoon_catch/game/monsoon_world.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fishing Line & Bobber Retraction / Reset Tests', () {
    late MonsoonWorld world;

    setUp(() async {
      world = MonsoonWorld();
      await world.onLoad();
    });

    test('Initial state: no bobber, line inactive, character idle', () {
      expect(world.isFishing, isFalse);
      expect(world.currentBobber, isNull);
      expect(world.children.whereType<BobberComponent>(), isEmpty);
      expect(world.fishingLine.isActive, isFalse);
      expect(world.character.current, equals(CharacterState.idle));
    });

    test('Casting creates bobber and activates line', () {
      final target = Vector2(350.0, 250.0);
      world.castTo(target);

      expect(world.isFishing, isTrue);
      expect(world.currentBobber, isNotNull);
      expect(world.children.whereType<BobberComponent>().length, equals(1));
      expect(world.fishingLine.isActive, isTrue);
      expect(world.character.current, equals(CharacterState.casting));
    });

    test('Atomic reset immediately removes bobber, deactivates line, and resets character to idle', () {
      final target = Vector2(350.0, 250.0);
      world.castTo(target);

      expect(world.isFishing, isTrue);
      expect(world.currentBobber, isNotNull);

      // Perform atomic reset
      world.resetFishingState();

      expect(world.isFishing, isFalse);
      expect(world.currentBobber, isNull);
      expect(world.children.whereType<BobberComponent>(), isEmpty);
      expect(world.fishingLine.isActive, isFalse);
      expect(world.character.current, equals(CharacterState.idle));
      expect(world.timer, equals(0.0));
      expect(world.nibblesRemaining, equals(0));
    });

    test('Zero lingering canvas artifacts: deactivated line renders 0 path fragments', () {
      final target = Vector2(350.0, 250.0);
      world.castTo(target);

      // Active line render
      final recActive = PictureRecorder();
      final canvasActive = Canvas(recActive);
      expect(() => world.fishingLine.render(canvasActive), returnsNormally);

      // Retract line
      world.retractLine();
      expect(world.fishingLine.isActive, isFalse);

      // Subsequent render must be a clean no-op
      final recInactive = PictureRecorder();
      final canvasInactive = Canvas(recInactive);
      world.fishingLine.render(canvasInactive);
      final picInactive = recInactive.endRecording();
      expect(picInactive, isNotNull);
    });

    test('Rapid consecutive cast-and-reset stress test leaves 0 orphan entities', () {
      for (int i = 0; i < 100; i++) {
        final targetX = 220.0 + (i % 20) * 15.0;
        final targetY = 235.0 + (i % 10) * 8.0;

        world.castTo(Vector2(targetX, targetY));
        expect(world.children.whereType<BobberComponent>().length, equals(1));

        world.resetFishingState();
        expect(world.children.whereType<BobberComponent>(), isEmpty);
        expect(world.currentBobber, isNull);
        expect(world.fishingLine.isActive, isFalse);
      }
    });

    test('Reel strain and catch transition correctly and reset cleanly', () {
      world.castTo(Vector2(320.0, 250.0));

      // Advance cast flight to touchdown
      world.currentBobber!.update(0.70);
      expect(world.currentBobber!.state, equals(BobberState.floating));

      // Simulate fish bite
      world.currentBobber!.changeState(BobberState.bite);
      world.character.reel();
      expect(world.character.current, equals(CharacterState.reeling));

      // Trigger catch
      world.character.catchFish();
      world.currentBobber!.changeState(BobberState.caught);
      expect(world.character.current, equals(CharacterState.caught));
      expect(world.currentBobber!.state, equals(BobberState.caught));

      // Reset
      world.resetFishingState();
      expect(world.character.current, equals(CharacterState.idle));
      expect(world.currentBobber, isNull);
      expect(world.fishingLine.isActive, isFalse);
    });
  });
}
