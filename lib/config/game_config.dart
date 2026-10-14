import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Central game configuration defining virtual resolution, aspect ratio,
/// and rendering layer priorities.
class GameConfig {
  GameConfig._();

  /// Virtual screen dimensions (16:9 aspect ratio standard for cozy pixel art)
  static const double virtualWidth = 640.0;
  static const double virtualHeight = 360.0;
  static final Vector2 virtualSize = Vector2(virtualWidth, virtualHeight);
  static const double aspectRatio = virtualWidth / virtualHeight; // 16:9

  /// Default letterbox / pillarbox margin background color (deep cozy slate)
  static const Color letterboxColor = Color(0xFF0F172A);

  /// Visual layering priorities (Flame z-ordering)
  static const int prioritySky = 10;
  static const int priorityClouds = 20;
  static const int priorityFarPines = 30;
  static const int priorityMidPines = 40;
  static const int priorityBankTrees = 50;
  static const int priorityRiverBank = 60;
  static const int priorityWaterSurface = 70;
  static const int priorityCharacter = 80;
  static const int priorityRain = 90;
  static const int priorityHud = 100;
}
