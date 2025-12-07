import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_add_restaurant_screen.dart';
class AdminRestaurantListScreen extends StatelessWidget {
  const AdminRestaurantListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quản Lý Nhà Hàng', style: GoogleFonts.poppins()),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // Điều hướng đến màn hình Thêm mới (không truyền tham số)
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AdminRestaurantDetailScreen(),
                ),
              );
            },
            tooltip: 'Thêm Nhà Hàng Mới',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('restaurants').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi tải dữ liệu: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'Chưa có nhà hàng nào được thêm vào.',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            );
          }

          final restaurants = snapshot.data!.docs;

          return ListView.builder(
            itemCount: restaurants.length,
            itemBuilder: (context, index) {
              final restaurantDoc = restaurants[index];
              final data = restaurantDoc.data() as Map<String, dynamic>;
              final name = data['name'] ?? 'Tên chưa được đặt';
              final address = data['address'] ?? 'Địa chỉ chưa cập nhật';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                elevation: 2,
                child: ListTile(
                  leading: const Icon(Icons.restaurant, color: Colors.deepOrange),
                  title: Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  subtitle: Text(address),
                  trailing: const Icon(Icons.edit),
                  onTap: () {
                    // Điều hướng đến màn hình Chỉnh sửa (truyền DocumentSnapshot)
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => AdminRestaurantDetailScreen(
                          restaurantDocument: restaurantDoc,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}