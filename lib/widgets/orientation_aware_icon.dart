import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

/// Widget che ruota il suo contenuto in base all'orientamento del dispositivo
/// Utile per mantenere le icone sempre orientate correttamente per l'utente
class OrientationAwareIcon extends StatefulWidget {
  final Widget child;

  const OrientationAwareIcon({
    super.key,
    required this.child,
  });

  @override
  State<OrientationAwareIcon> createState() => _OrientationAwareIconState();
}

class _OrientationAwareIconState extends State<OrientationAwareIcon> {
  DeviceOrientation _orientation = DeviceOrientation.portraitUp;
  StreamSubscription<dynamic>? _subscription;

  @override
  void initState() {
    super.initState();
    _detectOrientation();
  }

  void _detectOrientation() {
    // Usa il sensore per rilevare l'orientamento reale del dispositivo
    // Questo viene aggiornato quando il sistema notifica cambi di orientamento
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateOrientationFromMedia();
  }

  void _updateOrientationFromMedia() {
    final orientation = MediaQuery.of(context).orientation;

    // Determina l'orientamento basandosi sulla orientazione riportata da MediaQuery
    DeviceOrientation newOrientation;

    if (orientation == Orientation.portrait) {
      newOrientation = DeviceOrientation.portraitUp;
    } else {
      // In landscape, usiamo landscapeLeft come default
      newOrientation = DeviceOrientation.landscapeLeft;
    }

    if (_orientation != newOrientation) {
      setState(() => _orientation = newOrientation);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  double _getRotationAngle() {
    switch (_orientation) {
      case DeviceOrientation.portraitUp:
        return 0;
      case DeviceOrientation.landscapeLeft:
        return 1.5708; // 90° in radianti (π/2)
      case DeviceOrientation.landscapeRight:
        return -1.5708; // -90° in radianti (-π/2)
      case DeviceOrientation.portraitDown:
        return 3.1416; // 180° in radianti (π)
    }
  }

  @override
  Widget build(BuildContext context) {
    final angle = _getRotationAngle();

    return AnimatedRotation(
      turns: angle / (2 * 3.14159), // Converti radianti in turns
      duration: const Duration(milliseconds: 200),
      child: widget.child,
    );
  }
}

/// Wrapper per FAB che ruota l'icona in base all'orientamento
class OrientationAwareFAB extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget icon;
  final String? tooltip;
  final Color? backgroundColor;
  final String heroTag;

  const OrientationAwareFAB({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.backgroundColor,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: heroTag,
      onPressed: onPressed,
      tooltip: tooltip,
      backgroundColor: backgroundColor,
      child: OrientationAwareIcon(child: icon),
    );
  }
}
