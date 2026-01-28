import 'package:flutter/material.dart';

class MapControls extends StatelessWidget {
  final VoidCallback onRecenter;
  final VoidCallback onLoadGpx;
  final bool hasLocation;

  const MapControls({
    super.key,
    required this.onRecenter,
    required this.onLoadGpx,
    required this.hasLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 100,
      child: Column(
        children: [
          // Re-center button
          FloatingActionButton(
            heroTag: 'recenter',
            onPressed: onRecenter,
            tooltip: hasLocation ? 'Centra sulla mia posizione' : 'GPS non disponibile',
            child: Icon(
              hasLocation ? Icons.my_location : Icons.location_disabled,
            ),
          ),
          const SizedBox(height: 16),
          // Load GPX button
          FloatingActionButton(
            heroTag: 'loadgpx',
            onPressed: onLoadGpx,
            tooltip: 'Carica traccia GPX',
            child: const Icon(Icons.file_open),
          ),
        ],
      ),
    );
  }
}
