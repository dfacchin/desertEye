import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:meshtastic_flutter/meshtastic_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/meshtastic_node.dart';
import '../models/chat_message.dart';
import '../models/emergency_alert.dart';

// Keys for SharedPreferences
const String _lastDeviceIdKey = 'meshtastic_last_device_id';
const String _lastDeviceNameKey = 'meshtastic_last_device_name';

// Auto-reconnect interval
const Duration _reconnectInterval = Duration(seconds: 60);

/// Configurazione canale DesertEye
/// URL: https://meshtastic.org/e/?add=true#CiESEG1lVmlQUDE2dmlyJ0haUVkaCURlc2VydEV5ZToCCCASGAgBEAIY-gEgCygFOANAA0gBUBtoAcAGAQ
const String channelName = 'DesertEye';
const String channelPskBase64 = 'bWVWaVBQMTZ2aXInSFpRWQ==';

class MeshtasticService {
  MeshtasticClient? _client;
  bool _initialized = false;

  final StreamController<List<MeshtasticNode>> _nodeController =
      StreamController<List<MeshtasticNode>>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  final StreamController<ChatMessage> _chatController =
      StreamController<ChatMessage>.broadcast();
  final StreamController<EmergencyAlert> _emergencyController =
      StreamController<EmergencyAlert>.broadcast();
  final StreamController<ReconnectStatus> _reconnectStatusController =
      StreamController<ReconnectStatus>.broadcast();

  final Map<String, MeshtasticNode> _nodes = {};
  final List<ChatMessage> _chatMessages = [];
  static const int maxChatMessages = 100;

  // Emergency tracking
  final Map<String, EmergencyAlert> _activeEmergencies = {};

  StreamSubscription<NodeInfoWrapper>? _nodeSubscription;
  StreamSubscription<MeshPacketWrapper>? _packetSubscription;
  StreamSubscription<ConnectionStatus>? _connectionSubscription;

  // Auto-reconnect state
  Timer? _reconnectTimer;
  bool _isReconnecting = false;
  String? _lastConnectedDeviceId;
  bool _wasConnectedBefore = false;

  // Public streams
  Stream<List<MeshtasticNode>> get nodeStream => _nodeController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<ChatMessage> get chatStream => _chatController.stream;
  Stream<EmergencyAlert> get emergencyStream => _emergencyController.stream;
  Stream<ReconnectStatus> get reconnectStatusStream => _reconnectStatusController.stream;

  // Public getters
  bool get isConnected => _client?.isConnected ?? false;
  bool get isInitialized => _initialized;
  bool get isReconnecting => _isReconnecting;
  List<MeshtasticNode> get nodes => _nodes.values.toList();
  List<ChatMessage> get chatMessages => List.unmodifiable(_chatMessages);
  Map<String, EmergencyAlert> get activeEmergencies => Map.unmodifiable(_activeEmergencies);
  bool get hasActiveEmergency => _activeEmergencies.values.any((e) => e.isActive);

  /// Get local node name from the library
  String? get myNodeName {
    try {
      final myInfo = _client?.myNodeInfo;
      if (myInfo == null) return null;

      // Try to find our node in the nodes map
      final nodes = _client?.nodes;
      if (nodes != null && nodes.containsKey(myInfo.myNodeNum)) {
        return nodes[myInfo.myNodeNum]?.displayName;
      }
      return 'Node ${myInfo.myNodeNum.toRadixString(16)}';
    } catch (_) {
      return null;
    }
  }

  /// Get local node number
  int? get myNodeNum {
    try {
      return _client?.myNodeInfo?.myNodeNum;
    } catch (_) {
      return null;
    }
  }

