import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import '../models/emergency_alert.dart';

/// Pulsante SOS per inviare messaggi di emergenza e visualizzare emergenze in arrivo
class SosButton extends StatefulWidget {
  final bool isConnected;
  final LatLng? userPosition;
  final Future<void> Function(String message) onSendSos;
  final EmergencyAlert? incomingEmergency;
  final VoidCallback? onNavigateToEmergency;
  final VoidCallback? onDismissEmergency;

  const SosButton({
    super.key,
    required this.isConnected,
    required this.userPosition,
    required this.onSendSos,
    this.incomingEmergency,
    this.onNavigateToEmergency,
    this.onDismissEmergency,
  });

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton> with TickerProviderStateMixin {
  bool _isSending = false;
  late AnimationController _emergencyBlinkController;
  late Animation<double> _emergencyBlinkAnimation;
  late Animation<Color?> _emergencyColorAnimation;

  @override
  void initState() {
    super.initState();

    // Emergency blink animation (faster, more urgent)
    _emergencyBlinkController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _emergencyBlinkAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _emergencyBlinkController, curve: Curves.easeInOut),
    );

    _emergencyColorAnimation = ColorTween(
      begin: Colors.red.shade900,
      end: Colors.yellow,
    ).animate(_emergencyBlinkController);
  }

  @override
  void didUpdateWidget(SosButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Start/stop emergency animation based on incoming emergency
    if (widget.incomingEmergency?.isActive == true &&
        oldWidget.incomingEmergency?.isActive != true) {
      _emergencyBlinkController.repeat(reverse: true);
      // Vibrate to alert user
      HapticFeedback.heavyImpact();
    } else if (widget.incomingEmergency?.isActive != true &&
               oldWidget.incomingEmergency?.isActive == true) {
      _emergencyBlinkController.stop();
      _emergencyBlinkController.reset();
    }
  }

  @override
  void dispose() {
    _emergencyBlinkController.dispose();
    super.dispose();
  }

  void _handleTap() {
    // If there's an active incoming emergency, navigate to it
    if (widget.incomingEmergency?.isActive == true) {
      _showEmergencyInfoDialog();
      return;
    }

    // Otherwise, show SOS send dialog
    _showSosDialog();
  }

  Future<void> _showEmergencyInfoDialog() async {
    HapticFeedback.mediumImpact();

    final alert = widget.incomingEmergency!;
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.orange, width: 2),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(50),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber, color: Colors.orange, size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'EMERGENZA RICEVUTA',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withAlpha(100)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, color: Colors.white70, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Da: ${alert.nodeName}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.access_time, color: Colors.white70, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Ora: ${alert.timestamp.hour.toString().padLeft(2, '0')}:${alert.timestamp.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                    if (alert.position != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.green, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Posizione disponibile',
                              style: TextStyle(color: Colors.green.shade300),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  alert.message,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('dismiss'),
            child: const Text(
              'IGNORA',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          if (alert.position != null)
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop('navigate'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.navigation, size: 18),
              label: const Text('VAI ALLA POSIZIONE'),
            ),
        ],
      ),
    );

    if (action == 'navigate' && widget.onNavigateToEmergency != null) {
      widget.onNavigateToEmergency!();
    } else if (action == 'dismiss' && widget.onDismissEmergency != null) {
      widget.onDismissEmergency!();
    }
  }

  Future<void> _showSosDialog() async {
    // Vibrazione di avviso
    HapticFeedback.heavyImpact();

    if (!widget.isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connetti un dispositivo Meshtastic per inviare SOS'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SosConfirmDialog(
        userPosition: widget.userPosition,
      ),
    );

    if (confirmed == true && mounted) {
      await _sendSosMessage();
    }
  }

  Future<void> _sendSosMessage() async {
    setState(() => _isSending = true);

    // Vibrazione continua durante l'invio
    HapticFeedback.heavyImpact();

    try {
      final message = _buildSosMessage();
      await widget.onSendSos(message);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('SOS inviato con successo!')),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Errore invio SOS: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  String _buildSosMessage() {
    // Formato semplice: SOS lat,lon
    if (widget.userPosition != null) {
      final lat = widget.userPosition!.latitude.toStringAsFixed(6);
      final lon = widget.userPosition!.longitude.toStringAsFixed(6);
      return 'SOS $lat,$lon';
    } else {
      return 'SOS';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasIncomingEmergency = widget.incomingEmergency?.isActive == true;

    return AnimatedBuilder(
      animation: _emergencyBlinkAnimation,
      builder: (context, child) {
        // Only animate scale when there's an incoming emergency
        final scale = hasIncomingEmergency ? _emergencyBlinkAnimation.value : 1.0;

        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: GestureDetector(
        onTap: _isSending ? null : _handleTap,
        onLongPress: _isSending ? null : _showSosDialog,
        child: AnimatedBuilder(
          animation: _emergencyColorAnimation,
          builder: (context, child) {
            final borderColor = hasIncomingEmergency
                ? _emergencyColorAnimation.value ?? Colors.orange
                : (widget.isConnected ? Colors.red.shade300 : Colors.grey.shade400);

            final gradientColors = hasIncomingEmergency
                ? [Colors.orange.shade600, _emergencyColorAnimation.value ?? Colors.red.shade900]
                : widget.isConnected
                    ? [Colors.red.shade600, Colors.red.shade900]
                    : [Colors.grey.shade500, Colors.grey.shade700];

            final shadowColor = hasIncomingEmergency
                ? Colors.orange.withAlpha(150)
                : widget.isConnected
                    ? Colors.red.withAlpha(100)
                    : Colors.black.withAlpha(50);

            return Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: borderColor,
                  width: hasIncomingEmergency ? 4 : 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: hasIncomingEmergency ? 20 : 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _buildButtonContent(hasIncomingEmergency),
            );
          },
        ),
      ),
    );
  }

  Widget _buildButtonContent(bool hasIncomingEmergency) {
    if (_isSending) {
      return const Padding(
        padding: EdgeInsets.all(18),
        child: CircularProgressIndicator(
          strokeWidth: 3,
          color: Colors.white,
        ),
      );
    }

    if (hasIncomingEmergency) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.warning_amber,
            color: Colors.white,
            size: 26,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'SOS',
              style: TextStyle(
                color: Colors.red.shade900,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    }

    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.sos,
          color: Colors.white,
          size: 28,
        ),
        Text(
          'SOS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// Dialog di conferma SOS con slider per annullare
/// Se il timer scade senza scorrere lo slider, il SOS viene inviato automaticamente
class _SosConfirmDialog extends StatefulWidget {
  final LatLng? userPosition;

  const _SosConfirmDialog({this.userPosition});

  @override
  State<_SosConfirmDialog> createState() => _SosConfirmDialogState();
}

class _SosConfirmDialogState extends State<_SosConfirmDialog>
    with SingleTickerProviderStateMixin {
  static const int _countdownSeconds = 10;
  int _countdown = _countdownSeconds;
  double _sliderValue = 0.0;
  bool _cancelled = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startCountdown();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _startCountdown() async {
    for (int i = _countdownSeconds; i > 0; i--) {
      if (!mounted || _cancelled) return;
      setState(() => _countdown = i);

      // Vibrazione ogni secondo per urgenza
      HapticFeedback.lightImpact();

      await Future.delayed(const Duration(seconds: 1));
    }

    // Timer scaduto - invia SOS automaticamente
    if (mounted && !_cancelled) {
      Navigator.of(context).pop(true);
    }
  }

  void _onSliderChanged(double value) {
    setState(() => _sliderValue = value);

    // Se lo slider raggiunge la fine, annulla
    if (value >= 0.95) {
      HapticFeedback.heavyImpact();
      _cancelled = true;
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_countdownSeconds - _countdown) / _countdownSeconds;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    // Dimensioni ridotte per landscape
    final countdownSize = isLandscape ? 70.0 : 100.0;
    final countdownFontSize = isLandscape ? 32.0 : 42.0;
    final sliderHeight = isLandscape ? 44.0 : 56.0;
    final thumbSize = isLandscape ? 36.0 : 48.0;

    return PopScope(
      canPop: false, // Impedisce di chiudere con back button
      child: AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.red, width: 3),
        ),
        contentPadding: EdgeInsets.fromLTRB(20, isLandscape ? 8 : 20, 20, isLandscape ? 12 : 24),
        title: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) => Transform.scale(
            scale: _pulseAnimation.value,
            child: child,
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(isLandscape ? 6 : 8),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(80),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.sos, color: Colors.red, size: isLandscape ? 22 : 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'SOS IN PARTENZA',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: isLandscape ? 16 : 18,
                  ),
                ),
              ),
            ],
          ),
        ),
        content: SingleChildScrollView(
          child: isLandscape ? _buildLandscapeContent(progress, countdownSize, countdownFontSize, sliderHeight, thumbSize) : _buildPortraitContent(progress, countdownSize, countdownFontSize, sliderHeight, thumbSize),
        ),
      ),
    );
  }

  Widget _buildPortraitContent(double progress, double countdownSize, double countdownFontSize, double sliderHeight, double thumbSize) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCountdown(progress, countdownSize, countdownFontSize),
        const SizedBox(height: 20),
        _buildGpsInfo(),
        const SizedBox(height: 24),
        _buildCancelSlider(sliderHeight, thumbSize),
        const SizedBox(height: 16),
        _buildHelpText(),
      ],
    );
  }

  Widget _buildLandscapeContent(double progress, double countdownSize, double countdownFontSize, double sliderHeight, double thumbSize) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildCountdown(progress, countdownSize, countdownFontSize),
            const SizedBox(width: 16),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGpsInfo(),
                  const SizedBox(height: 8),
                  _buildHelpText(),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildCancelSlider(sliderHeight, thumbSize),
      ],
    );
  }

  Widget _buildCountdown(double progress, double size, double fontSize) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.red.withAlpha(30),
        border: Border.all(color: Colors.red, width: 4),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Progress circle
          SizedBox(
            width: size - 10,
            height: size - 10,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 6,
              backgroundColor: Colors.grey.shade800,
              valueColor: AlwaysStoppedAnimation<Color>(
                _countdown <= 3 ? Colors.orange : Colors.red,
              ),
            ),
          ),
          // Countdown number
          Text(
            '$_countdown',
            style: TextStyle(
              color: _countdown <= 3 ? Colors.orange : Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGpsInfo() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            widget.userPosition != null
                ? Icons.location_on
                : Icons.location_off,
            color: widget.userPosition != null
                ? Colors.green
                : Colors.orange,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.userPosition != null
                  ? 'GPS: ${widget.userPosition!.latitude.toStringAsFixed(4)}, ${widget.userPosition!.longitude.toStringAsFixed(4)}'
                  : 'GPS non disponibile',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelSlider(double sliderHeight, double thumbSize) {
    // Usa un Slider standard di Flutter per evitare problemi di layout
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'SCORRI PER ANNULLARE',
          style: TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: sliderHeight - 16,
            activeTrackColor: Colors.green.withAlpha(100),
            inactiveTrackColor: Colors.grey.shade800,
            thumbColor: Colors.green,
            overlayColor: Colors.green.withAlpha(50),
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: thumbSize / 2),
            trackShape: const RoundedRectSliderTrackShape(),
          ),
          child: Slider(
            value: _sliderValue,
            onChanged: _onSliderChanged,
            onChangeEnd: (value) {
              if (value < 0.95) {
                setState(() => _sliderValue = 0.0);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHelpText() {
    return Text(
      'Il messaggio SOS verrà inviato automaticamente\nse non annulli entro $_countdown secondi',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.grey.shade500,
        fontSize: 11,
      ),
    );
  }
}
