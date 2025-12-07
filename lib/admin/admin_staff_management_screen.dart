import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../shared/models.dart';
import 'admin_staff_form_screen.dart';

class AdminStaffManagementScreen extends StatefulWidget {
  const AdminStaffManagementScreen({super.key});

  @override
  State<AdminStaffManagementScreen> createState() => _AdminStaffManagementScreenState();
}

class _AdminStaffManagementScreenState extends State<AdminStaffManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Quản lý Tài khoản Nhân viên',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => _navigateToAddStaff(context),
            tooltip: 'Thêm nhân viên mới',
          ),
        ],
      ),
      body: _buildStaffList(context),
    );
  }

  Widget _buildStaffList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .where('role', whereIn: ['manager', 'superAdmin']).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Lỗi tải dữ liệu: ${snapshot.error}. Vui lòng kiểm tra Firestore Rules.'));
        }

        final staffList = snapshot.data!.docs
            .map((doc) => AppUser.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
            .where((user) => !user.isDeleted)
            .toList();

        if (staffList.isEmpty) {
          return const Center(child: Text('Chưa có tài khoản nhân viên nào.'));
        }

        return ListView.builder(
          itemCount: staffList.length,
          itemBuilder: (context, index) {
            final user = staffList[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: user.imageUrl != null ? NetworkImage(user.imageUrl!) : null,
                  child: user.imageUrl == null ? const Icon(Icons.person_outline) : null,
                ),
                title: Text(user.name),
                subtitle: Text('${user.email} - Vai trò: ${user.role.toString().split('.').last.toUpperCase()}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _navigateToEditStaff(context, user),
                      tooltip: 'Chỉnh sửa',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmDeleteStaff(context, user),
                      tooltip: 'Vô hiệu hóa',
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _navigateToAddStaff(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AdminStaffFormScreen(isNew: true),
      ),
    );
  }

  void _navigateToEditStaff(BuildContext context, AppUser user) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AdminStaffFormScreen(isNew: false, user: user),
      ),
    );
  }

  void _confirmDeleteStaff(BuildContext context, AppUser user) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xác nhận Vô hiệu hóa'),
          content: Text('Bạn có chắc chắn muốn vô hiệu hóa tài khoản ${user.name} không? Tài khoản sẽ không thể đăng nhập.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () {
                _deleteStaff(user.id);
                Navigator.of(context).pop();
              },
              child: const Text('Vô hiệu hóa', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteStaff(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isDeleted': true,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã vô hiệu hóa tài khoản thành công!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi vô hiệu hóa tài khoản: $e')),
        );
      }
    }
  }
}