  /// Initialize the Meshtastic client and request permissions
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _client = MeshtasticClient();
      await _client!.initialize();
      _initialized = true;
      // ignore: avoid_print
      print('[Meshtastic] Client initialized successfully');
    } catch (e) {
      // ignore: avoid_print
      print('[Meshtastic] Failed to initialize client: $e');
      rethrow;
    }
  }

  /// Scan for nearby Meshtastic devices
  Stream<BluetoothDevice> scanStream() {
    if (_client == null) {
      throw StateError('MeshtasticClient not initialized. Call initialize() first.');
    }
    return _client!.scanForDevices();
  }

  /// Stop scanning
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  /// Connect to a discovered device
  Future<void> connect(BluetoothDevice device) async {
    if (_client == null) {
      throw StateError('MeshtasticClient not initialized. Call initialize() first.');
    }

    // Stop any ongoing reconnection attempts when manually connecting
    _stopReconnectTimer();

    try {
      // ignore: avoid_print
      print('[Meshtastic] Connecting to ${device.platformName}...');

      await _client!.connectToDevice(device);
      _setupListeners();

      // Track this device for auto-reconnect
      _lastConnectedDeviceId = device.remoteId.toString();
      _wasConnectedBefore = true;

      // Emit connected state immediately after successful connection
      _connectionController.add(true);

      // Save device info for auto-reconnect
      await _saveLastDevice(device);

      // ignore: avoid_print
      print('[Meshtastic] Connected successfully!');

      // Log local node info if available
      final myInfo = _client!.myNodeInfo;
      if (myInfo != null) {
        // ignore: avoid_print
        print('[Meshtastic] Local node: ${myInfo.myNodeNum.toRadixString(16)}');
      }

      // Load existing nodes from client
      _loadNodesFromClient();

    } catch (e) {
      // ignore: avoid_print
      print('[Meshtastic] Connection failed: $e');
      _connectionController.add(false);
      rethrow;
    }
  }

  /// Load existing nodes from the client's cache
  void _loadNodesFromClient() {
    final clientNodes = _client?.nodes;
    if (clientNodes == null) return;

    for (final nodeInfo in clientNodes.values) {
      _updateNodeFromWrapper(nodeInfo);
    }
  }

  /// Setup listeners for nodes and packets
  void _setupListeners() {
    // Cancel existing subscriptions
    _nodeSubscription?.cancel();
    _packetSubscription?.cancel();
    _connectionSubscription?.cancel();

    // Listen for node updates
    _nodeSubscription = _client!.nodeStream.listen(
      (nodeInfo) {
        _updateNodeFromWrapper(nodeInfo);
      },
      onError: (e) {
        // ignore: avoid_print
        print('[Meshtastic] Node stream error: $e');
      },
    );

    // Listen for incoming packets (messages, positions, etc.)
    _packetSubscription = _client!.packetStream.listen(
      (packet) {
        _handlePacket(packet);
      },
      onError: (e) {
        // ignore: avoid_print
        print('[Meshtastic] Packet stream error: $e');
      },
    );

    // Listen for connection state changes
    _connectionSubscription = _client!.connectionStream.listen(
      (status) {
        final connected = status.state == MeshtasticConnectionState.connected;
        _connectionController.add(connected);

        // ignore: avoid_print
        print('[Meshtastic] Connection state: ${status.state}');

        if (status.state == MeshtasticConnectionState.error) {
          // ignore: avoid_print
          print('[Meshtastic] Error: ${status.errorMessage ?? "unknown"}');
        }

        // Handle disconnection - start auto-reconnect if we were previously connected
        if (!connected && _wasConnectedBefore && _lastConnectedDeviceId != null) {
          _startReconnectTimer();
        }
      },
      onError: (e) {
        // ignore: avoid_print
        print('[Meshtastic] Connection stream error: $e');
        _connectionController.add(false);

        // Start reconnect on error if we were previously connected
        if (_wasConnectedBefore && _lastConnectedDeviceId != null) {
          _startReconnectTimer();
        }
      },
    );
  }

  // ============ Auto-Reconnect ============

  /// Start the auto-reconnect timer (attempts every 60 seconds)
  void _startReconnectTimer() {
    // Don't start if already reconnecting or no device to reconnect to
    if (_isReconnecting || _lastConnectedDeviceId == null) return;

    _isReconnecting = true;
    // ignore: avoid_print
    print('[Meshtastic] Connection lost. Will attempt to reconnect every 60 seconds...');

    // Attempt immediately first, then every 60 seconds
    _attemptReconnect();

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(_reconnectInterval, (_) {
      _attemptReconnect();
    });
  }

  /// Stop the auto-reconnect timer
  void _stopReconnectTimer() {
    if (_reconnectTimer != null) {
      _reconnectTimer!.cancel();
      _reconnectTimer = null;
      // ignore: avoid_print
      print('[Meshtastic] Auto-reconnect stopped');
    }
    _isReconnecting = false;
    _reconnectStatusController.add(ReconnectStatus.idle);
  }

  /// Attempt to reconnect to the last connected device
  Future<void> _attemptReconnect() async {
    if (!_isReconnecting || _lastConnectedDeviceId == null) return;

    // Don't attempt if already connected
    if (isConnected) {
      _stopReconnectTimer();
      return;
    }

    // ignore: avoid_print
    print('[Meshtastic] Attempting to reconnect to $_lastConnectedDeviceId...');

    // Emit searching status
    _reconnectStatusController.add(ReconnectStatus.searching);

    try {
      if (!_initialized) {
        await initialize();
        await Future.delayed(const Duration(milliseconds: 500));
      }

      BluetoothDevice? foundDevice;

      // Scan for the device with timeout
      await for (final device in scanStream().timeout(
        const Duration(seconds: 15),
        onTimeout: (sink) => sink.close(),
      )) {
        if (device.remoteId.toString() == _lastConnectedDeviceId) {
          foundDevice = device;
          // ignore: avoid_print
          print('[Meshtastic] Reconnect: Device found!');
          break;
        }
      }

      await Future.delayed(const Duration(milliseconds: 200));
      await stopScan();

      if (foundDevice == null) {
        // ignore: avoid_print
        print('[Meshtastic] Reconnect: Device not found, will retry in 60 seconds');
        _reconnectStatusController.add(ReconnectStatus.failed);
        return;
      }

      await Future.delayed(const Duration(milliseconds: 500));

      // Emit connecting status
      _reconnectStatusController.add(ReconnectStatus.connecting);

      // Clear reconnecting flag before connecting
      _isReconnecting = false;

      await _client!.connectToDevice(foundDevice);
      _setupListeners();

      // Connection successful - stop reconnect timer
      _stopReconnectTimer();
      _connectionController.add(true);
      _reconnectStatusController.add(ReconnectStatus.connected);

      // ignore: avoid_print
      print('[Meshtastic] Reconnected successfully!');

      // Load existing nodes from client
      _loadNodesFromClient();

    } catch (e) {
      // ignore: avoid_print
      print('[Meshtastic] Reconnect attempt failed: $e');
      _reconnectStatusController.add(ReconnectStatus.failed);
      // Keep reconnecting flag true so timer continues
      _isReconnecting = true;
    }
  }

  /// Update or create a node from NodeInfoWrapper
  void _updateNodeFromWrapper(NodeInfoWrapper info) {
    // Skip nodes without valid position
    if (info.latitude == null || info.longitude == null) {
      // ignore: avoid_print
      print('[Meshtastic] NodeInfo: ${info.displayName} (no position)');
      return;
    }

    // Skip our own node (it's shown as user position)
    if (myNodeNum != null && info.num == myNodeNum) {
      // ignore: avoid_print
      print('[Meshtastic] Skipping local node: ${info.displayName}');
      return;
    }

    final nodeId = info.num.toRadixString(16);
    final position = LatLng(info.latitude!, info.longitude!);
    final now = DateTime.now();

    // ignore: avoid_print
    print('[Meshtastic] NodeInfo: ${info.displayName} at ${info.latitude}, ${info.longitude}');

    if (_nodes.containsKey(nodeId)) {
      final existingNode = _nodes[nodeId]!;
      _nodes[nodeId] = existingNode.addTrailPoint(position).copyWith(
            name: info.displayName,
            position: position,
            lastUpdate: now,
            batteryLevel: info.batteryLevel,
            snr: info.snr,
          );
    } else {
      _nodes[nodeId] = MeshtasticNode(
        nodeId: nodeId,
        name: info.displayName,
        position: position,
        heading: 0,
        lastUpdate: now,
        trailPoints: [position],
        batteryLevel: info.batteryLevel ?? -1,
        snr: info.snr,
        rssi: 0,
      );
    }

    _nodeController.add(_nodes.values.toList());
  }

  /// Handle incoming packet
  void _handlePacket(MeshPacketWrapper packet) {
    if (packet.isTextMessage) {
      _handleTextMessage(packet);
    } else if (packet.isPosition) {
      // ignore: avoid_print
      print('[Meshtastic] Position packet from ${packet.from.toRadixString(16)}');
    } else if (packet.isTelemetry) {
      // ignore: avoid_print
      print('[Meshtastic] Telemetry packet from ${packet.from.toRadixString(16)}');
    }
  }

  /// Handle incoming text message
  void _handleTextMessage(MeshPacketWrapper packet) {
    final text = packet.textMessage;
    if (text == null || text.isEmpty) return;

    final fromNodeId = packet.from.toRadixString(16);
    final fromNodeName = _getNodeName(packet.from);

    // ignore: avoid_print
    print('[Meshtastic] Message from $fromNodeName: $text');

    final message = ChatMessage(
      messageId: '${packet.from}_${DateTime.now().millisecondsSinceEpoch}',
      fromNodeId: fromNodeId,
      fromNodeName: fromNodeName,
      text: text,
      timestamp: DateTime.now(),
      toNodeId: packet.to,
      channelIndex: packet.channel,
    );

    _chatMessages.add(message);

    // Keep only the last N messages
    while (_chatMessages.length > maxChatMessages) {
      _chatMessages.removeAt(0);
    }

    _chatController.add(message);

    // Check for emergency message
    if (isEmergencyMessage(text)) {
      _handleEmergencyMessage(fromNodeId, fromNodeName, text);
    }
  }

  /// Handle incoming emergency message
  void _handleEmergencyMessage(String nodeId, String nodeName, String text) {
    // ignore: avoid_print
    print('[Meshtastic] 🆘 EMERGENCY from $nodeName: $text');

    // Get node position if available
    LatLng? position;
    if (_nodes.containsKey(nodeId)) {
      position = _nodes[nodeId]!.position;
    }

    final alert = EmergencyAlert(
      nodeId: nodeId,
      nodeName: nodeName,
      position: position,
      timestamp: DateTime.now(),
      message: text,
      isActive: true,
    );

    _activeEmergencies[nodeId] = alert;
    _emergencyController.add(alert);
  }

  /// Dismiss an active emergency
  void dismissEmergency(String nodeId) {
    if (_activeEmergencies.containsKey(nodeId)) {
      _activeEmergencies[nodeId] = _activeEmergencies[nodeId]!.copyWith(isActive: false);
      _emergencyController.add(_activeEmergencies[nodeId]!);
    }
  }

  /// Clear all emergencies
  void clearAllEmergencies() {
    for (final nodeId in _activeEmergencies.keys) {
      _activeEmergencies[nodeId] = _activeEmergencies[nodeId]!.copyWith(isActive: false);
    }
    _activeEmergencies.clear();
  }

  /// Get node name by number
  String _getNodeName(int nodeNum) {
    final nodeId = nodeNum.toRadixString(16);

    // Check our nodes map
    if (_nodes.containsKey(nodeId)) {
      return _nodes[nodeId]!.name;
    }

    // Check client's nodes
    try {
      final clientNodes = _client?.nodes;
      if (clientNodes != null && clientNodes.containsKey(nodeNum)) {
        return clientNodes[nodeNum]?.displayName ?? 'Node !$nodeId';
      }
    } catch (_) {}

    return 'Node !$nodeId';
  }

  /// Send a text message and add it to chat
  Future<void> sendMessage(String text, {int? destinationId}) async {
    if (_client == null || !isConnected) {
      throw StateError('Not connected to a Meshtastic device');
    }

    final messageId = 'out_${DateTime.now().millisecondsSinceEpoch}';
    final myNodeId = myNodeNum?.toRadixString(16) ?? 'local';
    final myName = myNodeName ?? 'Me';

    // Crea messaggio in stato "sending"
    final message = ChatMessage(
      messageId: messageId,
      fromNodeId: myNodeId,
      fromNodeName: myName,
      text: text,
      timestamp: DateTime.now(),
      toNodeId: destinationId,
      isOutgoing: true,
      deliveryStatus: MessageDeliveryStatus.sending,
    );

    // Aggiungi subito alla lista (in stato sending)
    _chatMessages.add(message);
    _chatController.add(message);

    try {
      await _client!.sendTextMessage(text, destinationId: destinationId);

      // Aggiorna stato a "sent"
      _updateMessageStatus(messageId, MessageDeliveryStatus.sent);

      // ignore: avoid_print
      print('[Meshtastic] Message sent: $text');
    } catch (e) {
      // Aggiorna stato a "failed"
      _updateMessageStatus(messageId, MessageDeliveryStatus.failed);

      // ignore: avoid_print
      print('[Meshtastic] Failed to send message: $e');
      rethrow;
    }
  }

  /// Aggiorna lo stato di consegna di un messaggio
  void _updateMessageStatus(String messageId, MessageDeliveryStatus status) {
    final index = _chatMessages.indexWhere((m) => m.messageId == messageId);
    if (index != -1) {
      _chatMessages[index] = _chatMessages[index].copyWith(deliveryStatus: status);
      // Notifica l'aggiornamento tramite lo stream
      _chatController.add(_chatMessages[index]);
    }
  }

  /// Disconnect from the current device
  /// Set [clearReconnect] to true to stop auto-reconnect attempts (manual disconnect)
  Future<void> disconnect({bool clearReconnect = true}) async {
    // Stop reconnect timer if this is a manual disconnect
    if (clearReconnect) {
      _stopReconnectTimer();
      _wasConnectedBefore = false;
      _lastConnectedDeviceId = null;
    }

    _nodeSubscription?.cancel();
    _nodeSubscription = null;

    _packetSubscription?.cancel();
    _packetSubscription = null;

    _connectionSubscription?.cancel();
    _connectionSubscription = null;

    try {
      await _client?.disconnect();
    } catch (e) {
      // ignore: avoid_print
      print('[Meshtastic] Disconnect error: $e');
    }

    _connectionController.add(false);
  }

  /// Update or add a node manually (for testing)
  void updateNode({
    required String nodeId,
    required String name,
    required double latitude,
    required double longitude,
    double heading = 0,
    int batteryLevel = -1,
    double snr = 0,
    int rssi = 0,
  }) {
    final position = LatLng(latitude, longitude);
    final now = DateTime.now();

    if (_nodes.containsKey(nodeId)) {
      final existingNode = _nodes[nodeId]!;
      _nodes[nodeId] = existingNode.addTrailPoint(position).copyWith(
            position: position,
            heading: heading,
            lastUpdate: now,
            batteryLevel: batteryLevel > 0 ? batteryLevel : null,
            snr: snr,
            rssi: rssi,
          );
    } else {
      _nodes[nodeId] = MeshtasticNode(
        nodeId: nodeId,
        name: name.isNotEmpty ? name : 'Node $nodeId',
        position: position,
        heading: heading,
        lastUpdate: now,
        trailPoints: [position],
        batteryLevel: batteryLevel,
        snr: snr,
        rssi: rssi,
      );
    }

    _nodeController.add(_nodes.values.toList());
  }

  void removeNode(String nodeId) {
    _nodes.remove(nodeId);
    _nodeController.add(_nodes.values.toList());
  }

  void clearNodes() {
    _nodes.clear();
    _nodeController.add([]);
  }

  void clearChatMessages() {
    _chatMessages.clear();
  }

  /// Add a test node (for debugging)
  void addTestNode({
    required String nodeId,
    required String name,
    required double latitude,
    required double longitude,
    double heading = 0,
  }) {
    updateNode(
      nodeId: nodeId,
      name: name,
      latitude: latitude,
      longitude: longitude,
      heading: heading,
      batteryLevel: 75,
      snr: 10.5,
      rssi: -80,
    );
  }

  // ============ Device Persistence ============

  /// Save last connected device info
  Future<void> _saveLastDevice(BluetoothDevice device) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastDeviceIdKey, device.remoteId.toString());
      await prefs.setString(_lastDeviceNameKey, device.platformName);
      // ignore: avoid_print
      print('[Meshtastic] Saved device: ${device.platformName} (${device.remoteId})');
    } catch (e) {
      // ignore: avoid_print
      print('[Meshtastic] Failed to save device: $e');
    }
  }

  /// Get last connected device info
  Future<({String? id, String? name})> getLastDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_lastDeviceIdKey);
      final name = prefs.getString(_lastDeviceNameKey);
      return (id: id, name: name);
    } catch (e) {
      // ignore: avoid_print
      print('[Meshtastic] Failed to load last device: $e');
      return (id: null, name: null);
    }
  }

  /// Clear saved device
  Future<void> clearLastDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastDeviceIdKey);
      await prefs.remove(_lastDeviceNameKey);
    } catch (e) {
      // ignore: avoid_print
      print('[Meshtastic] Failed to clear last device: $e');
    }
  }

  /// Try to auto-connect to last device (scans in background)
  /// Returns a stream that emits status updates
  Stream<AutoConnectStatus> tryAutoConnect() async* {
    final lastDevice = await getLastDevice();
    if (lastDevice.id == null) {
      yield AutoConnectStatus.noSavedDevice;
      return;
    }

    yield AutoConnectStatus.searching;
    // ignore: avoid_print
    print('[Meshtastic] Searching for last device: ${lastDevice.name} (${lastDevice.id})');

    try {
      if (!_initialized) {
        await initialize();
        // Wait for BLE subsystem to be ready after initialization
        await Future.delayed(const Duration(milliseconds: 500));
        // ignore: avoid_print
        print('[Meshtastic] Initialized, waiting before scan...');
      }

      // Additional delay before starting scan
      await Future.delayed(const Duration(milliseconds: 300));

      BluetoothDevice? foundDevice;

      // Scan for devices with timeout
      await for (final device in scanStream().timeout(
        const Duration(seconds: 10),
        onTimeout: (sink) => sink.close(),
      )) {
        if (device.remoteId.toString() == lastDevice.id) {
          foundDevice = device;
          // ignore: avoid_print
          print('[Meshtastic] Device found! Stopping scan...');
          break;
        }
      }

      // Wait before stopping scan to avoid race conditions
      await Future.delayed(const Duration(milliseconds: 200));
      await stopScan();

      if (foundDevice == null) {
        yield AutoConnectStatus.deviceNotFound;
        return;
      }

      // Wait after stopping scan before connecting
      // This gives the BLE stack time to settle
      await Future.delayed(const Duration(milliseconds: 500));

      yield AutoConnectStatus.connecting;
      // ignore: avoid_print
      print('[Meshtastic] Found last device, connecting after pause...');

      // Additional delay before connection attempt
      await Future.delayed(const Duration(milliseconds: 300));

      await connect(foundDevice);
      yield AutoConnectStatus.connected;

    } catch (e) {
      // ignore: avoid_print
      print('[Meshtastic] Auto-connect failed: $e');
      yield AutoConnectStatus.failed;
    }
  }

  void dispose() {
    _stopReconnectTimer();
    disconnect();
    _nodeController.close();
    _connectionController.close();
    _chatController.close();
    _emergencyController.close();
    _reconnectStatusController.close();
  }
}

/// Status of auto-connect attempt
enum AutoConnectStatus {
  noSavedDevice,
  searching,
  deviceNotFound,
  connecting,
  connected,
  failed,
}

/// Status of reconnection attempt
enum ReconnectStatus {
  idle,
  searching,
  connecting,
  connected,
  failed,
}
