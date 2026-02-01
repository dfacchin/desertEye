import 'package:flutter/material.dart';

/// Modalità tracking
enum TrackingMode {
  off, // Non segue la posizione
  northUp, // Segue posizione, mappa orientata a nord
  headingUp, // Segue posizione, mappa orientata verso direzione movimento
}

class MapControls extends StatefulWidget {
  final VoidCallback onRecenter;
  final VoidCallback onLoadGpx;
  final VoidCallback onDownloadMap;
  final VoidCallback? onClearTracks;
  final VoidCallback onToggleTracking;
  final VoidCallback onToggleMeshtastic;
  final VoidCallback onToggleOrientation;
  final bool hasLocation;
  final bool isOnline;
  final bool hasGpxTracks;
  final TrackingMode trackingMode;
  final bool isMeshtasticConnected;
  final int meshtasticNodeCount;
  final bool isLandscape;
  final bool isReconnecting;

  const MapControls({
    super.key,
    required this.onRecenter,
    required this.onLoadGpx,
    required this.onDownloadMap,
    this.onClearTracks,
    required this.onToggleTracking,
    required this.onToggleMeshtastic,
    required this.onToggleOrientation,
    required this.hasLocation,
    required this.isOnline,
    this.hasGpxTracks = false,
    required this.trackingMode,
    this.isMeshtasticConnected = false,
    this.meshtasticNodeCount = 0,
    this.isLandscape = false,
    this.isReconnecting = false,
  });

  @override
  State<MapControls> createState() => _MapControlsState();
}

class _MapControlsState extends State<MapControls>
    with SingleTickerProviderStateMixin {
  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    if (widget.isReconnecting) {
      _radarController.repeat();
    }
  }

  @override
  void didUpdateWidget(MapControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isReconnecting && !oldWidget.isReconnecting) {
      _radarController.repeat();
    } else if (!widget.isReconnecting && oldWidget.isReconnecting) {
      _radarController.stop();
      _radarController.reset();
    }
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Orientation toggle button
        FloatingActionButton(
          heroTag: 'orientation',
          onPressed: widget.onToggleOrientation,
          tooltip:
              widget.isLandscape ? 'Modalità portrait' : 'Modalità landscape',
          backgroundColor:
              widget.isLandscape ? Colors.purple.shade100 : Colors.white,
          child: Icon(
            widget.isLandscape
                ? Icons.stay_current_portrait
                : Icons.stay_current_landscape,
            color: widget.isLandscape ? Colors.purple : Colors.grey,
          ),
        ),
        const SizedBox(height: 16),

        // Meshtastic Bluetooth button with radar animation
        Stack(
          alignment: Alignment.center,
          children: [
            // Radar animation rings (visible only when reconnecting)
            if (widget.isReconnecting) ...[
              _buildRadarRing(0.0),
              _buildRadarRing(0.5),
            ],
            // Main button
            FloatingActionButton(
              heroTag: 'meshtastic',
              onPressed: widget.onToggleMeshtastic,
              tooltip: widget.isMeshtasticConnected
                  ? 'Disconnetti Meshtastic'
                  : widget.isReconnecting
                      ? 'Riconnessione in corso...'
                      : 'Connetti Meshtastic',
              backgroundColor: widget.isMeshtasticConnected
                  ? Colors.green.shade100
                  : widget.isReconnecting
                      ? Colors.orange.shade100
                      : Colors.white,
              child: Icon(
                widget.isMeshtasticConnected
                    ? Icons.bluetooth_connected
                    : widget.isReconnecting
                        ? Icons.bluetooth_searching
                        : Icons.bluetooth,
                color: widget.isMeshtasticConnected
                    ? Colors.green
                    : widget.isReconnecting
                        ? Colors.orange
                        : Colors.grey,
              ),
            ),
            // Badge con numero nodi
            if (widget.isMeshtasticConnected && widget.meshtasticNodeCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Text(
                    '${widget.meshtasticNodeCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Download map button (solo online)
        if (widget.isOnline)
          FloatingActionButton(
            heroTag: 'download',
            onPressed: widget.onDownloadMap,
            tooltip: 'Scarica mappa offline',
            child: const Icon(Icons.download),
          ),
        if (widget.isOnline) const SizedBox(height: 16),

        // Tracking/Recenter button
        FloatingActionButton(
          heroTag: 'tracking',
          onPressed: widget.hasLocation ? widget.onToggleTracking : widget.onRecenter,
          tooltip: _getTrackingTooltip(),
          backgroundColor: _getTrackingColor(),
          child: _getTrackingIcon(),
        ),
        const SizedBox(height: 16),

        // Load GPX button
        FloatingActionButton(
          heroTag: 'loadgpx',
          onPressed: widget.onLoadGpx,
          tooltip: 'Carica traccia GPX',
          child: const Icon(Icons.file_open),
        ),

        // Clear tracks button (solo se ci sono tracce)
        if (widget.hasGpxTracks) ...[
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'clearTracks',
            onPressed: widget.onClearTracks,
            tooltip: 'Cancella tracce',
            backgroundColor: Colors.red.shade100,
            child: const Icon(Icons.clear_all),
          ),
        ],
      ],
    );
  }

  Widget _buildRadarRing(double delayFraction) {
    return AnimatedBuilder(
      animation: _radarController,
      builder: (context, child) {
        // Calculate the animation value with delay
        double value = (_radarController.value + delayFraction) % 1.0;

        // Scale from 1.0 to 2.0
        double scale = 1.0 + value;

        // Fade out as it expands
        double opacity = (1.0 - value) * 0.6;

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.orange.withValues(alpha: opacity),
                width: 2,
              ),
            ),
          ),
        );
      },
    );
  }

  String _getTrackingTooltip() {
    if (!widget.hasLocation) return 'GPS non disponibile';
    switch (widget.trackingMode) {
      case TrackingMode.off:
        return 'Attiva tracking (nord in alto)';
      case TrackingMode.northUp:
        return 'Cambia a direzione movimento';
      case TrackingMode.headingUp:
        return 'Disattiva tracking';
    }
  }

  Color _getTrackingColor() {
    switch (widget.trackingMode) {
      case TrackingMode.off:
        return Colors.white;
      case TrackingMode.northUp:
        return Colors.blue.shade100;
      case TrackingMode.headingUp:
        return Colors.blue.shade300;
    }
  }

  Widget _getTrackingIcon() {
    if (!widget.hasLocation) {
      return const Icon(Icons.location_disabled);
    }
    switch (widget.trackingMode) {
      case TrackingMode.off:
        return const Icon(Icons.my_location);
      case TrackingMode.northUp:
        return const Icon(Icons.navigation);
      case TrackingMode.headingUp:
        return Transform.rotate(
          angle: 0,
          child: const Icon(Icons.navigation, color: Colors.blue),
        );
    }
  }
}
