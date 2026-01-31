import 'package:flutter/material.dart';

/// Modalità tracking
enum TrackingMode {
  off, // Non segue la posizione
  northUp, // Segue posizione, mappa orientata a nord
  headingUp, // Segue posizione, mappa orientata verso direzione movimento
}

class MapControls extends StatelessWidget {
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
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
          // Orientation toggle button
          FloatingActionButton(
            heroTag: 'orientation',
            onPressed: onToggleOrientation,
            tooltip: isLandscape ? 'Modalità portrait' : 'Modalità landscape',
            backgroundColor: isLandscape ? Colors.purple.shade100 : Colors.white,
            child: Icon(
              isLandscape ? Icons.stay_current_portrait : Icons.stay_current_landscape,
              color: isLandscape ? Colors.purple : Colors.grey,
            ),
          ),
          const SizedBox(height: 16),

          // Meshtastic Bluetooth button
          Stack(
            children: [
              FloatingActionButton(
                heroTag: 'meshtastic',
                onPressed: onToggleMeshtastic,
                tooltip: isMeshtasticConnected
                    ? 'Disconnetti Meshtastic'
                    : 'Connetti Meshtastic',
                backgroundColor: isMeshtasticConnected
                    ? Colors.green.shade100
                    : Colors.white,
                child: Icon(
                  isMeshtasticConnected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth,
                  color: isMeshtasticConnected ? Colors.green : Colors.grey,
                ),
              ),
              // Badge con numero nodi
              if (isMeshtasticConnected && meshtasticNodeCount > 0)
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
                      '$meshtasticNodeCount',
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
          if (isOnline)
            FloatingActionButton(
              heroTag: 'download',
              onPressed: onDownloadMap,
              tooltip: 'Scarica mappa offline',
              child: const Icon(Icons.download),
            ),
          if (isOnline) const SizedBox(height: 16),

          // Tracking/Recenter button
          FloatingActionButton(
            heroTag: 'tracking',
            onPressed: hasLocation ? onToggleTracking : onRecenter,
            tooltip: _getTrackingTooltip(),
            backgroundColor: _getTrackingColor(),
            child: _getTrackingIcon(),
          ),
          const SizedBox(height: 16),

          // Load GPX button
          FloatingActionButton(
            heroTag: 'loadgpx',
            onPressed: onLoadGpx,
            tooltip: 'Carica traccia GPX',
            child: const Icon(Icons.file_open),
          ),

          // Clear tracks button (solo se ci sono tracce)
          if (hasGpxTracks) ...[
            const SizedBox(height: 16),
            FloatingActionButton(
              heroTag: 'clearTracks',
              onPressed: onClearTracks,
              tooltip: 'Cancella tracce',
              backgroundColor: Colors.red.shade100,
              child: const Icon(Icons.clear_all),
            ),
          ],
        ],
      );
  }

  String _getTrackingTooltip() {
    if (!hasLocation) return 'GPS non disponibile';
    switch (trackingMode) {
      case TrackingMode.off:
        return 'Attiva tracking (nord in alto)';
      case TrackingMode.northUp:
        return 'Cambia a direzione movimento';
      case TrackingMode.headingUp:
        return 'Disattiva tracking';
    }
  }

  Color _getTrackingColor() {
    switch (trackingMode) {
      case TrackingMode.off:
        return Colors.white;
      case TrackingMode.northUp:
        return Colors.blue.shade100;
      case TrackingMode.headingUp:
        return Colors.blue.shade300;
    }
  }

  Widget _getTrackingIcon() {
    if (!hasLocation) {
      return const Icon(Icons.location_disabled);
    }
    switch (trackingMode) {
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
