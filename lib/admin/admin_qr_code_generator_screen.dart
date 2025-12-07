import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui';
import 'dart:typed_data';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:geocoding/geocoding.dart';
import 'package:menufood/shared/models.dart';

class AdminQRCodeGeneratorScreen extends StatefulWidget {
  final Restaurant restaurant;

  const AdminQRCodeGeneratorScreen({super.key, required this.restaurant});

  @override
  State<AdminQRCodeGeneratorScreen> createState() => _AdminQRCodeGeneratorScreenState();
}

class _AdminQRCodeGeneratorScreenState extends State<AdminQRCodeGeneratorScreen> {
  final TextEditingController _tableNumberController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey _qrBoundaryKey = GlobalKey();

  String _qrDataRaw = '';
  String? _currentTableNumber;
  String _restaurantName = 'Đang tải...';
  GeoPoint? _restaurantLocation;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _tableNumberController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _initializeData() {
    setState(() {
      _restaurantName = widget.restaurant.name ?? 'Không rõ tên';
      _addressController.text = widget.restaurant.address ?? '';
      _restaurantLocation = widget.restaurant.location;
    });
  }

  Future<void> _getLocationFromAddress() async {
    if (_addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập địa chỉ trước')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      List<Location> locations = await locationFromAddress(_addressController.text, localeIdentifier: 'vi_VN');
      if (locations.isNotEmpty) {
        _restaurantLocation = GeoPoint(locations.first.latitude, locations.first.longitude);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã tìm thấy tọa độ: ${_restaurantLocation!.latitude}, ${_restaurantLocation!.longitude}')),
        );
      } else {
        _restaurantLocation = null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tìm thấy tọa độ cho địa chỉ này.')),
        );
      }
    } catch (e) {
      _restaurantLocation = null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi lấy tọa độ: $e')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _updateAddressAndLocation() async {
    if (_addressController.text.isEmpty || _restaurantLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập địa chỉ và tìm tọa độ trước.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _firestore.collection('restaurants').doc(widget.restaurant.id).update({
        'address': _addressController.text,
        'location': _restaurantLocation,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật địa chỉ và tọa độ nhà hàng thành công!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi cập nhật: $e')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _assignQrCodeContent() async {
    setState(() => _isSaving = true);
    final restaurantQrData = 'menufood://dinein/${widget.restaurant.id}/HOME';

    try {
      await _firestore.collection('restaurants').doc(widget.restaurant.id).update({
        'qrCodeContent': restaurantQrData,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gán đường dẫn QR (Deep Link) vào nhà hàng thành công!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi gán QR: $e')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _generateAndSaveTableQrCode() async {
    final tableNumber = _tableNumberController.text.trim();
    if (tableNumber.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập số bàn.');
      return;
    }

    final newQrData = 'menufood://dinein/${widget.restaurant.id}/$tableNumber';

    try {
      await _firestore.collection('tables').doc(tableNumber).set({
        'restaurantId': widget.restaurant.id,
        'tableNumber': tableNumber,
        'qrCodeData': newQrData,
        'status': 'available',
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _qrDataRaw = newQrData;
        _currentTableNumber = tableNumber;
        _errorMessage = null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã tạo và lưu dữ liệu QR cho bàn vào hệ thống!')),
        );
      });

    } catch (e) {
      setState(() => _errorMessage = 'Lỗi lưu dữ liệu: $e');
      print('Lỗi lưu dữ liệu QR: $e');
    }
  }

  void _copyQrData() {
    if (_qrDataRaw.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _qrDataRaw));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã sao chép chuỗi QR thô vào Clipboard!')),
      );
    }
  }

  Future<void> _saveQrCodeToGallery() async {
    if (_qrBoundaryKey.currentContext == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể tìm thấy mã QR để lưu.')));
      return;
    }

    try {
      final boundary = _qrBoundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 5.0);
      final byteData = await image.toByteData(format: ImageByteFormat.png);

      if (byteData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lỗi: Không thể mã hóa hình ảnh.')));
        return;
      }

      final pngBytes = byteData.buffer.asUint8List();

      final result = await ImageGallerySaverPlus.saveImage(
        Uint8List.fromList(pngBytes),
        name: 'QR_Table_${_currentTableNumber ?? widget.restaurant.id}_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (result['isSuccess'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã lưu mã QR thành công vào thư viện ảnh!')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi lưu ảnh: ${result['errorMessage'] ?? 'Vui lòng kiểm tra quyền truy cập lưu trữ.'}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi lưu mã QR: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tạo Mã QR & Cập nhật Nhà hàng', style: GoogleFonts.poppins()),
        backgroundColor: Colors.deepOrange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Nhà hàng: $_restaurantName (ID: ${widget.restaurant.id})',
              style: GoogleFonts.poppins(fontSize: 18, color: Colors.deepOrange, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            Text(
              '1. Cập nhật Địa chỉ & Tọa độ',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const Divider(),

            TextField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Địa Chỉ Nhà Hàng',
                border: const OutlineInputBorder(),
                labelStyle: GoogleFonts.poppins(),
              ),
            ),
            const SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: _isSaving ? null : _getLocationFromAddress,
              icon: const Icon(Icons.location_on, color: Colors.white),
              label: Text(
                _isSaving ? 'Đang tìm tọa độ...' : 'Tìm & Lấy Tọa Độ (GPS)',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            ),
            const SizedBox(height: 10),

            if (_restaurantLocation != null)
              Text(
                'Tọa độ: ${_restaurantLocation!.latitude.toStringAsFixed(4)}, ${_restaurantLocation!.longitude.toStringAsFixed(4)}',
                style: GoogleFonts.poppins(color: Colors.green, fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 15),

            ElevatedButton.icon(
              onPressed: _isSaving ? null : _updateAddressAndLocation,
              icon: const Icon(Icons.save, color: Colors.white),
              label: Text(
                'LƯU ĐỊA CHỈ & TỌA ĐỘ',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            ),
            const SizedBox(height: 30),

            Text(
              '2. Gán Deep Link Nhà Hàng',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const Divider(),

            Text(
              'Đây là bước quan trọng để kết nối mã QR với nhà hàng. (Ví dụ: menufood://dinein/${widget.restaurant.id}/HOME)',
              style: GoogleFonts.poppins(fontSize: 14, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: _isSaving ? null : _assignQrCodeContent,
              icon: const Icon(Icons.link, color: Colors.white),
              label: Text(
                'GÁN QR DEEP LINK VÀO NHÀ HÀNG',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            ),
            const SizedBox(height: 30),

            Text(
              '3. Tạo QR Code cho từng Bàn',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const Divider(),

            TextField(
              controller: _tableNumberController,
              decoration: InputDecoration(
                labelText: 'Nhập Số Bàn (VD: T01, VIP-A)',
                border: const OutlineInputBorder(),
                labelStyle: GoogleFonts.poppins(),
              ),
            ),
            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: _isSaving ? null : _generateAndSaveTableQrCode,
              icon: const Icon(Icons.qr_code, color: Colors.white),
              label: Text(
                'TẠO VÀ LƯU QR BÀN',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
            const SizedBox(height: 30),

            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: Text(_errorMessage!, style: GoogleFonts.poppins(color: Colors.red)),
              ),

            if (_qrDataRaw.isNotEmpty)
              Column(
                children: [
                  Text(
                    'Mã QR đã tạo cho Bàn: $_currentTableNumber',
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  RepaintBoundary(
                    key: _qrBoundaryKey,
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.deepOrange, width: 2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: QrImageView(
                        data: _qrDataRaw,
                        version: QrVersions.auto,
                        size: 250.0,
                        gapless: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Dữ liệu mã hóa (Deep Link): $_qrDataRaw',
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),

                  TextButton.icon(
                    onPressed: _copyQrData,
                    icon: const Icon(Icons.copy, size: 18, color: Colors.blue),
                    label: Text('Sao chép chuỗi QR thô', style: GoogleFonts.poppins(color: Colors.blue)),
                  ),
                  const SizedBox(height: 10),

                  ElevatedButton.icon(
                    onPressed: _saveQrCodeToGallery,
                    icon: const Icon(Icons.save_alt, color: Colors.white),
                    label: Text(
                      'LƯU HÌNH ẢNH VÀO MÁY',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}