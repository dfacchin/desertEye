import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/chat_message.dart';
import '../services/meshtastic_service.dart';

class ChatPanel extends StatefulWidget {
  final MeshtasticService meshtasticService;
  final VoidCallback? onClose;

  const ChatPanel({
    super.key,
    required this.meshtasticService,
    this.onClose,
  });

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  StreamSubscription<ChatMessage>? _chatSubscription;
  List<ChatMessage> _messages = [];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _messages = List.from(widget.meshtasticService.chatMessages);
    _chatSubscription = widget.meshtasticService.chatStream.listen((message) {
      setState(() {
        // Controlla se è un aggiornamento di un messaggio esistente
        final existingIndex = _messages.indexWhere((m) => m.messageId == message.messageId);
        if (existingIndex != -1) {
          // Aggiorna messaggio esistente (es. cambio stato consegna)
          _messages[existingIndex] = message;
        } else {
          // Nuovo messaggio
          _messages.add(message);
        }
      });
      // Auto-scroll to bottom per nuovi messaggi
      if (!_messages.any((m) => m.messageId == message.messageId && m != message)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _textController.clear();

    try {
      await widget.meshtasticService.sendMessage(text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore invio: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(77),
            blurRadius: 10,
            offset: const Offset(-3, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.green.shade800,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.chat, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Mesh Chat',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_messages.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (widget.onClose != null)
                  GestureDetector(
                    onTap: widget.onClose,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Messages list
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 48,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Nessun messaggio',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'I messaggi dalla rete mesh appariranno qui',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _ChatMessageTile(message: _messages[index]);
                    },
                  ),
          ),
          // Input field
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Scrivi un messaggio...',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      filled: true,
                      fillColor: Colors.grey.shade700,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _isSending ? null : _sendMessage,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _isSending ? Colors.grey : Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: _isSending
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 20,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessageTile extends StatelessWidget {
  final ChatMessage message;

  const _ChatMessageTile({required this.message});

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');
    final timeString = timeFormat.format(message.timestamp);
    final isOutgoing = message.isOutgoing;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment: isOutgoing ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 240),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isOutgoing ? Colors.green.shade800 : Colors.grey.shade800,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: Radius.circular(isOutgoing ? 12 : 4),
                bottomRight: Radius.circular(isOutgoing ? 4 : 12),
              ),
            ),
            child: Column(
              crossAxisAlignment: isOutgoing ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Header: node name + time
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isOutgoing) ...[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _getNodeColor(message.fromNodeId),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          message.fromNodeName,
                          style: TextStyle(
                            color: _getNodeColor(message.fromNodeId),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (!message.isBroadcast)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withAlpha(51),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'DM',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    Text(
                      timeString,
                      style: TextStyle(
                        color: isOutgoing ? Colors.green.shade200 : Colors.grey.shade500,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Message text
                Text(
                  message.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                // Delivery status for outgoing messages
                if (isOutgoing) ...[
                  const SizedBox(height: 4),
                  _buildDeliveryStatus(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryStatus() {
    switch (message.deliveryStatus) {
      case MessageDeliveryStatus.sending:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Colors.green.shade200,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'Invio...',
              style: TextStyle(
                color: Colors.green.shade200,
                fontSize: 10,
              ),
            ),
          ],
        );
      case MessageDeliveryStatus.sent:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check,
              size: 12,
              color: Colors.green.shade200,
            ),
            const SizedBox(width: 4),
            Text(
              'Inviato',
              style: TextStyle(
                color: Colors.green.shade200,
                fontSize: 10,
              ),
            ),
          ],
        );
      case MessageDeliveryStatus.delivered:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.done_all,
              size: 12,
              color: Colors.green.shade200,
            ),
            const SizedBox(width: 4),
            Text(
              'Consegnato',
              style: TextStyle(
                color: Colors.green.shade200,
                fontSize: 10,
              ),
            ),
          ],
        );
      case MessageDeliveryStatus.failed:
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 12,
              color: Colors.red,
            ),
            SizedBox(width: 4),
            Text(
              'Errore invio',
              style: TextStyle(
                color: Colors.red,
                fontSize: 10,
              ),
            ),
          ],
        );
    }
  }

  Color _getNodeColor(String nodeId) {
    final hash = nodeId.hashCode;
    final colors = [
      Colors.green,
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.cyan,
      Colors.pink,
      Colors.teal,
      Colors.amber,
    ];
    return colors[hash.abs() % colors.length];
  }
}

/// Floating chat button to toggle chat panel with notification badge
class ChatToggleButton extends StatefulWidget {
  final bool isOpen;
  final int unreadCount;
  final bool isConnected;
  final VoidCallback onTap;

  const ChatToggleButton({
    super.key,
    required this.isOpen,
    required this.unreadCount,
    required this.onTap,
    this.isConnected = true,
  });

  @override
  State<ChatToggleButton> createState() => _ChatToggleButtonState();
}

class _ChatToggleButtonState extends State<ChatToggleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void didUpdateWidget(ChatToggleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Animate when unread count increases
    if (widget.unreadCount > oldWidget.unreadCount && !widget.isOpen) {
      _animationController.repeat(reverse: true);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          _animationController.stop();
          _animationController.reset();
        }
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = widget.unreadCount > 0 && !widget.isOpen;

    return GestureDetector(
      onTap: widget.isConnected ? widget.onTap : null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: hasUnread ? _scaleAnimation.value : 1.0,
            child: child,
          );
        },
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: widget.isOpen
                ? LinearGradient(
                    colors: [Colors.green.shade600, Colors.green.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : widget.isConnected
                    ? LinearGradient(
                        colors: [Colors.grey.shade800, Colors.grey.shade900],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: [Colors.grey.shade600, Colors.grey.shade700],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: hasUnread
                  ? Colors.red
                  : widget.isOpen
                      ? Colors.green.shade400
                      : Colors.green.withAlpha(128),
              width: hasUnread ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: hasUnread
                    ? Colors.red.withAlpha(102)
                    : Colors.black.withAlpha(77),
                blurRadius: hasUnread ? 12 : 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              Center(
                child: Icon(
                  widget.isOpen ? Icons.chat : Icons.chat_bubble_outline,
                  color: widget.isConnected
                      ? (widget.isOpen ? Colors.white : Colors.green)
                      : Colors.grey.shade400,
                  size: 28,
                ),
              ),
              // Notification badge
              if (hasUnread)
                Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withAlpha(128),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 22,
                      minHeight: 22,
                    ),
                    child: Text(
                      widget.unreadCount > 99 ? '99+' : '${widget.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              // Not connected indicator
              if (!widget.isConnected)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.bluetooth_disabled,
                      color: Colors.white,
                      size: 10,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
