import 'package:latlong2/latlong.dart';

class GpxTrack {
  final String name;
  final List<LatLng> points;

  GpxTrack({
    required this.name,
    required this.points,
  });

  bool get isEmpty => points.isEmpty;
  bool get isNotEmpty => points.isNotEmpty;
}
