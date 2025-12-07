import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:menufood/shared/models.dart';
import 'package:menufood/orders/order_tracking_screen.dart';
import 'package:menufood/chat/chat_screen.dart';
import 'package:menufood/shared/favorite_provider.dart';
import 'package:menufood/orders/review_input_screen.dart';

class PastOrdersScreen extends StatefulWidget {
  const PastOrdersScreen({super.key});

  @override
  State<PastOrdersScreen> createState() => _PastOrdersScreenState();
}

class _PastOrdersScreenState extends State<PastOrdersScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final currencyFormatter = NumberFormat.currency(locale: 'vi', symbol: '₫');

  void _navigateToChat(AppOrder order) {
    if (order.shipperId == null || currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đơn hàng chưa có Shipper hoặc bạn chưa đăng nhập.')),
      );
      return;
    }

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            orderId: order.id,
            customerId: order.userId,
            customerName: 'Bạn',
            shipperId: order.shipperId!,
          ),
        ),
      );
    }
  }

  void _navigateToReviewInputScreen({
    required String restaurantId,
    required String menuItemId,
    required String menuItemName,
    required String orderId,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ReviewInputScreen(
          restaurantId: restaurantId,
          menuItemId: menuItemId,
          menuItemName: menuItemName,
          orderId: orderId,
        ),
      ),
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
        return 'Shipper đang lấy hàng';
      case 'in transit':
        return 'Đang giao hàng';
      case 'delivered':
        return 'Đã giao hàng';
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
        return Colors.cyan;
      case 'in transit':
        return Colors.indigo.shade600;
      case 'delivered':
        return Colors.green.shade400;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildFavoriteButton(BuildContext context, String menuItemId, String restaurantId) {
    return Consumer<FavoriteProvider>(
      builder: (context, favoriteProvider, child) {
        final isFav = favoriteProvider.isFavorite(menuItemId);

        return IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(
            isFav ? Icons.favorite : Icons.favorite_border,
            color: isFav ? Colors.red.shade400 : Colors.grey,
            size: 18,
          ),
          onPressed: () async {
            await favoriteProvider.toggleFavorite(menuItemId, restaurantId);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isFav ? 'Đã xóa khỏi yêu thích.' : 'Đã thêm vào yêu thích.',
                  style: GoogleFonts.poppins(),
                ),
                duration: const Duration(milliseconds: 1000),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color commonBackgroundColor = Color(0xFFFCF6E0);

    if (currentUser == null) {
      return Scaffold(
        backgroundColor: commonBackgroundColor,
        appBar: AppBar(
          backgroundColor: commonBackgroundColor,
          title: Text('Đơn hàng của tôi', style: GoogleFonts.poppins(color: Colors.black87)),
          elevation: 0,
        ),
        body: Center(
          child: Text('Vui lòng đăng nhập để xem đơn hàng.', style: GoogleFonts.poppins()),
        ),
      );
    }

    return Scaffold(
      backgroundColor: commonBackgroundColor,
      appBar: AppBar(
        backgroundColor: commonBackgroundColor,
        title: Text('Đơn hàng của tôi', style: GoogleFonts.poppins(color: Colors.black87)),
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('userId', isEqualTo: currentUser!.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Lỗi khi tải đơn hàng: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('Bạn chưa có đơn hàng nào.', style: GoogleFonts.poppins()));
          }

          final orders = snapshot.data!.docs.map((doc) => AppOrder.fromFirestore(doc)).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final Timestamp? timestamp = order.timestamp;

              final orderDate = timestamp != null
                  ? DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate())
                  : 'Không rõ thời gian';

              final bool canChat = order.orderType == 'delivery' && order.shipperId != null &&
                  ['picking up', 'in transit'].contains(order.status);

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => OrderTrackingScreen(orderId: order.id),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        Text('Mã đơn: #${order.id.substring(0, 8)}',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepOrange)),
                        const SizedBox(height: 5),
                        Text('Thời gian: $orderDate',
                            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700])),
                        const SizedBox(height: 5),


                        const Divider(height: 20, thickness: 1),
                        Text('Chi tiết đơn hàng:', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
                        const SizedBox(height: 8),


                        ...order.items.map((itemMap) {
                          final itemId = itemMap['menuItemId'] as String;
                          final itemName = itemMap['name'] as String;
                          final itemQuantity = itemMap['quantity'] as int;
                          final itemPrice = itemMap['price'] as double;
                          final itemSubtotal = itemQuantity * itemPrice;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '$itemQuantity x $itemName (${currencyFormatter.format(itemSubtotal)})',
                                    style: GoogleFonts.poppins(fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),

                                if (order.status == 'completed' || order.status == 'delivered')
                                  TextButton(
                                    onPressed: () => _navigateToReviewInputScreen(
                                      restaurantId: order.restaurantId,
                                      menuItemId: itemId,
                                      menuItemName: itemName,
                                      orderId: order.id,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.star_border, size: 18, color: Colors.amber),
                                        const SizedBox(width: 4),
                                        Text('Đánh giá', style: GoogleFonts.poppins(fontSize: 12, color: Colors.amber)),
                                      ],
                                    ),
                                  ),

                                _buildFavoriteButton(context, itemId, order.restaurantId),
                              ],
                            ),
                          );
                        }).toList(),


                        const Divider(height: 20, thickness: 1),

                        Text('Tổng tiền: ${currencyFormatter.format(order.totalAmount)}',
                            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.deepOrange)),
                        const SizedBox(height: 10),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Trạng thái:', style: GoogleFonts.poppins(fontSize: 15)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getStatusColor(order.status).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _getStatusText(order.status),
                                style: GoogleFonts.poppins(
                                  color: _getStatusColor(order.status),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (canChat)
                          Padding(
                            padding: const EdgeInsets.only(top: 10.0),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => _navigateToChat(order),
                                icon: const Icon(Icons.chat_bubble_outline, size: 18, color: Colors.blue),
                                label: Text(
                                  'Chat với Shipper',
                                  style: GoogleFonts.poppins(color: Colors.blue, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
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