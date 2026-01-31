import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:latlong2/latlong.dart';
import '../constants/map_constants.dart';
import '../models/gpx_track.dart';
import '../models/meshtastic_node.dart';
import '../services/location_service.dart';
import '../services/gpx_service.dart';
import '../services/connectivity_service.dart';
import '../services/tile_cache_service.dart';
import '../services/meshtastic_service.dart';
import '../widgets/map_view.dart';
import '../widgets/map_controls.dart';
import '../widgets/offline_indicator.dart';
import '../widgets/download_progress_dialog.dart';
import '../widgets/node_info_panel.dart';
import '../widgets/chat_panel.dart';
import '../widgets/sos_button.dart';
import '../models/chat_message.dart';
import '../models/emergency_alert.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  final GpxService _gpxService = GpxService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final TileCacheService _tileCacheService = TileCacheService();
  final MeshtasticService _meshtasticService = MeshtasticService();

  LatLng? _userPosition;
  double _userHeading = 0;
  final List<GpxTrack> _gpxTracks = [];
  bool _isLoading = true;
  bool _isOnline = true;
  bool _hasCachedTiles = false;
  TrackingMode _trackingMode = TrackingMode.off;

  // Download state
  LatLngBounds? _downloadBounds;
  bool _isDownloading = false;

  // Meshtastic state
  List<MeshtasticNode> _meshtasticNodes = [];
  bool _isMeshtasticConnected = false;

  // Chat state
  bool _isChatOpen = false;
  int _unreadChatCount = 0;

  // Emergency state
  EmergencyAlert? _activeEmergency;

  // Auto-connect state
  String? _autoConnectMessage;

  StreamSubscription<bool>? _connectivitySubscription;
  StreamSubscription<LocationData>? _locationSubscription;
  StreamSubscription<double>? _compassSubscription;
  StreamSubscription<List<MeshtasticNode>>? _nodeSubscription;
  StreamSubscription<bool>? _meshtasticConnectionSubscription;
  StreamSubscription<ChatMessage>? _chatSubscription;
  StreamSubscription<EmergencyAlert>? _emergencySubscription;
  StreamSubscription<AutoConnectStatus>? _autoConnectSubscription;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Inizializza monitoraggio connettività
    await _connectivityService.initialize();
    _isOnline = _connectivityService.isOnline;

    // Ascolta cambiamenti connettività
    _connectivitySubscription = _connectivityService.connectionStream.listen(
      (isOnline) {
        setState(() => _isOnline = isOnline);
      },
    );

    // Verifica tiles in cache
    _hasCachedTiles = await _tileCacheService.hasCachedTiles();

    // Ascolta aggiornamenti nodi Meshtastic
    _nodeSubscription = _meshtasticService.nodeStream.listen((nodes) {
      setState(() => _meshtasticNodes = nodes);
    });

    // Ascolta stato connessione Meshtastic
    _meshtasticConnectionSubscription =
        _meshtasticService.connectionStream.listen((connected) {
      setState(() => _isMeshtasticConnected = connected);
    });

    // Ascolta messaggi chat
    _chatSubscription = _meshtasticService.chatStream.listen((message) {
      if (!_isChatOpen) {
        setState(() => _unreadChatCount++);
      }
    });

    // Ascolta emergenze in arrivo
    _emergencySubscription = _meshtasticService.emergencyStream.listen((alert) {
      if (alert.isActive) {
        setState(() => _activeEmergency = alert);
      } else {
        setState(() => _activeEmergency = null);
      }
    });

    // Inizializza posizione
    await _initializeLocation();

    // Prova auto-connect all'ultimo dispositivo (in background)
    _tryAutoConnect();
  }

  void _tryAutoConnect() {
    _autoConnectSubscription = _meshtasticService.tryAutoConnect().listen(
      (status) {
        switch (status) {
          case AutoConnectStatus.noSavedDevice:
            // Nessun dispositivo salvato, non fare nulla
            break;
          case AutoConnectStatus.searching:
            _showAutoConnectSnackBar('Ricerca ultimo dispositivo...');
            break;
          case AutoConnectStatus.deviceNotFound:
            _hideAutoConnectSnackBar();
            // Non mostrare errore, l'utente può connettersi manualmente
            break;
          case AutoConnectStatus.connecting:
            _showAutoConnectSnackBar('Connessione in corso...');
            break;
          case AutoConnectStatus.connected:
            _hideAutoConnectSnackBar();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Connesso automaticamente'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            }
            break;
          case AutoConnectStatus.failed:
            _hideAutoConnectSnackBar();
            // Non mostrare errore, l'utente può connettersi manualmente
            break;
        }
      },
      onError: (e) {
        _hideAutoConnectSnackBar();
      },
    );
  }

  void _showAutoConnectSnackBar(String message) {
    if (!mounted) return;
    setState(() => _autoConnectMessage = message);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        duration: const Duration(seconds: 30),
        backgroundColor: Colors.blue.shade700,
      ),
    );
  }

  void _hideAutoConnectSnackBar() {
    if (!mounted) return;
    setState(() => _autoConnectMessage = null);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  Future<void> _initializeLocation() async {
    setState(() => _isLoading = true);

    final position = await _locationService.getCurrentPosition();

    setState(() {
      _userPosition = position;
      _isLoading = false;
    });
  }

  void _toggleTracking() {
    setState(() {
      switch (_trackingMode) {
        case TrackingMode.off:
          _trackingMode = TrackingMode.northUp;
          _startTracking();
          break;
        case TrackingMode.northUp:
          _trackingMode = TrackingMode.headingUp;
          _startCompass();
          break;
        case TrackingMode.headingUp:
          _trackingMode = TrackingMode.off;
          _stopTracking();
          _stopCompass();
          _mapController.rotate(0);
          break;
      }
    });
  }

  Future<void> _startTracking() async {
    final started = await _locationService.startTracking();
    if (!started) {
      setState(() => _trackingMode = TrackingMode.off);
      return;
    }

    _locationSubscription = _locationService.locationStream.listen((data) {
      setState(() {
        _userPosition = data.position;
        if (data.speed > 1) {
          _userHeading = data.heading;
        }
      });

      if (_trackingMode != TrackingMode.off) {
        _mapController.move(data.position, _mapController.camera.zoom);
      }

      if (_trackingMode == TrackingMode.headingUp &&
          !_locationService.isCompassActive &&
          data.heading >= 0) {
        _mapController.rotate(-data.heading);
      } else if (_trackingMode == TrackingMode.northUp) {
        _mapController.rotate(0);
      }
    });

    if (_userPosition != null) {
      _mapController.move(_userPosition!, _mapController.camera.zoom);
    }
  }

  Future<void> _startCompass() async {
    final started = await _locationService.startCompass();
    if (!started) return;

    _compassSubscription = _locationService.compassStream.listen((heading) {
      setState(() {
        _userHeading = heading;
      });

      if (_trackingMode == TrackingMode.headingUp) {
        _mapController.rotate(-heading);
      }
    });
  }

  void _stopTracking() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _locationService.stopTracking();
  }

  void _stopCompass() {
    _compassSubscription?.cancel();
    _compassSubscription = null;
    _locationService.stopCompass();
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

  Future<void> _downloadMapRegion() async {
    final bounds = _mapController.camera.visibleBounds;

    setState(() {
      _downloadBounds = bounds;
    });

    const int minZoom = 10;
    const int maxZoom = 18;

    final tileCount = await _tileCacheService.countTilesForRegion(
      bounds: bounds,
      minZoom: minZoom,
      maxZoom: maxZoom,
    );

    if (!mounted) return;

    final shouldDownload = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scarica regione'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tiles da scaricare: $tileCount'),
            const SizedBox(height: 8),
            Text('Zoom: $minZoom - $maxZoom (max risoluzione)'),
            const SizedBox(height: 8),
            const Text(
              'L\'area evidenziata in blu sulla mappa verrà scaricata.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Scarica'),
          ),
        ],
      ),
    );

    if (shouldDownload != true) {
      setState(() {
        _downloadBounds = null;
      });
      return;
    }

    if (!mounted) return;

    setState(() {
      _isDownloading = true;
    });

    final progressStream = await _tileCacheService.downloadRegion(
      bounds: bounds,
      minZoom: minZoom,
      maxZoom: maxZoom,
    );

    if (mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => DownloadProgressDialog(
          progressStream: progressStream,
          onCancel: () {},
        ),
      );
    }

    _hasCachedTiles = await _tileCacheService.hasCachedTiles();
    setState(() {
      _downloadBounds = null;
      _isDownloading = false;
    });
  }

  void _clearTracks() {
    setState(() => _gpxTracks.clear());
  }

  // Meshtastic methods
  Future<void> _toggleMeshtastic() async {
    if (_isMeshtasticConnected) {
      await _meshtasticService.disconnect();
    } else {
      _showMeshtasticScanDialog();
    }
  }

  void _showMeshtasticScanDialog() {
    showDialog(
      context: context,
      builder: (context) => _MeshtasticScanDialog(
        meshtasticService: _meshtasticService,
        onDeviceSelected: (device) async {
          Navigator.of(context).pop();
          await _connectToMeshtastic(device);
        },
      ),
    );
  }

  Future<void> _connectToMeshtastic(BluetoothDevice device) async {
    try {
      // Mostra indicatore di caricamento
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text('Connessione a ${device.platformName}...'),
                ),
              ],
            ),
            duration: const Duration(seconds: 30),
          ),
        );
      }

      await _meshtasticService.connect(device);

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connesso a ${device.platformName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        // Messaggi di errore user-friendly
        String errorMessage = _getConnectionErrorMessage(e);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  String _getConnectionErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('133') || errorStr.contains('android_specific_error')) {
      return 'Errore connessione BLE. Prova a:\n'
          '1. Spegnere/riaccendere Bluetooth\n'
          '2. Riavviare il dispositivo Meshtastic';
    }
    if (errorStr.contains('mtu') || errorStr.contains('disconnected')) {
      return 'Dispositivo disconnesso. Riprova.';
    }
    if (errorStr.contains('timeout')) {
      return 'Timeout connessione. Avvicina il dispositivo.';
    }
    if (errorStr.contains('servizio meshtastic non trovato')) {
      return 'Dispositivo non compatibile con Meshtastic.';
    }

    return 'Errore connessione: ${error.toString().split('\n').first}';
  }

  void _onNodeTap(MeshtasticNode node) {
    NodeInfoPanel.show(
      context,
      node: node,
      userPosition: _userPosition,
    );
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _locationSubscription?.cancel();
    _compassSubscription?.cancel();
    _nodeSubscription?.cancel();
    _meshtasticConnectionSubscription?.cancel();
    _chatSubscription?.cancel();
    _emergencySubscription?.cancel();
    _autoConnectSubscription?.cancel();
    _connectivityService.dispose();
    _locationService.dispose();
    _meshtasticService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = _userPosition ?? MapConstants.defaultPosition;

    return Scaffold(
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            MapView(
              mapController: _mapController,
              center: center,
              userPosition: _userPosition,
              userHeading: _userHeading,
              gpxTracks: _gpxTracks,
              isOffline: !_isOnline,
              hasCachedTiles: _hasCachedTiles,
              tileCacheService: _tileCacheService,
              trackingMode: _trackingMode,
              downloadBounds: _downloadBounds,
              isDownloading: _isDownloading,
              meshtasticNodes: _meshtasticNodes,
              onNodeTap: _onNodeTap,
              emergencyNodeIds: _activeEmergency != null
                  ? {_activeEmergency!.nodeId}
                  : const {},
            ),

          // Indicatore offline
          OfflineIndicator(
            isOffline: !_isOnline,
            hasCachedTiles: _hasCachedTiles,
          ),

          // Controlli mappa
          if (!_isLoading)
            MapControls(
              onRecenter: _recenterMap,
              onLoadGpx: _loadGpxTrack,
              onDownloadMap: _downloadMapRegion,
              onClearTracks: _gpxTracks.isNotEmpty ? _clearTracks : null,
              onToggleTracking: _toggleTracking,
              onToggleMeshtastic: _toggleMeshtastic,
              hasLocation: _userPosition != null,
              isOnline: _isOnline,
              hasGpxTracks: _gpxTracks.isNotEmpty,
              trackingMode: _trackingMode,
              isMeshtasticConnected: _isMeshtasticConnected,
              meshtasticNodeCount: _meshtasticNodes.length,
            ),

          // Chat toggle button (sempre visibile, posizionato a sinistra)
          Positioned(
            left: 16,
            bottom: 32,
            child: ChatToggleButton(
              isOpen: _isChatOpen,
              unreadCount: _unreadChatCount,
              isConnected: _isMeshtasticConnected,
              onTap: _toggleChat,
            ),
          ),

          // SOS button (sopra il pulsante chat)
          Positioned(
            left: 16,
            bottom: 110,
            child: SosButton(
              isConnected: _isMeshtasticConnected,
              userPosition: _userPosition,
              onSendSos: _sendSosMessage,
              incomingEmergency: _activeEmergency,
              onNavigateToEmergency: _navigateToEmergency,
              onDismissEmergency: _dismissEmergency,
            ),
          ),

          // Chat panel
          if (_isChatOpen && _isMeshtasticConnected)
            Positioned(
              right: 0,
              top: 60,
              bottom: 170,
              child: ChatPanel(
                meshtasticService: _meshtasticService,
                onClose: _toggleChat,
              ),
            ),
        ],
      ),
    );
  }

  void _toggleChat() {
    setState(() {
      _isChatOpen = !_isChatOpen;
      if (_isChatOpen) {
        _unreadChatCount = 0;
      }
    });
  }

  Future<void> _sendSosMessage(String message) async {
    await _meshtasticService.sendMessage(message);
  }

  void _navigateToEmergency() {
    if (_activeEmergency?.position != null) {
      _mapController.move(_activeEmergency!.position!, 16);
    }
    // Dismetti l'emergenza dopo la navigazione
    _dismissEmergency();
  }

  void _dismissEmergency() {
    if (_activeEmergency != null) {
      _meshtasticService.dismissEmergency(_activeEmergency!.nodeId);
      setState(() => _activeEmergency = null);
    }
  }
}

