import 'package:latlong2/latlong.dart';

/// Rappresenta un nodo nella rete Meshtastic
class MeshtasticNode {
  final String nodeId;
  final String name;
  final LatLng position;
  final double heading; // Direzione in gradi (0-360)
  final DateTime lastUpdate;
  final List<LatLng> trailPoints; // Ultimi N punti (max 10)
  final int batteryLevel; // Percentuale 0-100
  final double snr; // Signal-to-Noise Ratio
  final int rssi; // Received Signal Strength Indicator

  MeshtasticNode({
    required this.nodeId,
    required this.name,
    required this.position,
    this.heading = 0,
    required this.lastUpdate,
    this.trailPoints = const [],
    this.batteryLevel = -1, // -1 = sconosciuto
    this.snr = 0,
    this.rssi = 0,
  });

  /// Crea copia con valori aggiornati
  MeshtasticNode copyWith({
    String? nodeId,
    String? name,
    LatLng? position,
    double? heading,
    DateTime? lastUpdate,
    List<LatLng>? trailPoints,
    int? batteryLevel,
    double? snr,
    int? rssi,
  }) {
    return MeshtasticNode(
      nodeId: nodeId ?? this.nodeId,
      name: name ?? this.name,
      position: position ?? this.position,
      heading: heading ?? this.heading,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      trailPoints: trailPoints ?? this.trailPoints,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      snr: snr ?? this.snr,
      rssi: rssi ?? this.rssi,
    );
  }

  /// Aggiunge punto al trail mantenendo max 10 punti
  MeshtasticNode addTrailPoint(LatLng point) {
    final newTrail = List<LatLng>.from(trailPoints);
    newTrail.add(point);

    // Mantieni solo ultimi 10 punti
    while (newTrail.length > 10) {
      newTrail.removeAt(0);
    }

    return copyWith(trailPoints: newTrail);
  }

  /// Stringa batteria formattata
  String get batteryString {
    if (batteryLevel < 0) return 'N/A';
    return '$batteryLevel%';
  }

  /// Tempo trascorso dall'ultimo aggiornamento
  Duration get timeSinceUpdate => DateTime.now().difference(lastUpdate);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MeshtasticNode && other.nodeId == nodeId;
  }

  @override
  int get hashCode => nodeId.hashCode;
}
