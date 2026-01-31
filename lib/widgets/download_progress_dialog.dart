import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';

class DownloadProgressDialog extends StatefulWidget {
  final Stream<DownloadProgress> progressStream;
  final VoidCallback onCancel;

  const DownloadProgressDialog({
    super.key,
    required this.progressStream,
    required this.onCancel,
  });

  @override
  State<DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<DownloadProgressDialog> {
  StreamSubscription<DownloadProgress>? _subscription;
  double _percentage = 0;
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    _subscription = widget.progressStream.listen(
      (progress) {
        setState(() => _percentage = progress.percentageProgress);
      },
      onDone: () {
        setState(() => _isComplete = true);
      },
      onError: (error) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore download: $error')),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isComplete ? 'Download completato' : 'Download mappa'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_isComplete) ...[
            LinearProgressIndicator(value: _percentage / 100),
            const SizedBox(height: 16),
            Text('${_percentage.toStringAsFixed(1)}% completato'),
          ] else ...[
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 16),
            const Text('Download completato!'),
          ],
        ],
      ),
      actions: [
        if (_isComplete)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Chiudi'),
          )
        else
          TextButton(
            onPressed: () {
              widget.onCancel();
              Navigator.of(context).pop();
            },
            child: const Text('Annulla'),
          ),
      ],
    );
  }
}