/// Dialog per scansione dispositivi Meshtastic
class _MeshtasticScanDialog extends StatefulWidget {
  final MeshtasticService meshtasticService;
  final void Function(BluetoothDevice device) onDeviceSelected;

  const _MeshtasticScanDialog({
    required this.meshtasticService,
    required this.onDeviceSelected,
  });

  @override
  State<_MeshtasticScanDialog> createState() => _MeshtasticScanDialogState();
}

class _MeshtasticScanDialogState extends State<_MeshtasticScanDialog> {
  final List<BluetoothDevice> _devices = [];
  final Set<String> _deviceIds = {}; // Per evitare duplicati
  bool _isScanning = false;
  StreamSubscription<BluetoothDevice>? _scanSubscription;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _devices.clear();
      _deviceIds.clear();
    });

    try {
      // Inizializza il client Meshtastic (richiede permessi)
      if (!widget.meshtasticService.isInitialized) {
        await widget.meshtasticService.initialize();
      }

      _scanSubscription = widget.meshtasticService.scanStream().listen(
        (device) {
          // Evita duplicati
          final deviceId = device.remoteId.toString();
          if (!_deviceIds.contains(deviceId)) {
            setState(() {
              _deviceIds.add(deviceId);
              _devices.add(device);
            });
          }
        },
        onError: (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Errore scansione: $error')),
            );
          }
          setState(() => _isScanning = false);
        },
      );

      // Ferma scansione dopo 15 secondi
      await Future.delayed(const Duration(seconds: 15));
      await _stopScan();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
      setState(() => _isScanning = false);
    }
  }

  Future<void> _stopScan() async {
    _scanSubscription?.cancel();
    await widget.meshtasticService.stopScan();
    if (mounted) {
      setState(() => _isScanning = false);
    }
  }

  @override
  void dispose() {
    _stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.bluetooth_searching, color: Colors.blue),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Dispositivi Meshtastic',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_isScanning) ...[
            const SizedBox(width: 8),
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: _devices.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isScanning ? Icons.radar : Icons.bluetooth_disabled,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isScanning
                          ? 'Ricerca dispositivi...'
                          : 'Nessun dispositivo trovato',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: _devices.length,
                itemBuilder: (context, index) {
                  final device = _devices[index];
                  final name = device.platformName.isNotEmpty
                      ? device.platformName
                      : 'Dispositivo sconosciuto';

                  return ListTile(
                    leading: const Icon(Icons.router, color: Colors.green),
                    title: Text(name),
                    subtitle: Text(device.remoteId.toString()),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => widget.onDeviceSelected(device),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        if (!_isScanning)
          TextButton(
            onPressed: _startScan,
            child: const Text('Riprova'),
          ),
      ],
    );
  }
}
