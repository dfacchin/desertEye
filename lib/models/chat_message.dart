/// Stato di consegna del messaggio
enum MessageDeliveryStatus {
  sending,   // In fase di invio
  sent,      // Inviato con successo
  delivered, // Consegnato (ACK ricevuto)
  failed,    // Invio fallito
}

class ChatMessage {
  final String messageId;
  final String fromNodeId;
  final String fromNodeName;
  final String text;
  final DateTime timestamp;
  final int? toNodeId; // null = broadcast, otherwise specific node
  final int channelIndex;
  final bool isOutgoing; // true = messaggio inviato da noi
  final MessageDeliveryStatus deliveryStatus;

  ChatMessage({
    required this.messageId,
    required this.fromNodeId,
    required this.fromNodeName,
    required this.text,
    required this.timestamp,
    this.toNodeId,
    this.channelIndex = 0,
    this.isOutgoing = false,
    this.deliveryStatus = MessageDeliveryStatus.sent,
  });

  bool get isBroadcast => toNodeId == null || toNodeId == 0xFFFFFFFF;

  ChatMessage copyWith({
    String? messageId,
    String? fromNodeId,
    String? fromNodeName,
    String? text,
    DateTime? timestamp,
    int? toNodeId,
    int? channelIndex,
    bool? isOutgoing,
    MessageDeliveryStatus? deliveryStatus,
  }) {
    return ChatMessage(
      messageId: messageId ?? this.messageId,
      fromNodeId: fromNodeId ?? this.fromNodeId,
      fromNodeName: fromNodeName ?? this.fromNodeName,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      toNodeId: toNodeId ?? this.toNodeId,
      channelIndex: channelIndex ?? this.channelIndex,
      isOutgoing: isOutgoing ?? this.isOutgoing,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
    );
  }
}
