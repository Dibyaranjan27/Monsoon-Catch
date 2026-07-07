import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/events.dart';

import 'components/bobber.dart';
import 'components/rain.dart';

void main() {
  runApp(GameWidget(game: MonsoonGame()));
}

class MonsoonGame extends FlameGame with TapCallbacks {
  BobberComponent? currentBobber;
  late RainComponent rain;

  @override
  Color backgroundColor() => const Color(0xFF1B2A36); // Moody deep-water color

  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    // Initialize the rain environment
    rain = RainComponent();
    add(rain);
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    
    // Remove existing bobber if there is one
    if (currentBobber != null) {
      remove(currentBobber!);
    }
    
    // Add new bobber at tap location
    currentBobber = BobberComponent(position: event.localPosition);
    add(currentBobber!);
  }
}
