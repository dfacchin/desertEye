import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Dati posizione con heading
class LocationData {
  final LatLng position;
  final double heading; // Direzione in gradi (0-360, 0 = Nord)
  final double speed; // Velocità in m/s

  LocationData({
    required this.position,
    required this.heading,
    required this.speed,
  });
}

class LocationService {
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription;

  final StreamController<LocationData> _locationController =
      StreamController<LocationData>.broadcast();
  final StreamController<double> _compassController =
      StreamController<double>.broadcast();

  Stream<LocationData> get locationStream => _locationController.stream;
  Stream<double> get compassStream => _compassController.stream;

  LatLng? _lastPosition;
  double _lastHeading = 0;
  double _lastSpeed = 0;
  double _compassHeading = 0;
  double _smoothedHeading = 0;

  // Fattore smoothing (0.0 = molto smooth, 1.0 = nessun smooth)
  static const double _smoothingFactor = 0.15;

  /// Determina posizione utente con gestione permessi
  Future<LatLng?> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      return null;
    }
  }

  /// Avvia tracking continuo della posizione
  Future<bool> startTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;

    // Avvia tracking GPS
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((position) {
      _lastPosition = LatLng(position.latitude, position.longitude);
      _lastSpeed = position.speed;

      // Usa heading GPS solo se in movimento (speed > 1 m/s)
      if (position.speed > 1 && position.heading >= 0) {
        _lastHeading = position.heading;
      }

      _emitLocation();
    });

    return true;
  }

  /// Avvia tracking bussola per orientamento telefono
  Future<bool> startCompass() async {
    final events = FlutterCompass.events;
    if (events == null) return false;

    _compassSubscription = events.listen((event) {
      if (event.heading != null) {
        _compassHeading = event.heading!;

        // Applica smoothing all'heading
        _smoothedHeading = _smoothHeading(_smoothedHeading, _compassHeading);
        _compassController.add(_smoothedHeading);

        // Se fermo, usa heading bussola smoothed
        if (_lastSpeed < 1) {
          _lastHeading = _smoothedHeading;
          _emitLocation();
        }
      }
    });

    return true;
  }

  /// Smooth heading usando interpolazione circolare (gestisce 0/360)
  double _smoothHeading(double current, double target) {
    // Converti in radianti
    final currentRad = current * (math.pi / 180);
    final targetRad = target * (math.pi / 180);

    // Usa interpolazione circolare per gestire wrap-around 0/360
    final sinCurrent = math.sin(currentRad);
    final cosCurrent = math.cos(currentRad);
    final sinTarget = math.sin(targetRad);
    final cosTarget = math.cos(targetRad);

    // Interpola sin e cos separatamente
    final sinSmoothed =
        sinCurrent + _smoothingFactor * (sinTarget - sinCurrent);
    final cosSmoothed =
        cosCurrent + _smoothingFactor * (cosTarget - cosCurrent);

    // Riconverti in gradi
    var smoothed = math.atan2(sinSmoothed, cosSmoothed) * (180 / math.pi);

    // Normalizza a 0-360
    if (smoothed < 0) smoothed += 360;

    return smoothed;
  }

  void _emitLocation() {
    if (_lastPosition != null) {
      _locationController.add(LocationData(
        position: _lastPosition!,
        heading: _lastHeading,
        speed: _lastSpeed,
      ));
    }
  }

  /// Ferma tracking GPS
  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  /// Ferma tracking bussola
  void stopCompass() {
    _compassSubscription?.cancel();
    _compassSubscription = null;
  }

  /// Verifica se il tracking è attivo
  bool get isTracking => _positionSubscription != null;

  /// Verifica se la bussola è attiva
  bool get isCompassActive => _compassSubscription != null;

  /// Heading corrente dalla bussola
  double get compassHeading => _smoothedHeading;

  /// Controlla stato permessi
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Apre impostazioni app
  Future<bool> openSettings() async {
    return await Geolocator.openAppSettings();
  }

  void dispose() {
    stopTracking();
    stopCompass();
    _locationController.close();
    _compassController.close();
  }
}
