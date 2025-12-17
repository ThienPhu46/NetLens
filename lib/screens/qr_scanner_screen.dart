import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'ar_switch_screen.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    returnImage: false,
  );
  bool isProcessing = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _handleBarcode(Barcode barcode) {
    if (isProcessing) return;
    String? ipAddress = barcode.rawValue;

    if (ipAddress != null && ipAddress.isNotEmpty) {
      setState(() {
        isProcessing = true;
      });
      controller.stop();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ArSwitchScreen(targetIp: ipAddress),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quét mã QR Switch')),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                MobileScanner(
                  controller: controller,
                  onDetect: (capture) {
                    if (capture.barcodes.isNotEmpty) {
                      _handleBarcode(capture.barcodes.first);
                    }
                  },
                ),
                Center(
                  child: Container(
                    width: 250, height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.red.withOpacity(0.5), width: 3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Expanded(
            flex: 1,
            child: Center(
              child: Text('Hướng camera vào mã QR chứa IP của Switch', style: TextStyle(color: Colors.white70)),
            ),
          )
        ],
      ),
    );
  }
}