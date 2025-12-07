import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:menufood/shared/models.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  static const Color commonBackgroundColor = Color(0xFFFCF6E0);
  static const Color primaryOrangeColor = Color(0xFFF96E21);

  final String _currentAdminId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown_admin';

  Future<String> _getShipperName(String? shipperId) async {
    if (shipperId == null || shipperId.isEmpty) {
      return 'Chưa có';
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(shipperId).get();
      if (doc.exists) {
        return doc.data()?['fullName'] ?? doc.data()?['name'] ?? 'Shipper (ID: ${shipperId.substring(0, 4)}...)';
      }
      return 'Không tìm thấy shipper';
    } catch (e) {
      print('Lỗi khi lấy tên shipper: $e');
      return 'Lỗi tải tên';
    }
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus, {String? cancelledBy}) async {
    try {
      final updateData = {
        'status': newStatus,
        'adminUpdateAt': FieldValue.serverTimestamp(),
      };

      if (newStatus == 'cancelled' && cancelledBy != null) {
        updateData['cancelledAt'] = FieldValue.serverTimestamp();
        updateData['cancelledBy'] = cancelledBy;
      } else if (newStatus != 'cancelled') {
        updateData.remove('cancelledAt');
        updateData.remove('cancelledBy');
      }

      await FirebaseFirestore.instance.collection('orders').doc(orderId).update(updateData);

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

  Future<void> _updatePaymentStatus(String orderId, String newPaymentStatus) async {
    try {
      final updateData = {
        'paymentStatus': newPaymentStatus,
        'paymentReceivedAt': FieldValue.serverTimestamp(),
        'paymentConfirmedBy': _currentAdminId,
      };

      await FirebaseFirestore.instance.collection('orders').doc(orderId).update(updateData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cập nhật trạng thái thanh toán đơn hàng $orderId thành "$newPaymentStatus" thành công!'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi cập nhật trạng thái thanh toán: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showConfirmationDialog(String orderId, String currentStatus, String newStatus, String actionText, {bool isPaymentAction = false}) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        final isCancelAction = newStatus == 'cancelled';
        final cancelActionText = isCancelAction ? 'Từ chối đơn' : actionText;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(
            isPaymentAction ? 'Xác nhận Thanh toán' : 'Xác nhận hành động',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: Text(
            isPaymentAction
                ? 'Bạn có chắc chắn đã nhận đủ số tiền và muốn đánh dấu đơn hàng này là Đã Thanh Toán?'
                : 'Bạn có chắc chắn muốn "$cancelActionText" đơn hàng này không?',
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
                if (isPaymentAction) {
                  _updatePaymentStatus(orderId, 'paid');
                } else {
                  _updateOrderStatus(orderId, newStatus, cancelledBy: isCancelAction ? 'admin' : null);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isCancelAction ? Colors.red : (isPaymentAction ? Colors.lightBlue : primaryOrangeColor),
                foregroundColor: Colors.white,
              ),
              child: Text(isPaymentAction ? 'Đã nhận tiền' : cancelActionText, style: GoogleFonts.poppins()),
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
      case 'picking up':
        return 'Đang đi lấy hàng';
      case 'in transit':
        return 'Đang giao hàng';
      case 'delivered':
        return 'Đã giao thành công';
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
      case 'picking up':
        return Colors.brown;
      case 'in transit':
        return Colors.indigo;
      case 'delivered':
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getPaymentStatusText(String status) {
    switch (status) {
      case 'unpaid':
        return 'Chưa thanh toán (Tiền mặt)';
      case 'awaiting_payment':
        return 'Chờ xác nhận online';
      case 'paid':
        return 'Đã thanh toán';
      case 'refunded':
        return 'Đã hoàn tiền';
      default:
        return 'Không rõ';
    }
  }

  Color _getPaymentStatusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'unpaid':
      case 'awaiting_payment':
        return Colors.red;
      case 'refunded':
        return Colors.orange;
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
              final isCancelled = order.status == 'cancelled';
              final isPaid = order.paymentStatus == 'paid';
              final cancelledBy = order.cancelledBy ?? 'Hệ thống/Quản lý';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isCancelled
                      ? const BorderSide(color: Colors.red, width: 2.5)
                      : BorderSide.none,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Đơn hàng #${order.id.substring(0, 8)}',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isCancelled ? Colors.red : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FittedBox(
                            child: Container(
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
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Thanh toán: ${order.paymentMethod == 'cash' || order.paymentMethod == 'pos' ? 'Tại quầy/Tiền mặt' : 'Online/QR'}',
                              style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[700]),
                              overflow: TextOverflow.ellipsis, // Thêm ellipsis
                            ),
                          ),
                          const SizedBox(width: 8),
                          FittedBox(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getPaymentStatusColor(order.paymentStatus).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _getPaymentStatusText(order.paymentStatus),
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _getPaymentStatusColor(order.paymentStatus),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (isCancelled)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            cancelledBy == 'customer'
                                ? '⚠️ Đơn hàng đã bị KHÁCH HÀNG hủy.'
                                : 'Đơn hàng bị TỪ CHỐI bởi Quản lý/Hệ thống.',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                      if (order.shipperId != null && order.shipperId!.isNotEmpty)
                        FutureBuilder<String>(
                          future: _getShipperName(order.shipperId),
                          builder: (context, snapshot) {
                            final shipperName = snapshot.data ?? 'Đang tải...';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Text(
                                'Shipper: $shipperName',
                                style: GoogleFonts.poppins(fontSize: 15, color: Colors.indigo.shade700, fontWeight: FontWeight.w600),
                              ),
                            );
                          },
                        ),
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
                        'Tổng tiền: ${NumberFormat('#,##0', 'vi_VN').format(order.totalAmount)} VNĐ',
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
                            '  - ${item['name']} x ${item['quantity']} (${NumberFormat('#,##0', 'vi_VN').format(item['price'] as num)} VNĐ)',
                            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[800]),
                          );
                        },
                      ),
                      const SizedBox(height: 15),

                      if (!isCancelled && order.status != 'completed')
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: [
                            if (!isPaid)
                              ElevatedButton.icon(
                                onPressed: () => _showConfirmationDialog(
                                  order.id,
                                  order.status,
                                  'paid',
                                  'Đánh dấu đã nhận tiền',
                                  isPaymentAction: true,
                                ),
                                icon: const Icon(Icons.check_circle_outline),
                                label: Text('Đã nhận tiền', style: GoogleFonts.poppins(fontSize: 14)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.lightBlue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),

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

                            if (order.status == 'ready' && order.orderType == 'delivery' && (order.shipperId == null || order.shipperId!.isEmpty))
                              ElevatedButton(
                                onPressed: () {
                                  _showConfirmationDialog(order.id, order.status, 'ready', 'Mở cho Shipper nhận');
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueGrey,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text('Mở cho Shipper nhận', style: GoogleFonts.poppins(fontSize: 14)),
                              ),

                            if (order.status == 'picking up' || order.status == 'in transit')
                              Container(
                                padding: const EdgeInsets.all(8.0),
                                decoration: BoxDecoration(
                                    color: Colors.yellow.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.yellow.shade700)
                                ),
                                child: Text(
                                    'Shipper đang xử lý',
                                    style: GoogleFonts.poppins(color: Colors.yellow.shade900, fontWeight: FontWeight.bold)
                                ),
                              ),

                            if (order.status == 'ready' && order.orderType == 'dine_in' && isPaid)
                              ElevatedButton(
                                onPressed: () => _showConfirmationDialog(order.id, order.status, 'completed', 'Hoàn thành'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text('Hoàn thành (Dine-in)', style: GoogleFonts.poppins(fontSize: 14)),
                              ),

                            if (order.status == 'pending' || order.status == 'preparing' || order.status == 'ready')
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