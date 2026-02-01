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
  final VoidCallback? onShowNodeList;
  final bool hasLocation;
  final bool isOnline;
  final bool hasGpxTracks;
  final TrackingMode trackingMode;
  final bool isMeshtasticConnected;
  final int meshtasticNodeCount;
  final bool isLandscape;
  final bool isReconnecting;
  final bool isAutoConnecting;

  const MapControls({
    super.key,
    required this.onRecenter,
    required this.onLoadGpx,
    required this.onDownloadMap,
    this.onClearTracks,
    required this.onToggleTracking,
    required this.onToggleMeshtastic,
    required this.onToggleOrientation,
    this.onShowNodeList,
    required this.hasLocation,
    required this.isOnline,
    this.hasGpxTracks = false,
    required this.trackingMode,
    this.isMeshtasticConnected = false,
    this.meshtasticNodeCount = 0,
    this.isLandscape = false,
    this.isReconnecting = false,
    this.isAutoConnecting = false,
  });

  @override
  State<MapControls> createState() => _MapControlsState();
}

class _MapControlsState extends State<MapControls>
    with SingleTickerProviderStateMixin {
  late AnimationController _radarController;

  // True when either reconnecting or auto-connecting
  bool get _isConnecting => widget.isReconnecting || widget.isAutoConnecting;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    if (_isConnecting) {
      _radarController.repeat();
    }
  }

  @override
  void didUpdateWidget(MapControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasConnecting = oldWidget.isReconnecting || oldWidget.isAutoConnecting;
    if (_isConnecting && !wasConnecting) {
      _radarController.repeat();
    } else if (!_isConnecting && wasConnecting) {
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
    if (widget.isLandscape) {
      return _buildLandscapeLayout();
    }
    return _buildPortraitLayout();
  }

  Widget _buildPortraitLayout() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildOrientationButton(),
        const SizedBox(height: 16),
        _buildMeshtasticButton(),
        const SizedBox(height: 16),
        if (widget.isMeshtasticConnected && widget.meshtasticNodeCount > 0) ...[
          _buildNodeListButton(),
          const SizedBox(height: 16),
        ],
        if (widget.isOnline) ...[
          _buildDownloadButton(),
          const SizedBox(height: 16),
        ],
        _buildTrackingButton(),
        const SizedBox(height: 16),
        _buildLoadGpxButton(),
        if (widget.hasGpxTracks) ...[
          const SizedBox(height: 16),
          _buildClearTracksButton(),
        ],
      ],
    );
  }

  Widget _buildLandscapeLayout() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Prima colonna
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildOrientationButton(),
            const SizedBox(height: 12),
            _buildMeshtasticButton(),
            const SizedBox(height: 12),
            if (widget.isMeshtasticConnected && widget.meshtasticNodeCount > 0) ...[
              _buildNodeListButton(),
              const SizedBox(height: 12),
            ],
            if (widget.isOnline) _buildDownloadButton(),
          ],
        ),
        const SizedBox(width: 12),
        // Seconda colonna
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTrackingButton(),
            const SizedBox(height: 12),
            _buildLoadGpxButton(),
            if (widget.hasGpxTracks) ...[
              const SizedBox(height: 12),
              _buildClearTracksButton(),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildOrientationButton() {
    return FloatingActionButton(
      heroTag: 'orientation',
      onPressed: widget.onToggleOrientation,
      tooltip: widget.isLandscape ? 'Modalità portrait' : 'Modalità landscape',
      backgroundColor: widget.isLandscape ? Colors.purple.shade100 : Colors.white,
      child: Icon(
        widget.isLandscape ? Icons.stay_current_portrait : Icons.stay_current_landscape,
        color: widget.isLandscape ? Colors.purple : Colors.grey,
      ),
    );
  }

  Widget _buildMeshtasticButton() {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (_isConnecting) ...[
          _buildRadarRing(0.0),
          _buildRadarRing(0.5),
        ],
        FloatingActionButton(
          heroTag: 'meshtastic',
          // Disable button when connecting/configuring
          onPressed: _isConnecting ? null : widget.onToggleMeshtastic,
          tooltip: widget.isMeshtasticConnected
              ? 'Disconnetti Meshtastic'
              : widget.isAutoConnecting
                  ? 'Connessione in corso...'
                  : widget.isReconnecting
                      ? 'Riconnessione in corso...'
                      : 'Connetti Meshtastic',
          backgroundColor: widget.isMeshtasticConnected
              ? Colors.green.shade100
              : _isConnecting
                  ? Colors.blue.shade100
                  : Colors.white,
          child: Icon(
            widget.isMeshtasticConnected
                ? Icons.bluetooth_connected
                : _isConnecting
                    ? Icons.bluetooth_searching
                    : Icons.bluetooth,
            color: widget.isMeshtasticConnected
                ? Colors.green
                : _isConnecting
                    ? Colors.blue
                    : Colors.grey,
          ),
        ),
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
    );
  }

  Widget _buildNodeListButton() {
    return FloatingActionButton(
      heroTag: 'nodeList',
      onPressed: widget.onShowNodeList,
      tooltip: 'Lista nodi',
      backgroundColor: Colors.green.shade50,
      child: const Icon(Icons.people, color: Colors.green),
    );
  }

  Widget _buildDownloadButton() {
    return FloatingActionButton(
      heroTag: 'download',
      onPressed: widget.onDownloadMap,
      tooltip: 'Scarica mappa offline',
      child: const Icon(Icons.download),
    );
  }

  Widget _buildTrackingButton() {
    return FloatingActionButton(
      heroTag: 'tracking',
      onPressed: widget.hasLocation ? widget.onToggleTracking : widget.onRecenter,
      tooltip: _getTrackingTooltip(),
      backgroundColor: _getTrackingColor(),
      child: _getTrackingIcon(),
    );
  }

  Widget _buildLoadGpxButton() {
    return FloatingActionButton(
      heroTag: 'loadgpx',
      onPressed: widget.onLoadGpx,
      tooltip: 'Carica traccia GPX',
      child: const Icon(Icons.file_open),
    );
  }

  Widget _buildClearTracksButton() {
    return FloatingActionButton(
      heroTag: 'clearTracks',
      onPressed: widget.onClearTracks,
      tooltip: 'Cancella tracce',
      backgroundColor: Colors.red.shade100,
      child: const Icon(Icons.clear_all),
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
