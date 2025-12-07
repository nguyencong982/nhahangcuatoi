import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:menufood/shared/menu_screen.dart';
import 'package:menufood/admin/admin_login_screen.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> with WidgetsBindingObserver {
  final MobileScannerController cameraController = MobileScannerController();
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    cameraController.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    cameraController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        cameraController.start();
      }
    } else if (state == AppLifecycleState.paused) {
      cameraController.stop();
    }
  }

  Future<void> _handleBarcode(Barcode barcode) async {
    if (_isNavigating) return;

    final String? rawValue = barcode.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    print('🔍 Mã QR quét được: $rawValue');

    String? restaurantId;
    String? tableNumber;

    const deepLinkPrefix = 'menufood://dinein/';
    if (rawValue.startsWith(deepLinkPrefix)) {
      try {
        final path = rawValue.substring(deepLinkPrefix.length);
        final parts = path.split('/');

        if (parts.length >= 2) {
          restaurantId = parts[0];
          tableNumber = parts[1];
          print('✅ Phân tích Deep Link (String Split) thành công: $restaurantId - $tableNumber');
        } else {
          print('❌ Deep Link không đủ tham số: $rawValue');
        }
      } catch (e) {
        print('❌ Lỗi phân tích Deep Link: $e');
      }
    }

    else if (rawValue.contains('restaurant_id:') && rawValue.contains('table_number:')) {
      try {
        final cleanedRawValue = rawValue.replaceAll(' ', '');
        final parts = cleanedRawValue.split(',');
        for (var part in parts) {
          final pair = part.split(':');
          if (pair.length == 2) {
            final key = pair[0].trim();
            final value = pair[1].trim();

            if (key == 'restaurant_id') {
              restaurantId = value;
            } else if (key == 'table_number') {
              tableNumber = value;
            }
          }
        }
        if (restaurantId != null && tableNumber != null) {
          print('✅ Phân tích Key-Value (cũ) thành công: $restaurantId - $tableNumber');
        }
      } catch (e) {
        print('❌ Lỗi phân tích Key-Value: $e');
      }
    }


    if (restaurantId != null && tableNumber != null) {
      setState(() => _isNavigating = true);
      await cameraController.stop();

      print('✅ ĐIỀU HƯỚNG CUỐI CÙNG: Nhà hàng ID: $restaurantId - Bàn: $tableNumber');

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => MenuScreen(
            restaurantId: restaurantId!,
            tableNumber: tableNumber,
          ),
        ),
      );
      return;
    }

    if (mounted) {
      setState(() => _isNavigating = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mã QR không hợp lệ. Vui lòng thử lại.')),
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _isNavigating = false);
          cameraController.start();
        }
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quét Mã QR Menu'),
        backgroundColor: Colors.deepOrange,
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            tooltip: 'Đăng nhập Admin',
            onPressed: () {
              cameraController.stop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AdminLoginScreen()),
              );
            },
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
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.deepOrange, width: 3),
                borderRadius: BorderRadius.circular(15),
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
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  shadows: [Shadow(blurRadius: 5.0, color: Colors.black)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
