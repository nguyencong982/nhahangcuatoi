import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:menufood/shared/models.dart';

class ShipperReceivedOrdersScreen extends StatelessWidget {
  const ShipperReceivedOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shipperId = FirebaseAuth.instance.currentUser?.uid;
    if (shipperId == null) {
      return const Scaffold(
        body: Center(child: Text('Không tìm thấy thông tin shipper')),
      );
    }

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('shipperId', isEqualTo: shipperId)
            .where('status', whereIn: ['picking up', 'delivered', 'completed'])
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data!.docs.map((doc) => AppOrder.fromFirestore(doc)).toList();
          if (orders.isEmpty) {
            return const Center(child: Text('Chưa có đơn hàng nào.'));
          }

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];

              final customerName = order.customerName ?? 'Người dùng';

              final customerPhone = order.customerPhoneNumber?.isNotEmpty == true
                  ? order.customerPhoneNumber!
                  : 'Không có SĐT';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ExpansionTile(
                  title: Text(
                    'Đơn hàng #${order.id.substring(0, 8)}',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Tổng tiền: ${NumberFormat('#,##0', 'vi_VN').format(order.totalAmount)} VNĐ',
                    style: GoogleFonts.poppins(color: Colors.grey[700]),
                  ),
                  children: [
                    ListTile(
                      title: Text('Người nhận: $customerName', style: GoogleFonts.poppins()),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('SĐT: $customerPhone', style: GoogleFonts.poppins()),
                          const SizedBox(height: 4),
                          Text('Địa chỉ: ${order.deliveryAddress ?? "Không có"}',
                              style: GoogleFonts.poppins()),
                          const SizedBox(height: 4),
                          Text('Ghi chú: ${order.customerNotes ?? "Không có"}',
                              style: GoogleFonts.poppins()),
                          const SizedBox(height: 8),
                          Text('Trạng thái: ${order.status}',
                              style: GoogleFonts.poppins(
                                color: order.status == 'completed'
                                    ? Colors.green
                                    : Colors.orange,
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}