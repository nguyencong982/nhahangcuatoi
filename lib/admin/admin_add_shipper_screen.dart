import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'AdminManageShippersScreen.dart';

class AdminAddShipperScreen extends StatefulWidget {
  final Map<String, dynamic>? shipperData;
  final String? docId;

  const AdminAddShipperScreen({super.key, this.shipperData, this.docId});

  @override
  State<AdminAddShipperScreen> createState() => _AdminAddShipperScreenState();
}

class _AdminAddShipperScreenState extends State<AdminAddShipperScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    if (widget.shipperData != null) {
      _isEditMode = true;
      _nameController.text = widget.shipperData!['name']?.toString() ?? '';
      _phoneController.text = widget.shipperData!['phone']?.toString() ?? '';
      _addressController.text = widget.shipperData!['address']?.toString() ?? '';
      _emailController.text = widget.shipperData!['email']?.toString() ?? '';
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  Future<void> _deleteShipper() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text('Xác nhận xóa', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: const Text('Tài khoản này sẽ bị xóa vĩnh viễn khỏi danh sách.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      setState(() => _isLoading = true);
      try {
        await FirebaseFirestore.instance.collection('users').doc(widget.docId).delete();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa shipper')));
        }
      } catch (e) {
        setState(() => _errorMessage = 'Lỗi khi xóa: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveShipper() async {
    if (!_isEditMode && _imageFile == null) {
      setState(() => _errorMessage = 'Vui lòng chọn ảnh đại diện cho Shipper');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      String photoUrl = widget.shipperData?['photoUrl']?.toString() ?? "";

      if (_imageFile != null) {
        String fileName = _isEditMode ? widget.docId! : DateTime.now().millisecondsSinceEpoch.toString();
        Reference storageRef = FirebaseStorage.instance.ref().child('shipper_avatars').child('$fileName.jpg');
        UploadTask uploadTask = storageRef.putFile(_imageFile!);
        TaskSnapshot snapshot = await uploadTask;
        photoUrl = await snapshot.ref.getDownloadURL();
      }

      if (_isEditMode) {
        await FirebaseFirestore.instance.collection('users').doc(widget.docId).update({
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'address': _addressController.text.trim(),
          'photoUrl': photoUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        setState(() => _successMessage = 'Cập nhật thành công!');
      } else {
        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'address': _addressController.text.trim(),
          'role': 'shipper',
          'photoUrl': photoUrl,
          'createdAt': FieldValue.serverTimestamp(),
        });

        _nameController.clear();
        _phoneController.clear();
        _emailController.clear();
        _passwordController.clear();
        _addressController.clear();
        _imageFile = null;
        setState(() => _successMessage = 'Tạo tài khoản thành công!');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Lỗi: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Sửa Shipper' : 'Tạo Tài Khoản Shipper',
            style: GoogleFonts.poppins(color: Colors.black, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          if (!_isEditMode)
            IconButton(
              icon: const Icon(Icons.list_alt, color: Colors.deepOrange),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdminManageShippersScreen()),
              ),
            ),
          if (_isEditMode)
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              onPressed: _isLoading ? null : _deleteShipper,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepOrange))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 55,
                backgroundColor: Colors.grey[200],
                backgroundImage: _imageFile != null
                    ? FileImage(_imageFile!)
                    : (_isEditMode && widget.shipperData?['photoUrl'] != null && widget.shipperData?['photoUrl'] != "")
                    ? NetworkImage(widget.shipperData!['photoUrl'].toString()) as ImageProvider
                    : null,
                child: (_imageFile == null && (!_isEditMode || widget.shipperData?['photoUrl'] == null || widget.shipperData?['photoUrl'] == ""))
                    ? const Icon(Icons.camera_alt, size: 40, color: Colors.grey)
                    : null,
              ),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Tên Shipper', prefixIcon: const Icon(Icons.person_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: 'Số điện thoại', prefixIcon: const Icon(Icons.phone_android), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _addressController,
              decoration: InputDecoration(labelText: 'Địa chỉ', prefixIcon: const Icon(Icons.map_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
            ),
            if (!_isEditMode) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'Email', prefixIcon: const Icon(Icons.alternate_email), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Mật khẩu', prefixIcon: const Icon(Icons.lock_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
              ),
            ],
            const SizedBox(height: 30),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
              ),
            if (_successMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_successMessage!, style: const TextStyle(color: Colors.green), textAlign: TextAlign.center),
              ),
            ElevatedButton(
              onPressed: _saveShipper,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: Text(_isEditMode ? 'CẬP NHẬT THÔNG TIN' : 'TẠO TÀI KHOẢN MỚI',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}