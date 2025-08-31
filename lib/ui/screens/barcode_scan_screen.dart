import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key});

  // Preserve existing helper used elsewhere.
  static Future<String?> pick(BuildContext context) => Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const BarcodeScanScreen()),
      );

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  late final MobileScannerController _controller;
  bool _hasPermission = !kIsWeb; // On web we request explicitly.
  bool _isStarting = false;
  String? _permissionError;
  String? _lastCode; // recent detected code

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      // On mobile auto-starts via plugin; on web we'll manual start().
      autoStart: !kIsWeb,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startCameraWeb() async {
    if (!kIsWeb) return;
    setState(() {
      _permissionError = null;
      _isStarting = true;
    });
    try {
      await _controller.start(); // must be user gesture
      setState(() => _hasPermission = true);
    } catch (e) {
      setState(() {
        _permissionError = 'Camera permission was denied or not available.';
        _hasPermission = false;
      });
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  void _useThisCode() {
    if (_lastCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No code detected yet')),
      );
      return;
    }
    Navigator.of(context).pop(_lastCode);
  }

  @override
  Widget build(BuildContext context) {
    final overlay = Container(
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.all(12),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Text(
                _lastCode == null
                    ? 'Point camera at a barcode'
                    : 'Code: ${_lastCode}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: _useThisCode,
              child: const Text('Use this code'),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan a Barcode'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (kIsWeb && !_hasPermission)
            _WebPermissionGate(
              isStarting: _isStarting,
              error: _permissionError,
              onEnable: _startCameraWeb,
            )
          else
            MobileScanner(
              controller: _controller,
              onDetect: (capture) {
                final codes = capture.barcodes;
                if (codes.isEmpty) return;
                final raw = codes.first.rawValue;
                if (raw == null || raw.isEmpty) return;
                setState(() => _lastCode = raw);
              },
            ),

          // Optional scan frame
          IgnorePointer(
            child: Align(
              alignment: Alignment.center,
              child: Container(
                width: 280,
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.9),
                    width: 2,
                  ),
                ),
              ),
            ),
          ),

            if (_hasPermission) overlay,
        ],
      ),
    );
  }
}

class _WebPermissionGate extends StatelessWidget {
  final bool isStarting;
  final String? error;
  final VoidCallback onEnable;
  const _WebPermissionGate({
    required this.isStarting,
    required this.error,
    required this.onEnable,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo_camera, size: 64, color: Colors.white70),
            const SizedBox(height: 16),
            const Text(
              'Enable Camera',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'To scan a barcode, allow camera access. You can change this later in your browser settings.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: const TextStyle(color: Colors.orangeAccent)),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: isStarting ? null : onEnable,
              child: Text(isStarting ? 'Starting…' : 'Allow Camera'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tip: On iPhone/iPad, this requires Safari over HTTPS.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
