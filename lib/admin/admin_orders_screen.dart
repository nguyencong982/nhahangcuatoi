import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:menufood/shared/models.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  static const Color commonBackgroundColor = Color(0xFFFCF6E0);
  static const Color primaryOrangeColor = Color(0xFFF96E21);

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
        'status': newStatus,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cập nhật trạng thái đơn hàng $orderId thành "$newStatus" thành công!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi cập nhật trạng thái: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showConfirmationDialog(String orderId, String currentStatus, String newStatus, String actionText) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(
            'Xác nhận hành động',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Bạn có chắc chắn muốn "$actionText" đơn hàng này không?',
            style: GoogleFonts.poppins(),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text('Hủy', style: GoogleFonts.poppins(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _updateOrderStatus(orderId, newStatus);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryOrangeColor,
                foregroundColor: Colors.white,
              ),
              child: Text(actionText, style: GoogleFonts.poppins()),
            ),
          ],
        );
      },
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Chờ xử lý';
      case 'preparing':
        return 'Đang chuẩn bị';
      case 'ready':
        return 'Sẵn sàng';
      case 'delivering':
        return 'Đang giao hàng';
      case 'completed':
        return 'Hoàn thành';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return 'Không xác định';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'preparing':
        return Colors.blue;
      case 'ready':
        return Colors.purple;
      case 'delivering':
        return Colors.indigo;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: commonBackgroundColor,
      appBar: AppBar(
        backgroundColor: commonBackgroundColor,
        title: Text('Quản lý Đơn hàng', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Lỗi khi tải đơn hàng: ${snapshot.error}',
                style: GoogleFonts.poppins(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'Không có đơn hàng nào.',
                style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
            );
          }

          final orders = snapshot.data!.docs.map((doc) => AppOrder.fromFirestore(doc)).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Đơn hàng #${order.id.substring(0, 8)}',
                            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(order.status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Text(
                              _getStatusText(order.status),
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _getStatusColor(order.status),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Loại đơn: ${order.orderType == 'dine_in' ? 'Ăn tại quán' : 'Giao hàng'}',
                        style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[700]),
                      ),
                      if (order.tableNumber != null && order.tableNumber!.isNotEmpty)
                        Text(
                          'Bàn số: ${order.tableNumber}',
                          style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[700]),
                        ),
                      Text(
                        'Tổng tiền: ${order.totalAmount.toStringAsFixed(0)} VNĐ',
                        style: GoogleFonts.poppins(fontSize: 16, color: primaryOrangeColor, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Thời gian: ${DateFormat('dd/MM/yyyy HH:mm').format(order.timestamp.toDate())}',
                        style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700]),
                      ),
                      if (order.customerNotes != null && order.customerNotes!.isNotEmpty)
                        Text(
                          'Ghi chú: ${order.customerNotes}',
                          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700]),
                        ),
                      if (order.orderType == 'delivery' && order.deliveryAddress != null && order.deliveryAddress!.isNotEmpty)
                        Text(
                          'Địa chỉ: ${order.deliveryAddress}',
                          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700]),
                        ),
                      const Divider(height: 20, thickness: 0.5),
                      Text(
                        'Món ăn (${order.items.length}):',
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: order.items.length,
                        itemBuilder: (context, itemIndex) {
                          final item = order.items[itemIndex];
                          return Text(
                            '  - ${item['name']} x ${item['quantity']} (${(item['price'] as num).toStringAsFixed(0)} VNĐ)',
                            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[800]),
                          );
                        },
                      ),
                      const SizedBox(height: 15),

                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: [
                          if (order.status == 'pending')
                            ElevatedButton(
                              onPressed: () => _showConfirmationDialog(order.id, order.status, 'preparing', 'Xác nhận đơn'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text('Xác nhận đơn', style: GoogleFonts.poppins(fontSize: 14)),
                            ),
                          if (order.status == 'preparing')
                            ElevatedButton(
                              onPressed: () => _showConfirmationDialog(order.id, order.status, 'ready', 'Sẵn sàng'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text('Đã chuẩn bị xong', style: GoogleFonts.poppins(fontSize: 14)),
                            ),
                          if (order.status == 'ready' && order.orderType == 'delivery')
                            ElevatedButton(
                              onPressed: () => _showConfirmationDialog(order.id, order.status, 'delivering', 'Bắt đầu giao'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text('Bắt đầu giao', style: GoogleFonts.poppins(fontSize: 14)),
                            ),
                          if (order.status == 'delivering' || (order.status == 'ready' && order.orderType == 'dine_in'))
                            ElevatedButton(
                              onPressed: () => _showConfirmationDialog(order.id, order.status, 'completed', 'Hoàn thành'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text('Hoàn thành', style: GoogleFonts.poppins(fontSize: 14)),
                            ),
                          if (order.status == 'pending' || order.status == 'preparing')
                            ElevatedButton(
                              onPressed: () => _showConfirmationDialog(order.id, order.status, 'cancelled', 'Từ chối đơn'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text('Từ chối đơn', style: GoogleFonts.poppins(fontSize: 14)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}