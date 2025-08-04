import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'shared/menu_screen.dart';
import 'admin/admin_login_screen.dart';
import 'admin/admin_dashboard_screen.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isScanning = true;

  @override
  void initState() {
    super.initState();
    cameraController.start();
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void _handleBarcode(Barcode barcode) {
    if (!_isScanning) return;

    final String? rawValue = barcode.rawValue;
    if (rawValue != null) {
      print('Mã QR đã quét: $rawValue');
      _isScanning = false;

      String? restaurantId;
      String? tableNumber;

      final parts = rawValue.split(',');
      for (var part in parts) {
        final keyValue = part.split(':');
        if (keyValue.length == 2) {
          final key = keyValue[0].trim();
          final value = keyValue[1].trim();
          if (key == 'restaurant_id') {
            restaurantId = value;
          } else if (key == 'table_number') {
            tableNumber = value;
          }
        }
      }

      if (restaurantId != null && tableNumber != null) {
        cameraController.stop();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => MenuScreen(
              restaurantId: restaurantId!,
              tableNumber: tableNumber!,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mã QR không hợp lệ. Vui lòng thử lại.')),
        );
        _isScanning = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quét Mã QR Menu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            onPressed: () {
              cameraController.stop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AdminLoginScreen()),
              ).then((_) {
                cameraController.start();
              });
            },
            tooltip: 'Đăng nhập Admin',
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                _handleBarcode(barcodes.first);
              }
            },
          ),
          Center(
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.deepOrange, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.qr_code_scanner, size: 100, color: Colors.white54),
            ),
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text(
                'Hướng camera vào mã QR của bàn ăn để xem menu.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 16, shadows: [
                  Shadow(blurRadius: 5.0, color: Colors.black)
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
