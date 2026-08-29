import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tx_browser/core/theme/tx_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/url_utils.dart';
import '../../services/search_service/search_service.dart';
import '../../state/tabs_provider.dart';
import '../../widgets/buttons/tx_button.dart';
import '../../widgets/buttons/tx_pressable.dart';

/// Real Camera QR Code and Barcode Scanner Screen with laser guide and fallback entry.
class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  MobileScannerController? _scannerController;
  bool _hasScanned = false;
  bool _isTorchOn = false;
  bool _hasPermission = false;
  bool _isCheckingPermission = true;
  String? _errorMessage;
  late AnimationController _laserAnimCtrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _laserAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _requestPermissionAndStart();
  }

  Future<void> _requestPermissionAndStart() async {
    setState(() {
      _isCheckingPermission = true;
      _errorMessage = null;
    });

    final status = await Permission.camera.request();
    if (!mounted) return;

    if (status.isGranted || status.isLimited) {
      _scannerController?.dispose();
      _scannerController = MobileScannerController(
        formats: const [BarcodeFormat.all],
        detectionSpeed: DetectionSpeed.normal,
      );
      setState(() {
        _hasPermission = true;
        _isCheckingPermission = false;
      });
    } else {
      setState(() {
        _hasPermission = false;
        _isCheckingPermission = false;
        _errorMessage = 'Camera access is needed to scan QR codes.';
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_scannerController == null || !_hasPermission) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _scannerController?.stop();
    } else if (state == AppLifecycleState.resumed && !_hasScanned) {
      _scannerController?.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _laserAnimCtrl.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.trim().isNotEmpty) {
        setState(() => _hasScanned = true);
        HapticFeedback.mediumImpact();
        _handleScannedContent(rawValue.trim());
        break;
      }
    }
  }

  void _handleScannedContent(String content) {
    _scannerController?.stop();

    final resolved = UrlUtils.isUrl(content)
        ? (UrlUtils.normalizeUrl(content) ?? 'https://$content')
        : const SearchService().resolve(content);

    ref.read(tabsProvider.notifier).openTab(url: resolved);
    context.go('/browser', extra: resolved);
  }

  void _toggleTorch() {
    _scannerController?.toggleTorch();
    setState(() => _isTorchOn = !_isTorchOn);
  }

  void _showManualInputDialog() {
    final textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Open URL or Search'),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter URL or barcode text',
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.go,
          onSubmitted: (val) {
            Navigator.pop(ctx);
            if (val.trim().isNotEmpty) {
              _handleScannedContent(val.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (textCtrl.text.trim().isNotEmpty) {
                _handleScannedContent(textCtrl.text.trim());
              }
            },
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      _handleScannedContent(text);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clipboard is empty')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ─── 1. CAMERA SCANNER VIEWPORT ─────────────────────────
            if (_hasPermission && _scannerController != null)
              MobileScanner(
                controller: _scannerController,
                onDetect: _onDetect,
                fit: BoxFit.cover,
                errorBuilder: (context, error) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(TxSpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.cameraOff, size: 48, color: colors.error),
                          const SizedBox(height: TxSpacing.md),
                          Text(
                            'Camera Error: ${error.errorCode.name}',
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: TxSpacing.lg),
                          TxButton(
                            label: 'Retry Camera',
                            icon: LucideIcons.rotateCw,
                            onPressed: _requestPermissionAndStart,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              )
            else if (_isCheckingPermission)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(TxSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.cameraOff,
                          size: 36,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: TxSpacing.lg),
                      const Text(
                        'Camera Access Needed',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: TxSpacing.sm),
                      Text(
                        _errorMessage ?? 'Enable camera permission to scan QR codes and URLs.',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: TxSpacing.xl),
                      TxButton(
                        label: 'Grant Permission',
                        icon: LucideIcons.shieldCheck,
                        onPressed: _requestPermissionAndStart,
                      ),
                      const SizedBox(height: TxSpacing.sm),
                      TextButton(
                        onPressed: () => openAppSettings(),
                        child: const Text(
                          'Open App Settings',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ─── 2. LASER SCANNING OVERLAY ──────────────────────────
            if (_hasPermission)
              SafeArea(
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final boxSize = (constraints.maxWidth * 0.65)
                          .clamp(180.0, 270.0)
                          .clamp(120.0, (constraints.maxHeight - 160.0).clamp(120.0, 270.0));
                      final laserTravel = boxSize - 40.0;

                      return SizedBox(
                        width: boxSize,
                        height: boxSize,
                        child: Stack(
                          children: [
                            // Viewfinder Reticle Corners
                            CustomPaint(
                              size: Size(boxSize, boxSize),
                              painter: _ReticlePainter(color: colors.primary),
                            ),
                            // Animated Scanning Laser Line
                            AnimatedBuilder(
                              animation: _laserAnimCtrl,
                              builder: (context, child) {
                                return Positioned(
                                  top: 20 + (_laserAnimCtrl.value * laserTravel),
                                  left: 20,
                                  right: 20,
                                  child: Container(
                                    height: 2.5,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          colors.primary.withValues(alpha: 0.1),
                                          colors.primary,
                                          colors.primary.withValues(alpha: 0.1),
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: colors.primary.withValues(alpha: 0.8),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

            // ─── 3. TOP ACTION BAR ──────────────────────────────────
            Positioned(
              top: MediaQuery.of(context).padding.top + TxSpacing.sm,
              left: TxSpacing.md,
              right: TxSpacing.md,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button
                  TxPressable(
                    onTap: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/');
                      }
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 1),
                      ),
                      child: const Center(
                        child: Icon(
                          LucideIcons.chevronLeft,
                          size: 22,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  // Title Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    child: const Text(
                      'Scan QR Code',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  // Torch Toggle Button
                  TxPressable(
                    onTap: _hasPermission ? _toggleTorch : null,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _isTorchOn
                            ? colors.primary
                            : Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 1),
                      ),
                      child: Center(
                        child: Icon(
                          _isTorchOn ? LucideIcons.zap : LucideIcons.zapOff,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ─── 4. BOTTOM ACTIONS DOCK ─────────────────────────────
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + TxSpacing.lg,
              left: TxSpacing.lg,
              right: TxSpacing.lg,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Align QR code within the frame to open automatically',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: TxSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Paste Clipboard action
                      TxPressable(
                        onTap: _pasteFromClipboard,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: TxSpacing.md,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.clipboard, size: 16, color: Colors.white),
                              SizedBox(width: 6),
                              Text(
                                'Paste URL',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: TxSpacing.sm),
                      // Enter Manually
                      TxPressable(
                        onTap: _showManualInputDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: TxSpacing.md,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.keyboard, size: 16, color: Colors.white),
                              SizedBox(width: 6),
                              Text(
                                'Type URL',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for precision rounded viewfinder reticle corners.
class _ReticlePainter extends CustomPainter {
  _ReticlePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 28.0;

    // Top-Left
    canvas.drawLine(const Offset(0, 0), const Offset(cornerLength, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, cornerLength), paint);

    // Top-Right
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - cornerLength, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, cornerLength), paint);

    // Bottom-Left
    canvas.drawLine(Offset(0, size.height), Offset(cornerLength, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - cornerLength), paint);

    // Bottom-Right
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - cornerLength, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant _ReticlePainter oldDelegate) => oldDelegate.color != color;
}
