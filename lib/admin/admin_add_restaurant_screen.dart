import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminRestaurantDetailScreen extends StatefulWidget {
  // DocumentSnapshot của nhà hàng cần chỉnh sửa. Null nếu là Thêm mới.
  final DocumentSnapshot? restaurantDocument;

  const AdminRestaurantDetailScreen({super.key, this.restaurantDocument});

  @override
  State<AdminRestaurantDetailScreen> createState() => _AdminRestaurantDetailScreenState();
}

class _AdminRestaurantDetailScreenState extends State<AdminRestaurantDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _qrCodeController = TextEditingController();

  GeoPoint? _restaurantLocation;
  bool _isLoading = false;
  late bool _isEditing;
  String? _restaurantId;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.restaurantDocument != null;
    if (_isEditing) {
      final data = widget.restaurantDocument!.data() as Map<String, dynamic>;
      _restaurantId = widget.restaurantDocument!.id;
      _nameController.text = data['name'] ?? '';
      _addressController.text = data['address'] ?? '';
      _descriptionController.text = data['description'] ?? '';
      _imageUrlController.text = data['imageUrl'] ?? '';
      _qrCodeController.text = data['qrCodeContent'] ?? '';
      _restaurantLocation = data['location'];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _qrCodeController.dispose();
    super.dispose();
  }

  Future<void> _getLocationFromAddress() async {
    if (_addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập địa chỉ trước')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

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
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveRestaurant() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final Map<String, dynamic> data = {
          'name': _nameController.text,
          'address': _addressController.text,
          'description': _descriptionController.text,
          'imageUrl': _imageUrlController.text,
          'qrCodeContent': _qrCodeController.text,
          'location': _restaurantLocation,
        };

        if (_isEditing) {
          // Chỉnh sửa (Update)
          await FirebaseFirestore.instance.collection('restaurants').doc(_restaurantId).update(data);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chỉnh sửa nhà hàng thành công!')),
          );
        } else {
          // Thêm mới (Add)
          await FirebaseFirestore.instance.collection('restaurants').add(data);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Thêm nhà hàng thành công!')),
          );
          _formKey.currentState!.reset();
          _restaurantLocation = null;
        }

        // Quay lại màn hình trước
        Navigator.of(context).pop();

      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteRestaurant(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xác nhận Xóa', style: GoogleFonts.poppins()),
        content: Text('Bạn có chắc chắn muốn xóa nhà hàng này? Thao tác này không thể hoàn tác.', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Hủy', style: GoogleFonts.poppins(color: Colors.blue)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Xóa', style: GoogleFonts.poppins(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && _restaurantId != null) {
      setState(() {
        _isLoading = true;
      });
      try {
        // Xóa document nhà hàng
        await FirebaseFirestore.instance.collection('restaurants').doc(_restaurantId).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Xóa nhà hàng thành công!')),
        );
        Navigator.of(context).pop();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi xóa: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Chỉnh Sửa Nhà Hàng' : 'Thêm Nhà Hàng', style: GoogleFonts.poppins()),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _isLoading ? null : () => _deleteRestaurant(context),
              tooltip: 'Xóa Nhà Hàng',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Tên Nhà Hàng',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập tên nhà hàng';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: 'Địa Chỉ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập địa chỉ';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _getLocationFromAddress,
                icon: _isLoading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.0,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.location_on),
                label: Text(
                  _isLoading ? 'Đang lấy tọa độ...' : 'Lấy tọa độ từ địa chỉ',
                  style: GoogleFonts.poppins(),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              if (_restaurantLocation != null)
                Text(
                  'Tọa độ đã lấy: ${_restaurantLocation!.latitude}, ${_restaurantLocation!.longitude}',
                  style: GoogleFonts.poppins(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Mô Tả',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _imageUrlController,
                decoration: InputDecoration(
                  labelText: 'URL Hình Ảnh',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _qrCodeController,
                decoration: InputDecoration(
                  labelText: 'Nội dung QR Code',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveRestaurant,
                icon: Icon(_isEditing ? Icons.save : Icons.add),
                label: Text(_isEditing ? 'Lưu Thay Đổi' : 'Thêm Nhà Hàng', style: GoogleFonts.poppins()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isEditing ? Colors.green : Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              if (_isEditing)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : () => _deleteRestaurant(context),
                    icon: const Icon(Icons.delete),
                    label: Text('Xóa Nhà Hàng', style: GoogleFonts.poppins()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}