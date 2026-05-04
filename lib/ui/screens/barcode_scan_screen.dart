import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_fitness_app/theme.dart';

class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key});

  static Future<String?> pick(BuildContext context) => Navigator.push<String>(
    context,
    MaterialPageRoute(builder: (_) => const BarcodeScanScreen()),
  );

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  late final MobileScannerController _controller;
  bool _hasPermission = !kIsWeb;
  bool _isStarting = false;
  String? _permissionError;
  bool _done = false; // prevent double-pop

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
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
      await _controller.start();
      setState(() => _hasPermission = true);
    } catch (e) {
      setState(() {
        _permissionError = 'Camera permission denied or unavailable.';
        _hasPermission = false;
      });
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;
    _done = true;
    Navigator.of(context).pop(raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Barcode'),
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
              onDetect: _onDetect,
            ),

          // Scan frame
          IgnorePointer(
            child: Align(
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 280,
                    height: 160,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary, width: 2.5),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Point at a barcode — detects automatically',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
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
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Allow camera access to scan barcodes. You can change this in browser settings.',
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
              'Tip: On iPhone/iPad, requires Safari over HTTPS.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
