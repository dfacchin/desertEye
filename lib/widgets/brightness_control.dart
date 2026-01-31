import 'package:flutter/material.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'orientation_aware_icon.dart';

/// Barra laterale per il controllo della luminosità dello schermo
class BrightnessControl extends StatefulWidget {
  final bool isVisible;
  final VoidCallback? onInteraction;

  const BrightnessControl({
    super.key,
    this.isVisible = true,
    this.onInteraction,
  });

  @override
  State<BrightnessControl> createState() => _BrightnessControlState();
}

class _BrightnessControlState extends State<BrightnessControl> {
  double _brightness = 0.5;
  bool _isAutoMode = true;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentBrightness();
  }

  Future<void> _loadCurrentBrightness() async {
    try {
      final brightness = await ScreenBrightness().current;
      if (mounted) {
        setState(() => _brightness = brightness);
      }
    } catch (_) {
      // Ignore errors, use default
    }
  }

  Future<void> _setBrightness(double value) async {
    widget.onInteraction?.call();

    try {
      await ScreenBrightness().setScreenBrightness(value);
      if (mounted) {
        setState(() {
          _brightness = value;
          _isAutoMode = false;
        });
      }
    } catch (_) {
      // Ignore errors
    }
  }

  Future<void> _setAutoMode() async {
    widget.onInteraction?.call();

    try {
      await ScreenBrightness().resetScreenBrightness();
      if (mounted) {
        setState(() => _isAutoMode = true);
      }
      await _loadCurrentBrightness();
    } catch (_) {
      // Ignore errors
    }
  }

  void _toggleExpanded() {
    widget.onInteraction?.call();
    setState(() => _isExpanded = !_isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    return AnimatedOpacity(
      opacity: widget.isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: _isExpanded ? _buildExpandedControl() : _buildCollapsedButton(),
      ),
    );
  }

  Widget _buildCollapsedButton() {
    return GestureDetector(
      onTap: _toggleExpanded,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(150),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isAutoMode ? Colors.blue.withAlpha(150) : Colors.amber.withAlpha(150),
            width: 2,
          ),
        ),
        child: OrientationAwareIcon(
          child: Icon(
            _isAutoMode ? Icons.brightness_auto : Icons.brightness_medium,
            color: _isAutoMode ? Colors.blue : Colors.amber,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedControl() {
    return Container(
      width: 50,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(180),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.white.withAlpha(50),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Close button
          GestureDetector(
            onTap: _toggleExpanded,
            child: const Icon(
              Icons.close,
              color: Colors.white70,
              size: 18,
            ),
          ),

          const SizedBox(height: 8),

          // Brightness icon (high)
          Icon(
            Icons.brightness_high,
            color: Colors.amber.shade300,
            size: 20,
          ),

          const SizedBox(height: 8),

          // Vertical slider
          SizedBox(
            height: 150,
            child: RotatedBox(
              quarterTurns: 3,
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 6,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                  activeTrackColor: Colors.amber,
                  inactiveTrackColor: Colors.grey.shade700,
                  thumbColor: Colors.amber,
                  overlayColor: Colors.amber.withAlpha(50),
                ),
                child: Slider(
                  value: _brightness,
                  min: 0.05,
                  max: 1.0,
                  onChanged: _setBrightness,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Brightness icon (low)
          Icon(
            Icons.brightness_low,
            color: Colors.grey.shade500,
            size: 20,
          ),

          const SizedBox(height: 12),

          // Auto mode button
          GestureDetector(
            onTap: _setAutoMode,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _isAutoMode
                    ? Colors.blue.withAlpha(100)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isAutoMode ? Colors.blue : Colors.grey.shade600,
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.brightness_auto,
                    color: _isAutoMode ? Colors.blue : Colors.grey,
                    size: 18,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'AUTO',
                    style: TextStyle(
                      color: _isAutoMode ? Colors.blue : Colors.grey,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Current brightness percentage
          Text(
            '${(_brightness * 100).round()}%',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
