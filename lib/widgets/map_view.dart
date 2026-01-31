import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../constants/map_constants.dart';
import '../models/gpx_track.dart';
import '../models/meshtastic_node.dart';
import '../services/tile_cache_service.dart';
import 'map_controls.dart';

class MapView extends StatelessWidget {
  final MapController mapController;
  final LatLng center;
  final LatLng? userPosition;
  final double userHeading;
  final List<GpxTrack> gpxTracks;
  final bool isOffline;
  final bool hasCachedTiles;
  final TileCacheService tileCacheService;
  final TrackingMode trackingMode;
  final LatLngBounds? downloadBounds;
  final bool isDownloading;
  final List<MeshtasticNode> meshtasticNodes;
  final void Function(MeshtasticNode node)? onNodeTap;
  final Set<String> emergencyNodeIds;
  final Set<String> visibleNodePaths;

  const MapView({
    super.key,
    required this.mapController,
    required this.center,
    this.userPosition,
    this.userHeading = 0,
    this.gpxTracks = const [],
    required this.isOffline,
    required this.hasCachedTiles,
    required this.tileCacheService,
    required this.trackingMode,
    this.downloadBounds,
    this.isDownloading = false,
    this.meshtasticNodes = const [],
    this.onNodeTap,
    this.emergencyNodeIds = const {},
    this.visibleNodePaths = const {},
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: MapConstants.defaultZoom,
        minZoom: MapConstants.minZoom,
        maxZoom: MapConstants.maxZoom,
      ),
      children: [
        // Tile layer con supporto offline
        _buildTileLayer(),

        // Area download evidenziata
        if (downloadBounds != null)
          PolygonLayer(
            polygons: [
              Polygon(
                points: [
                  downloadBounds!.northWest,
                  downloadBounds!.northEast,
                  downloadBounds!.southEast,
                  downloadBounds!.southWest,
                ],
                color: isDownloading
                    ? Colors.green.withValues(alpha: 0.2)
                    : Colors.blue.withValues(alpha: 0.2),
                borderColor: isDownloading ? Colors.green : Colors.blue,
                borderStrokeWidth: 3,
              ),
            ],
          ),

        // GPX track polylines
        PolylineLayer(
          polylines: gpxTracks
              .where((track) => track.isNotEmpty)
              .map((track) => Polyline(
                    points: track.points,
                    color: Colors.blue,
                    strokeWidth: 4.0,
                  ))
              .toList(),
        ),

        // Meshtastic node trails (solo per nodi con path visibile)
        PolylineLayer(
          polylines: meshtasticNodes
              .where((node) =>
                  node.trailPoints.length > 1 &&
                  visibleNodePaths.contains(node.nodeId))
              .map((node) => Polyline(
                    points: node.trailPoints,
                    color: Colors.green.withValues(alpha: 0.7),
                    strokeWidth: 3.0,
                  ))
              .toList(),
        ),

        // Waypoints visibili se offline senza cache
        if (isOffline && !hasCachedTiles)
          MarkerLayer(
            markers: gpxTracks
                .expand((track) => track.points)
                .map((point) => Marker(
                      point: point,
                      width: 8,
                      height: 8,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ))
                .toList(),
          ),

        // Meshtastic node markers con freccia e nome
        MarkerLayer(
          markers: meshtasticNodes
              .map((node) => Marker(
                    point: node.position,
                    width: 80,
                    height: 70,
                    child: GestureDetector(
                      onTap: () => onNodeTap?.call(node),
                      child: emergencyNodeIds.contains(node.nodeId)
                          ? _EmergencyNodeMarker(node: node)
                          : _buildNodeMarker(node),
                    ),
                  ))
              .toList(),
        ),

        // User position marker
        if (userPosition != null)
          MarkerLayer(
            markers: [
              Marker(
                point: userPosition!,
                width: 48,
                height: 48,
                child: _buildUserMarker(),
              ),
            ],
          ),

        // Attribution (required by OSM)
        const RichAttributionWidget(
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors'),
          ],
        ),
      ],
    );
  }

  Widget _buildNodeMarker(MeshtasticNode node) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Freccia con heading
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: Transform.rotate(
            angle: node.heading * (math.pi / 180),
            child: const Icon(
              Icons.navigation,
              color: Colors.green,
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 2),
        // Nome nodo
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 2,
              ),
            ],
          ),
          child: Text(
            node.name,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildUserMarker() {
    // Se in modalità heading, mostra freccia che indica direzione
    if (trackingMode == TrackingMode.headingUp) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.navigation,
          color: Colors.blue,
          size: 32,
        ),
      );
    }

    // Se in modalità north-up, mostra freccia che indica heading reale
    if (trackingMode == TrackingMode.northUp && userHeading > 0) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        child: Transform.rotate(
          angle: userHeading * (math.pi / 180),
          child: const Icon(
            Icons.navigation,
            color: Colors.blue,
            size: 32,
          ),
        ),
      );
    }

    // Default: pallino posizione
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.3),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.my_location,
        color: Colors.blue,
        size: 32,
      ),
    );
  }

  Widget _buildTileLayer() {
    // Offline senza cache: sfondo grigio
    if (isOffline && !hasCachedTiles) {
      return ColoredBox(
        color: Colors.grey.shade200,
        child: CustomPaint(
          painter: _GridPainter(),
          size: Size.infinite,
        ),
      );
    }

    // Usa tile provider appropriato
    final tileProvider = isOffline
        ? tileCacheService.createOfflineTileProvider()
        : tileCacheService.createOnlineTileProvider();

    return TileLayer(
      urlTemplate: MapConstants.osmTileUrl,
      userAgentPackageName: MapConstants.userAgent,
      tileProvider: tileProvider,
    );
  }
}

// Griglia per sfondo offline senza cache
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;

    const spacing = 50.0;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Marker lampeggiante per nodi in emergenza
class _EmergencyNodeMarker extends StatefulWidget {
  final MeshtasticNode node;

  const _EmergencyNodeMarker({required this.node});

  @override
  State<_EmergencyNodeMarker> createState() => _EmergencyNodeMarkerState();
}

class _EmergencyNodeMarkerState extends State<_EmergencyNodeMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _colorAnimation = ColorTween(
      begin: Colors.red,
      end: Colors.orange,
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icona emergenza lampeggiante
            Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: (_colorAnimation.value ?? Colors.red).withAlpha(80),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _colorAnimation.value ?? Colors.red,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_colorAnimation.value ?? Colors.red).withAlpha(150),
                      blurRadius: 15,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Transform.rotate(
                  angle: widget.node.heading * (math.pi / 180),
                  child: Icon(
                    Icons.warning_amber,
                    color: _colorAnimation.value ?? Colors.red,
                    size: 28,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            // Nome nodo con sfondo rosso
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withAlpha(150),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sos, color: Colors.white, size: 10),
                  const SizedBox(width: 2),
                  Text(
                    widget.node.name,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
