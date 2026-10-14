import 'package:flutter/material.dart';
import '../game/monsoon_game.dart';
import '../models/weather_state.dart';

/// Cozy HUD overlay allowing the user to inspect and switch weather conditions
/// in real time (Clear Day, Clear Dawn, Overcast, Monsoon Storm).
class WeatherControlsOverlay extends StatefulWidget {
  final MonsoonGame game;

  const WeatherControlsOverlay({super.key, required this.game});

  @override
  State<WeatherControlsOverlay> createState() => _WeatherControlsOverlayState();
}

class _WeatherControlsOverlayState extends State<WeatherControlsOverlay> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    widget.game.weather.addListener(_onWeatherChanged);
  }

  @override
  void dispose() {
    widget.game.weather.removeListener(_onWeatherChanged);
    super.dispose();
  }

  void _onWeatherChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final weather = widget.game.weather;

    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Material(
            color: Colors.transparent,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                color: const Color(0xDD0F172A), // Deep cozy slate glass
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1.5,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Toggle header
                  InkWell(
                    onTap: () => setState(() => _isExpanded = !_isExpanded),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getWeatherIcon(weather.currentType),
                            color: const Color(0xFFFACC15),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            weather.currentType.displayName,
                            style: const TextStyle(
                              fontFamily: 'PressStart2P',
                              color: Colors.white,
                              fontSize: 9,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: Colors.white70,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Expandable panel with buttons and metrics
                  if (_isExpanded) ...[
                    const SizedBox(height: 8),
                    const Divider(color: Colors.white24, height: 1),
                    const SizedBox(height: 8),

                    // Weather switch buttons
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.end,
                      children: WeatherType.values.map((type) {
                        final isSelected = weather.currentType == type;
                        return InkWell(
                          onTap: () {
                            weather.setWeather(type);
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF2563EB)
                                  : const Color(0x33FFFFFF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF60A5FA)
                                    : Colors.white12,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              type.displayName,
                              style: TextStyle(
                                fontFamily: 'PressStart2P',
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white70,
                                fontSize: 7,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 10),

                    // Real-time atmospheric metrics
                    _buildMetricRow(
                      'Rain Intensity',
                      '${(weather.rainIntensity * 100).toInt()}%',
                    ),
                    const SizedBox(height: 4),
                    _buildMetricRow(
                      'Wind Speed',
                      '${(weather.windSpeed * 100).toInt()}%',
                    ),
                    const SizedBox(height: 4),
                    _buildMetricRow(
                      'Wave Turbulence',
                      weather.waveTurbulence.toStringAsFixed(2),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 9,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF93C5FD),
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  IconData _getWeatherIcon(WeatherType type) {
    switch (type) {
      case WeatherType.clearDawn:
        return Icons.wb_twilight;
      case WeatherType.clearDay:
        return Icons.wb_sunny;
      case WeatherType.overcast:
        return Icons.cloud;
      case WeatherType.monsoon:
        return Icons.thunderstorm;
    }
  }
}
