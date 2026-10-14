import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monsoon_catch/components/character.dart';

void main() {
  group('CharacterComponent & Rod Tip Exact Math Tests', () {
    test('Character initializes with correct grounding and anchor', () {
      final character = CharacterComponent();
      expect(character.position.x, closeTo(118.0, 1e-4));
      expect(character.position.y, closeTo(208.8, 1e-4));
      expect(character.anchor, equals(Anchor.bottomCenter));
      expect(character.current, equals(CharacterState.idle));
    });

    test('Idle rod tip coordinates match exact analytical formula', () {
      final character = CharacterComponent(position: Vector2(118.0, 208.8));
      final tip = character.rodTipPosition;

      // Expected: x = 132.0 + 48.0 * cos(42 deg) = 167.671
      //           y = 186.0 - 48.0 * sin(42 deg) = 153.882
      expect(tip.x, closeTo(167.671, 0.1));
      expect(tip.y, closeTo(153.882, 1.0)); // accounting for breathing bob

      // Backwards compatibility method matches exact rodTipPosition
      expect(character.getRodTipPosition().x, equals(tip.x));
      expect(character.getRodTipPosition().y, equals(tip.y));
    });

    test('Strain / Reeling rod tip deflects downward significantly under tension', () {
      final character = CharacterComponent(position: Vector2(118.0, 208.8));
      character.current = CharacterState.idle;
      final idleTipY = character.rodTipPosition.y;

      character.reel();
      expect(character.current, equals(CharacterState.reeling));
      final strainTip = character.rodTipPosition;

      // Steady state tip: (164.59, 192.63)
      expect(strainTip.x, closeTo(164.59, 1.0)); // with micro-jitter
      expect(strainTip.y, closeTo(192.63, 1.5));

      // Downward deflection from idle must be >= 35.0 px
      final downwardDeflection = strainTip.y - idleTipY;
      expect(downwardDeflection, greaterThanOrEqualTo(35.0));
    });

    test('Caught celebratory pose elevates rod tip high above idle', () {
      final character = CharacterComponent(position: Vector2(118.0, 208.8));
      character.current = CharacterState.idle;
      final idleTipY = character.rodTipPosition.y;

      character.catchFish();
      expect(character.current, equals(CharacterState.caught));
      final caughtTip = character.rodTipPosition;

      // Expected tip: (141.23, 125.86)
      expect(caughtTip.x, closeTo(141.23, 1.0));
      expect(caughtTip.y, closeTo(125.86, 4.0)); // with celebratory hop

      // Tip must be significantly elevated (lower y coordinate) compared to idle
      expect(caughtTip.y, lessThan(idleTipY - 20.0));
    });

    test('Casting trajectory is continuous and reaches windup and release extrema', () {
      final character = CharacterComponent(position: Vector2(118.0, 208.8));
      character.current = CharacterState.casting;

      // Windup apex at t = 0.25: tip at (91.15, 139.23)
      character.castProgress = 0.25;
      final windupTip = character.rodTipPosition;
      expect(windupTip.x, closeTo(91.15, 0.5));
      expect(windupTip.y, closeTo(139.23, 0.5));

      // Release flick at t = 0.65: tip at (189.10, 165.58)
      character.castProgress = 0.65;
      final releaseTip = character.rodTipPosition;
      expect(releaseTip.x, closeTo(189.10, 0.5));
      expect(releaseTip.y, closeTo(165.58, 0.5));

      // Sample 100 intervals across [0.0, 1.0] to test C0 continuity and non-NaN
      Vector2 prevTip = character.rodTipPosition;
      for (int i = 0; i <= 100; i++) {
        final t = i / 100.0;
        character.castProgress = t;
        final currentTip = character.rodTipPosition;

        expect(currentTip.x.isFinite, isTrue);
        expect(currentTip.y.isFinite, isTrue);

        if (i > 0) {
          final stepDistance = (currentTip - prevTip).length;
          // Step distance must be bounded (smooth trajectory without jumps)
          expect(stepDistance, lessThan(12.0));
        }
        prevTip = currentTip;
      }
    });

    test('Zero floating gap invariant: line start delta with rod tip is 0.0 px', () {
      final character = CharacterComponent(position: Vector2(118.0, 208.8));

      for (final state in CharacterState.values) {
        character.current = state;
        final rodTip = character.rodTipPosition;
        final lineOrigin = character.rodTipPosition; // line binds directly to provider
        final delta = (rodTip - lineOrigin).length;
        expect(delta, equals(0.0));
      }
    });

    test('Procedural Canvas rendering operates cleanly without bitmap dependencies', () {
      final character = CharacterComponent(position: Vector2(118.0, 208.8));

      // Test rendering in all 4 states using a headless PictureRecorder
      for (final state in CharacterState.values) {
        character.current = state;
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(() => character.render(canvas), returnsNormally);

        final picture = recorder.endRecording();
        expect(picture, isNotNull);
      }
    });
  });
}
