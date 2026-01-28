import 'package:latlong2/latlong.dart';

class MapConstants {
  // Default position near Bolzano, Italy
  static const LatLng defaultPosition = LatLng(46.4983, 11.3548);
  static const double defaultZoom = 13.0;
  static const double minZoom = 3.0;
  static const double maxZoom = 18.0;

  // OpenStreetMap tile URL
  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String userAgent = 'com.example.desert_eye';
}
