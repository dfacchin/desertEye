import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../constants/map_constants.dart';
import '../models/gpx_track.dart';
import '../services/location_service.dart';
import '../services/gpx_service.dart';
import '../widgets/map_view.dart';
import '../widgets/map_controls.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  final GpxService _gpxService = GpxService();

  LatLng? _userPosition;
  final List<GpxTrack> _gpxTracks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    setState(() => _isLoading = true);

    final position = await _locationService.getCurrentPosition();

    setState(() {
      _userPosition = position;
      _isLoading = false;
    });
  }

  void _recenterMap() {
    final center = _userPosition ?? MapConstants.defaultPosition;
    _mapController.move(center, MapConstants.defaultZoom);
  }

  Future<void> _loadGpxTrack() async {
    final track = await _gpxService.loadGpxFile();
    if (track != null && track.isNotEmpty) {
      setState(() {
        _gpxTracks.add(track);
      });

      // Center on track start point
      if (track.points.isNotEmpty) {
        _mapController.move(track.points.first, MapConstants.defaultZoom);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Caricato: ${track.name}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = _userPosition ?? MapConstants.defaultPosition;

    return Scaffold(
      appBar: AppBar(
        title: const Text('DesertEye'),
        actions: [
          if (_gpxTracks.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: () => setState(() => _gpxTracks.clear()),
              tooltip: 'Cancella tracce',
            ),
        ],
      ),
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            MapView(
              mapController: _mapController,
              center: center,
              userPosition: _userPosition,
              gpxTracks: _gpxTracks,
            ),
          if (!_isLoading)
            MapControls(
              onRecenter: _recenterMap,
              onLoadGpx: _loadGpxTrack,
              hasLocation: _userPosition != null,
            ),
        ],
      ),
    );
  }
}
