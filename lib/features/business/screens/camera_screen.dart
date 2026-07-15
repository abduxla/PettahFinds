import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Full-screen custom camera with a square product-framing overlay.
///
/// Push this screen and await an [XFile?]. Returns the raw captured file when
/// the user taps "Use Photo", or null when they cancel.
///
/// Usage:
/// ```dart
/// final XFile? file = await Navigator.push<XFile>(
///   context,
///   MaterialPageRoute(builder: (_) => const CameraScreen()),
/// );
/// ```
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  int _cameraIndex = 0;
  FlashMode _flashMode = FlashMode.off;

  bool _initialized = false;
  bool _isCapturing = false;
  String? _initError;

  // Non-null after capture — switches to review mode.
  XFile? _captured;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _disposeController();
    } else if (state == AppLifecycleState.resumed) {
      _startController(_cameras[_cameraIndex]);
    }
  }

  // ── Initialisation ────────────────────────────────────────────────────────

  Future<void> _init() async {
    try {
      _cameras = await availableCameras();
    } on CameraException catch (e) {
      if (mounted) setState(() => _initError = _describe(e));
      return;
    }
    if (_cameras.isEmpty) {
      if (mounted) setState(() => _initError = 'No cameras found on this device.');
      return;
    }
    // Prefer the rear camera.
    final backIdx = _cameras.indexWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
    );
    _cameraIndex = backIdx != -1 ? backIdx : 0;
    await _startController(_cameras[_cameraIndex]);
  }

  Future<void> _startController(CameraDescription camera) async {
    final ctrl = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _controller = ctrl;
    try {
      await ctrl.initialize();
      if (mounted) setState(() => _initialized = true);
    } on CameraException catch (e) {
      if (mounted) setState(() => _initError = _describe(e));
    }
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
    if (mounted) setState(() => _initialized = false);
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _capture() async {
    final ctrl = _controller;
    if (_isCapturing || ctrl == null || !ctrl.value.isInitialized) return;
    setState(() => _isCapturing = true);
    try {
      final file = await ctrl.takePicture();
      if (mounted) setState(() { _captured = file; _isCapturing = false; });
    } on CameraException catch (e) {
      if (mounted) {
        setState(() => _isCapturing = false);
        _showSnack(_describe(e));
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    final nextIdx = (_cameraIndex + 1) % _cameras.length;
    _disposeController();
    setState(() { _cameraIndex = nextIdx; _initialized = false; });
    await _startController(_cameras[_cameraIndex]);
  }

  Future<void> _cycleFlash() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    final next = _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
    try {
      await ctrl.setFlashMode(next);
      if (mounted) setState(() => _flashMode = next);
    } catch (_) {
      // Devices without a flash just ignore this.
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  String _describe(CameraException e) {
    switch (e.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
      case 'CameraAccessRestricted':
        return 'Camera access denied. Enable it in Settings.';
      case 'noCamerasAvailable':
        return 'No cameras available on this device.';
      default:
        return e.description ?? 'Camera error (${e.code})';
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // After capture: show the review screen.
    if (_captured != null) {
      return _ReviewScreen(
        file: _captured!,
        onRetake: () => setState(() => _captured = null),
        onUse: () => Navigator.pop(context, _captured),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildPreview(),
          if (_initialized) ...[
            const _SquareOverlay(),
            _buildInstructions(),
            _buildControls(),
          ],
          // Close button — always visible.
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                tooltip: 'Close camera',
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (_initError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt_outlined,
                  color: Colors.white38, size: 64),
              const SizedBox(height: 20),
              Text(
                _initError!,
                style: const TextStyle(color: Colors.white60, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (!_initialized || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final ctrl = _controller!;
    final ps = ctrl.value.previewSize ?? const Size(4, 3);
    // Android reports the sensor size in landscape (width > height).
    // Swap to portrait so FittedBox.cover fills the phone screen correctly.
    final previewW = Platform.isAndroid ? ps.height : ps.width;
    final previewH = Platform.isAndroid ? ps.width : ps.height;

    return SizedBox.expand(
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: previewW,
            height: previewH,
            child: CameraPreview(ctrl),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    final size = MediaQuery.sizeOf(context);
    final squareSide = size.width * _kSquareFraction;
    final squareTop = (size.height - squareSide) / 2;

    return Positioned(
      top: squareTop + squareSide + 14,
      left: 0,
      right: 0,
      child: Center(
        child: Text(
          'Place the product inside the frame',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.88),
            fontSize: 13,
            fontWeight: FontWeight.w500,
            shadows: const [Shadow(blurRadius: 6, color: Colors.black54)],
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    final size = MediaQuery.sizeOf(context);
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final squareSide = size.width * _kSquareFraction;
    final squareTop = (size.height - squareSide) / 2;
    final squareBottom = squareTop + squareSide;

    return Positioned(
      left: 0,
      right: 0,
      // 44 = instruction text height + spacing; give it comfortable room above controls.
      top: squareBottom + 44,
      bottom: safeBottom + 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _CircleIconButton(
            icon: _flashMode == FlashMode.off
                ? Icons.flash_off_rounded
                : Icons.flash_on_rounded,
            tooltip: 'Toggle flash',
            onTap: _cycleFlash,
          ),
          _CaptureButton(
            isCapturing: _isCapturing,
            onTap: _capture,
          ),
          _CircleIconButton(
            icon: Icons.cameraswitch_outlined,
            tooltip: 'Switch camera',
            onTap: _cameras.length > 1 ? _switchCamera : null,
          ),
        ],
      ),
    );
  }
}

// ── Square framing overlay ─────────────────────────────────────────────────

const double _kSquareFraction = 0.82;

class _SquareOverlay extends StatelessWidget {
  const _SquareOverlay();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _OverlayPainter(),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  // PetaFinds teal — hard-coded because the camera screen is always dark.
  static const _kTeal = Color(0xFF0D6E6E);
  static const _kCornerLen = 22.0;
  static const _kBorderWidth = 2.0;
  static const _kRadius = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final squareSide = size.width * _kSquareFraction;
    final squareRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: squareSide,
      height: squareSide,
    );
    final rrect = RRect.fromRectAndRadius(
        squareRect, const Radius.circular(_kRadius));

    // 1. Dark vignette outside the square.
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(rrect),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.54),
    );

    // 2. Corner L-marks in teal.
    final cp = Paint()
      ..color = _kTeal
      ..strokeWidth = _kBorderWidth + 1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    final l = squareRect.left;
    final t = squareRect.top;
    final r = squareRect.right;
    final b = squareRect.bottom;
    const rad = _kRadius;
    const cl = _kCornerLen;

    // Top-left
    canvas.drawLine(Offset(l, t + rad), Offset(l, t + rad + cl), cp);
    canvas.drawLine(Offset(l + rad, t), Offset(l + rad + cl, t), cp);
    // Top-right
    canvas.drawLine(Offset(r, t + rad), Offset(r, t + rad + cl), cp);
    canvas.drawLine(Offset(r - rad, t), Offset(r - rad - cl, t), cp);
    // Bottom-left
    canvas.drawLine(Offset(l, b - rad), Offset(l, b - rad - cl), cp);
    canvas.drawLine(Offset(l + rad, b), Offset(l + rad + cl, b), cp);
    // Bottom-right
    canvas.drawLine(Offset(r, b - rad), Offset(r, b - rad - cl), cp);
    canvas.drawLine(Offset(r - rad, b), Offset(r - rad - cl, b), cp);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Controls ──────────────────────────────────────────────────────────────

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _CircleIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: onTap != null ? 0.18 : 0.06),
          ),
          child: Icon(
            icon,
            color: Colors.white.withValues(alpha: onTap != null ? 1.0 : 0.3),
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  final bool isCapturing;
  final VoidCallback onTap;

  const _CaptureButton({required this.isCapturing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isCapturing ? null : onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCapturing
                  ? Colors.white.withValues(alpha: 0.5)
                  : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Review screen ─────────────────────────────────────────────────────────

/// Shows the captured photo with Retake / Use Photo actions.
class _ReviewScreen extends StatelessWidget {
  final XFile file;
  final VoidCallback onRetake;
  final VoidCallback onUse;

  const _ReviewScreen({
    required this.file,
    required this.onRetake,
    required this.onUse,
  });

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Preview fills the screen.
          Image.file(File(file.path), fit: BoxFit.contain),

          // Translucent top bar.
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: const Text(
                  'Review photo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                  ),
                ),
              ),
            ),
          ),

          // Action buttons.
          Positioned(
            left: 24,
            right: 24,
            bottom: safeBottom + 28,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onRetake,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retake'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onUse,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Use Photo'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0D6E6E),
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
