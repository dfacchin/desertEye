import 'package:flutter/material.dart';

class OfflineIndicator extends StatelessWidget {
  final bool isOffline;
  final bool hasCachedTiles;

  const OfflineIndicator({
    super.key,
    required this.isOffline,
    required this.hasCachedTiles,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOffline) return const SizedBox.shrink();

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 8,
      right: 8,
      child: Card(
        color: hasCachedTiles ? Colors.orange.shade100 : Colors.red.shade100,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasCachedTiles ? Icons.cloud_off : Icons.signal_wifi_off,
                size: 20,
                color: hasCachedTiles ? Colors.orange : Colors.red,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasCachedTiles
                      ? 'Offline - Mappa dalla cache'
                      : 'Offline - Nessuna mappa disponibile',
                  style: TextStyle(
                    color: hasCachedTiles
                        ? Colors.orange.shade900
                        : Colors.red.shade900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
