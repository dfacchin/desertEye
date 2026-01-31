import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/meshtastic_node.dart';

class NodeInfoPanel extends StatelessWidget {
  final MeshtasticNode node;
  final LatLng? userPosition;
  final VoidCallback? onClose;
  final VoidCallback? onTogglePath;
  final bool isPathVisible;

  const NodeInfoPanel({
    super.key,
    required this.node,
    this.userPosition,
    this.onClose,
    this.onTogglePath,
    this.isPathVisible = false,
  });

  /// Mostra il panel come bottom sheet
  static void show(
    BuildContext context, {
    required MeshtasticNode node,
    LatLng? userPosition,
    VoidCallback? onTogglePath,
    bool isPathVisible = false,
  }) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      constraints: isLandscape
          ? BoxConstraints(
              maxWidth: 450,
              maxHeight: MediaQuery.of(context).size.height * 0.95,
            )
          : null,
      builder: (context) => NodeInfoPanel(
        node: node,
        userPosition: userPosition,
        onClose: () => Navigator.of(context).pop(),
        onTogglePath: onTogglePath,
        isPathVisible: isPathVisible,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(
        maxHeight: isLandscape ? screenHeight * 0.95 : screenHeight * 0.6,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
          // Header con nome e icona
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.router,
                    color: Colors.green,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'ID: ${node.nodeId}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          const Divider(height: 24),

          // Info grid - 3 colonne in landscape, lista verticale in portrait
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: isLandscape
                ? _buildLandscapeInfoGrid()
                : _buildPortraitInfoList(),
          ),

          const Divider(height: 24),

          // Coordinate
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Coordinate',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildCoordinate(
                        'Lat',
                        node.position.latitude.toStringAsFixed(6),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildCoordinate(
                        'Lon',
                        node.position.longitude.toStringAsFixed(6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Show Path button
          if (node.trailPoints.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    onTogglePath?.call();
                    onClose?.call();
                  },
                  icon: Icon(
                    isPathVisible ? Icons.visibility_off : Icons.route,
                  ),
                  label: Text(
                    isPathVisible
                        ? 'Nascondi percorso'
                        : 'Mostra percorso (${node.trailPoints.length} punti)',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPathVisible
                        ? Colors.grey.shade300
                        : Colors.green,
                    foregroundColor: isPathVisible
                        ? Colors.black87
                        : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortraitInfoList() {
    return Column(
      children: [
        _buildInfoRow(
          Icons.battery_charging_full,
          'Batteria',
          node.batteryString,
          _getBatteryColor(node.batteryLevel),
        ),
        const SizedBox(height: 12),
        _buildInfoRow(
          Icons.signal_cellular_alt,
          'Segnale (SNR)',
          '${node.snr.toStringAsFixed(1)} dB',
          _getSignalColor(node.snr),
        ),
        const SizedBox(height: 12),
        _buildInfoRow(
          Icons.access_time,
          'Ultimo agg.',
          _formatTimeSince(node.timeSinceUpdate),
          Colors.grey,
        ),
        if (userPosition != null) ...[
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.straighten,
            'Distanza',
            _calculateDistance(userPosition!, node.position),
            Colors.blue,
          ),
        ],
        const SizedBox(height: 12),
        _buildInfoRow(
          Icons.explore,
          'Heading',
          '${node.heading.toStringAsFixed(0)}°',
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildLandscapeInfoGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildMiniInfoTile(
            Icons.battery_charging_full,
            node.batteryString,
            _getBatteryColor(node.batteryLevel),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: _buildMiniInfoTile(
            Icons.signal_cellular_alt,
            '${node.snr.toStringAsFixed(1)}',
            _getSignalColor(node.snr),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: _buildMiniInfoTile(
            Icons.access_time,
            _formatTimeSince(node.timeSinceUpdate),
            Colors.grey,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: _buildMiniInfoTile(
            Icons.straighten,
            userPosition != null
                ? _calculateDistance(userPosition!, node.position)
                : '-',
            Colors.blue,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: _buildMiniInfoTile(
            Icons.explore,
            '${node.heading.toStringAsFixed(0)}°',
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniInfoTile(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildCoordinate(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getBatteryColor(int level) {
    if (level < 0) return Colors.grey;
    if (level < 20) return Colors.red;
    if (level < 50) return Colors.orange;
    return Colors.green;
  }

  Color _getSignalColor(double snr) {
    if (snr < 0) return Colors.red;
    if (snr < 5) return Colors.orange;
    return Colors.green;
  }

  String _formatTimeSince(Duration duration) {
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds}s fa';
    }
    if (duration.inMinutes < 60) {
      return '${duration.inMinutes}m fa';
    }
    if (duration.inHours < 24) {
      return '${duration.inHours}h fa';
    }
    return '${duration.inDays}g fa';
  }

  String _calculateDistance(LatLng from, LatLng to) {
    const distance = Distance();
    final meters = distance.as(LengthUnit.Meter, from, to);

    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    }
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }
}
