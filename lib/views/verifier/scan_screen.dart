import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:lottie/lottie.dart';
import 'package:docscamer/views/verifier/result_screen.dart';
import 'package:docscamer/main.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _isScanCompleted = false;
  bool _isFlashOn = false;
  final MobileScannerController controller = MobileScannerController();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: localeNotifier,
      builder: (context, locale, _) {
        final bool isFr = locale.languageCode == 'fr';
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: Text(isFr ? "Scanner un document" : "Scan a document"),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off, color: Colors.white),
                onPressed: () {
                  setState(() => _isFlashOn = !_isFlashOn);
                  controller.toggleTorch();
                },
              ),
            ],
          ),
          body: Stack(
            children: [
              MobileScanner(
                controller: controller,
                onDetect: (capture) {
                  if (_isScanCompleted) return;
                  final List<Barcode> barcodes = capture.barcodes;
                  for (final barcode in barcodes) {
                    final String? code = barcode.rawValue;
                    if (code != null) {
                      setState(() => _isScanCompleted = true);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ResultScreen(qrData: code),
                        ),
                      ).then((_) => setState(() => _isScanCompleted = false));
                      break;
                    }
                  }
                },
              ),
              // Overlay design pro
              _buildOverlay(context, isFr),
              
              Positioned(
                bottom: 60,
                left: 24,
                right: 24,
                child: Column(
                  children: [
                    Text(
                      isFr ? "Assurez-vous que le document est :" : "Ensure the document is:",
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _hintTag(isFr ? "Bien éclairé" : "Well lit"),
                        const SizedBox(width: 8),
                        _hintTag(isFr ? "Non flou" : "Not blurry"),
                        const SizedBox(width: 8),
                        _hintTag(isFr ? "Entier et à plat" : "Entire and flat"),
                      ],
                    ),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _hintTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11)),
    );
  }

  Widget _buildOverlay(BuildContext context, bool isFr) {
    return Stack(
      children: [
        // Darken outside area
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.7),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Center(
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ],
          ),
        ),
        Center(
          child: SizedBox(
            width: 280,
            height: 280,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF007A5E).withValues(alpha: 0.3), width: 1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Center(
                child: Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Color(0xFF007A5E),
                  size: 64,
                ),
              ),
            ),
          ),
        ),
        // Frame corners
        Center(
          child: SizedBox(
            width: 280,
            height: 280,
            child: CustomPaint(
              painter: ScannerFramePainter(),
            ),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 320),
            child: Text(
              isFr ? "Placez le document dans le cadre" : "Place the document in the frame",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ],
    );
  }
}

class ScannerFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF007A5E)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 40.0;
    const radius = 24.0;

    // Top Left
    canvas.drawArc(Rect.fromLTWH(0, 0, radius * 2, radius * 2), 3.14, 1.57, false, paint);
    canvas.drawLine(const Offset(radius, 0), const Offset(cornerLength, 0), paint);
    canvas.drawLine(const Offset(0, radius), const Offset(0, cornerLength), paint);

    // Top Right
    canvas.drawArc(Rect.fromLTWH(size.width - radius * 2, 0, radius * 2, radius * 2), -1.57, 1.57, false, paint);
    canvas.drawLine(Offset(size.width - radius, 0), Offset(size.width - cornerLength, 0), paint);
    canvas.drawLine(Offset(size.width, radius), Offset(size.width, cornerLength), paint);

    // Bottom Left
    canvas.drawArc(Rect.fromLTWH(0, size.height - radius * 2, radius * 2, radius * 2), 1.57, 1.57, false, paint);
    canvas.drawLine(Offset(radius, size.height), Offset(cornerLength, size.height), paint);
    canvas.drawLine(Offset(0, size.height - radius), Offset(0, size.height - cornerLength), paint);

    // Bottom Right
    canvas.drawArc(Rect.fromLTWH(size.width - radius * 2, size.height - radius * 2, radius * 2, radius * 2), 0, 1.57, false, paint);
    canvas.drawLine(Offset(size.width - radius, size.height), Offset(size.width - cornerLength, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height - radius), Offset(size.width, size.height - cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
