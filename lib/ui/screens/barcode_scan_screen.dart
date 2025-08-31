import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
  final MobileScannerController _controller = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
    ],
    facing: CameraFacing.back,
    detectionSpeed: DetectionSpeed.noDuplicates, // avoid spam
    autoStart: true,
  );

  bool _torchOn = false;
  final bool _scanningPaused = false; // made final (never mutated)
  String? _lastCode;
  DateTime _lastShown = DateTime.fromMillisecondsSinceEpoch(0);
  String? _lastDetectedCode;
  bool _handled = false; // prevents multiple pops

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(String code) {
    if (_handled) return; // already finished
    if (_lastDetectedCode != null) return; // already showing UI
    setState(() => _lastDetectedCode = code);
    _controller.stop();
  }

  Future<void> _useCode() async {
    if (_handled) return;
    final code = _lastDetectedCode;
    if (code == null) return;
    _handled = true;
    try {
      await _controller.stop();
    } catch (_) {}
    try {
      await _controller.dispose();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pop(code);
  }

  Future<void> _scanAgain() async {
    if (_handled) return; // after handled we don't allow rescans
    if (!mounted) return;
    setState(() => _lastDetectedCode = null);
    try {
      await _controller.start();
    } catch (_) {}
  }

  void _handleDetection(BarcodeCapture cap) {
    if (_handled) return; // stop processing
    if (_scanningPaused) return;
    final b = cap.barcodes.firstOrNull;
    final val = b?.rawValue?.trim();
    if (val == null || val.isEmpty) return;

    // Simple debounce so the bottom sheet doesn't pop multiple times.
    final now = DateTime.now();
    if (val == _lastCode && now.difference(_lastShown).inSeconds < 2) return;
    _lastCode = val;
    _lastShown = now;

    _onDetect(val);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // Ensures the camera always covers the screen (no black bands).
            LayoutBuilder(
              builder: (context, constraints) {
                return ClipRect(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: MobileScanner(
                        controller: _controller,
                        onDetect: _handleDetection,
                      ),
                    ),
                  ),
                );
              },
            ),

            // Scrim + cutout overlay
            const _ScannerOverlay(),

            // Top controls
            Positioned(
              left: 8,
              right: 8,
              top: 8,
              child: Row(
                children: [
                  IconButton.filledTonal(
                    style: ButtonStyle(
                      backgroundColor: WidgetStatePropertyAll(
                        Colors.black.withValues(alpha: .35),
                      ),
                    ),
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .35),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Align the barcode in the frame',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Supported: EAN-13, UPC-A/E, EAN-8',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    style: ButtonStyle(
                      backgroundColor: WidgetStatePropertyAll(
                        Colors.black.withValues(alpha: .35),
                      ),
                    ),
                    icon: Icon(
                      _torchOn ? Icons.flash_on : Icons.flash_off,
                      color: Colors.white,
                    ),
                    onPressed: () async {
                      await _controller.toggleTorch();
                      setState(
                        () => _torchOn = !_torchOn,
                      ); // fallback: API lacks torchState getter in this version
                    },
                  ),
                  const SizedBox(width: 6),
                  IconButton.filledTonal(
                    style: ButtonStyle(
                      backgroundColor: WidgetStatePropertyAll(
                        Colors.black.withValues(alpha: .35),
                      ),
                    ),
                    icon: const Icon(Icons.cameraswitch, color: Colors.white),
                    onPressed: () => _controller.switchCamera(),
                  ),
                ],
              ),
            ),

            // Bottom action panel
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _lastDetectedCode == null
                    ? const SizedBox.shrink()
                    : Container(
                        key: const ValueKey('actions'),
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .85),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Barcode detected',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: Colors.white),
                            ),
                            const SizedBox(height: 6),
                            SelectableText(
                              _lastDetectedCode!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _useCode,
                                    child: const Text('Use this code'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _scanAgain,
                                    child: const Text('Scan again'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _OverlayPainter(), size: Size.infinite),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cutoutWidth = size.width * 0.78;
    final cutoutHeight = cutoutWidth * 0.56; // barcode-ish aspect
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.42),
        width: cutoutWidth,
        height: cutoutHeight,
      ),
      const Radius.circular(16),
    );

    // Dim everything
    final scrim = Path()..addRect(Offset.zero & size);
    final hole = Path()..addRRect(r);
    final path = Path.combine(PathOperation.difference, scrim, hole);

    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: .55));

    // White border
    final border = Paint()
      ..color = Colors.white.withValues(alpha: .9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(r, border);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
