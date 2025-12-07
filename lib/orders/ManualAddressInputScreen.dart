import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart' as geocoding;

class ManualAddressInputScreen extends StatefulWidget {
  final String? initialAddress;
  final String? initialPhoneNumber;

  const ManualAddressInputScreen({
    Key? key,
    this.initialAddress,
    this.initialPhoneNumber,
  }) : super(key: key);

  @override
  State<ManualAddressInputScreen> createState() => _ManualAddressInputScreenState();
}

class _ManualAddressInputScreenState extends State<ManualAddressInputScreen> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _addressController.text = widget.initialAddress ?? '';
    _phoneController.text = widget.initialPhoneNumber ?? '';
  }

  @override
  void dispose() {
    _addressController.dispose();
    _notesController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _handleSaveAddress() async {
    final fullAddress = _addressController.text.trim();
    final notes = _notesController.text.trim();
    final phoneNumber = _phoneController.text.trim();

    if (fullAddress.isEmpty) {
      _showSnackBar('Vui lòng nhập địa chỉ giao hàng chi tiết.');
      return;
    }

    if (phoneNumber.isEmpty) {
      _showSnackBar('Vui lòng nhập Số điện thoại liên lạc của bạn.');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    GeoPoint? geoPoint;
    bool geocodingSuccess = false;

    try {
      List<geocoding.Location> locations = await geocoding.locationFromAddress(fullAddress);

      if (locations.isNotEmpty) {
        geoPoint = GeoPoint(locations.first.latitude, locations.first.longitude);
        geocodingSuccess = true;
      }
    } catch (e) {
      print('Lỗi Geocoding khi nhập thủ công: $e');
    }

    setState(() {
      _isProcessing = false;
    });

    if (!geocodingSuccess) {
      _showSnackBar('Không tìm thấy tọa độ chính xác. Đơn hàng sẽ được xử lý bằng địa chỉ chuỗi.');
    }

    if (mounted) {
      Navigator.of(context).pop({
        'address': fullAddress,
        'location': geoPoint,
        'notes': notes,
        'phoneNumber': phoneNumber,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Nhập Địa Chỉ Thủ Công', style: GoogleFonts.poppins()),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Số điện thoại liên lạc',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: 'Nhập số điện thoại của bạn (Shipper sẽ gọi)',
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Địa chỉ giao hàng chi tiết',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _addressController,
              decoration: InputDecoration(
                hintText: 'Ví dụ: Số nhà 123, Đường A, Phường B, Quận C...',
                prefixIcon: const Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            Text(
              'Ghi chú cho tài xế (Tùy chọn)',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                hintText: 'Ví dụ: Giao sau 7h tối, gọi điện trước khi đến...',
                prefixIcon: const Icon(Icons.edit_note),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 30),

            // --- NÚT XÁC NHẬN ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _handleSaveAddress,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: _isProcessing
                    ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    SizedBox(width: 10),
                    Text('Đang xử lý...', style: TextStyle(color: Colors.white)),
                  ],
                )
                    : Text(
                  'XÁC NHẬN ĐỊA CHỈ',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Lưu ý: Chúng tôi sẽ cố gắng tìm tọa độ GPS từ địa chỉ bạn nhập. Nếu không tìm thấy, Shipper sẽ dựa vào địa chỉ chuỗi.',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}