import 'package:latlong2/latlong.dart';

/// Rappresenta un'emergenza attiva da un nodo
class EmergencyAlert {
  final String nodeId;
  final String nodeName;
  final LatLng? position;
  final DateTime timestamp;
  final String message;
  final bool isActive;

  EmergencyAlert({
    required this.nodeId,
    required this.nodeName,
    this.position,
    required this.timestamp,
    required this.message,
    this.isActive = true,
  });

  EmergencyAlert copyWith({
    String? nodeId,
    String? nodeName,
    LatLng? position,
    DateTime? timestamp,
    String? message,
    bool? isActive,
  }) {
    return EmergencyAlert(
      nodeId: nodeId ?? this.nodeId,
      nodeName: nodeName ?? this.nodeName,
      position: position ?? this.position,
      timestamp: timestamp ?? this.timestamp,
      message: message ?? this.message,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// Verifica se un messaggio è un SOS/emergenza
bool isEmergencyMessage(String text) {
  final lowerText = text.toLowerCase();
  return lowerText.contains('sos') ||
      lowerText.contains('emergenza') ||
      lowerText.contains('emergency') ||
      lowerText.contains('aiuto') ||
      lowerText.contains('help') ||
      lowerText.contains('soccorso') ||
      text.contains('🆘');
}
