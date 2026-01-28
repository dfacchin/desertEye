import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:gpx/gpx.dart';
import 'package:latlong2/latlong.dart';
import '../models/gpx_track.dart';

class GpxService {
  /// Pick and parse a GPX file
  Future<GpxTrack?> loadGpxFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['gpx'],
    );

    if (result == null || result.files.single.path == null) {
      return null;
    }

    final file = File(result.files.single.path!);
    final contents = await file.readAsString();

    return parseGpx(contents, result.files.single.name);
  }

  /// Parse GPX XML string into GpxTrack model
  GpxTrack parseGpx(String xmlString, String fileName) {
    final gpx = GpxReader().fromString(xmlString);
    final List<LatLng> points = [];

    // Extract points from all tracks
    for (final track in gpx.trks) {
      for (final segment in track.trksegs) {
        for (final point in segment.trkpts) {
          if (point.lat != null && point.lon != null) {
            points.add(LatLng(point.lat!, point.lon!));
          }
        }
      }
    }

    // Also extract route points if present
    for (final route in gpx.rtes) {
      for (final point in route.rtepts) {
        if (point.lat != null && point.lon != null) {
          points.add(LatLng(point.lat!, point.lon!));
        }
      }
    }

    return GpxTrack(
      name: gpx.metadata?.name ?? fileName,
      points: points,
    );
  }
}
