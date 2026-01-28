import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../constants/map_constants.dart';
import '../models/gpx_track.dart';

class MapView extends StatelessWidget {
  final MapController mapController;
  final LatLng center;
  final LatLng? userPosition;
  final List<GpxTrack> gpxTracks;

  const MapView({
    super.key,
    required this.mapController,
    required this.center,
    this.userPosition,
    this.gpxTracks = const [],
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
        // OpenStreetMap tile layer
        TileLayer(
          urlTemplate: MapConstants.osmTileUrl,
          userAgentPackageName: MapConstants.userAgent,
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

        // User position marker
        if (userPosition != null)
          MarkerLayer(
            markers: [
              Marker(
                point: userPosition!,
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.my_location,
                  color: Colors.blue,
                  size: 40,
                ),
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
}
