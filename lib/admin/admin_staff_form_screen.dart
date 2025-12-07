import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../shared/models.dart';

class AdminStaffFormScreen extends StatefulWidget {
  final bool isNew;
  final AppUser? user;

  const AdminStaffFormScreen({super.key, required this.isNew, this.user});

  @override
  State<AdminStaffFormScreen> createState() => _AdminStaffFormScreenState();
}

class _AdminStaffFormScreenState extends State<AdminStaffFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  UserRole _selectedRole = UserRole.manager;

  @override
  void initState() {
    super.initState();
    if (!widget.isNew && widget.user != null) {
      _emailController.text = widget.user!.email;
      _nameController.text = widget.user!.name;
      _phoneController.text = widget.user!.phone ?? '';
      _selectedRole = widget.user!.role;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (widget.isNew) {
        await _createNewStaff();
      } else {
        await _updateExistingStaff();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.isNew ? 'Tạo tài khoản thành công!' : 'Cập nhật tài khoản thành công!')),
        );
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      _showError('Lỗi xác thực: ${e.message}');
    } catch (e) {
      _showError('Lỗi: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createNewStaff() async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    final newStaff = AppUser(
      id: userCredential.user!.uid,
      email: _emailController.text.trim(),
      name: _nameController.text.trim(),
      role: _selectedRole,
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      imageUrl: null,
      isDeleted: false,
    );

    await _firestore.collection('users').doc(newStaff.id).set(newStaff.toFirestore());
  }

  Future<void> _updateExistingStaff() async {
    if (widget.user == null) throw Exception("User object is missing for update.");

    final updateData = {
      'name': _nameController.text.trim(),
      'role': _selectedRole.toString().split('.').last,
      'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
    };

    await _firestore.collection('users').doc(widget.user!.id).update(updateData);

    if (_passwordController.text.isNotEmpty) {
      _showError('Để thay đổi mật khẩu của người dùng khác, vui lòng sử dụng Cloud Functions.');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isNew ? 'Thêm Nhân viên Mới' : 'Chỉnh sửa: ${widget.user!.name}',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                readOnly: !widget.isNew,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.email),
                  fillColor: widget.isNew ? Colors.white : Colors.grey[200],
                  filled: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty || !value.contains('@')) {
                    return 'Vui lòng nhập email hợp lệ.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _passwordController,
                keyboardType: TextInputType.text,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: widget.isNew ? 'Mật khẩu (Tối thiểu 6 ký tự)' : 'Mật khẩu mới (Để trống nếu không đổi)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                ),
                validator: (value) {
                  if (widget.isNew && (value == null || value.length < 6)) {
                    return 'Mật khẩu phải có ít nhất 6 ký tự.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Họ và Tên',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập họ và tên.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Số Điện Thoại',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<UserRole>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Vai trò',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
                items: UserRole.values
                    .where((role) => role == UserRole.manager || role == UserRole.superAdmin)
                    .map((UserRole role) {
                  return DropdownMenuItem<UserRole>(
                    value: role,
                    child: Text(role.toString().split('.').last.toUpperCase()),
                  );
                }).toList(),
                onChanged: (UserRole? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedRole = newValue;
                    });
                  }
                },
              ),
              const SizedBox(height: 40),
              Center(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitForm,
                  icon: _isLoading ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                  ) : const Icon(Icons.save),
                  label: Text(
                    widget.isNew ? 'TẠO TÀI KHOẢN' : 'CẬP NHẬT',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 55),
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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