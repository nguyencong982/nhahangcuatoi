import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:menufood/shared/models.dart';
import 'package:menufood/orders/shipper_order_detail_screen.dart';
import 'package:menufood/welcome/WelcomeScreen.dart';
import 'package:intl/intl.dart';
import 'package:menufood/orders/ShipperStatisticsScreen.dart';
import 'package:menufood/orders/shipper_received_orders_screen.dart';
import 'package:menufood/chat/chat_screen.dart';

class ShipperHomeScreen extends StatefulWidget {
  const ShipperHomeScreen({super.key});

  @override
  State<ShipperHomeScreen> createState() => _ShipperHomeScreenState();
}

class _ShipperHomeScreenState extends State<ShipperHomeScreen> {
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  Stream<QuerySnapshot>? _availableOrdersStream;
  bool _isLoading = true;
  int _selectedIndex = 0;

  final GlobalKey<ShipperStatisticsScreenState> _statsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _fetchAvailableOrders();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      _showSnackBar('Không thể gọi điện thoại: $phoneNumber');
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar('Đã sao chép số điện thoại.');
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  String _getVietnameseStatus(String status) {
    switch (status) {
      case 'ready':
        return 'Sẵn sàng nhận';
      case 'picking up':
        return 'Đang lấy hàng';
      case 'in transit':
        return 'Đang giao hàng';
      case 'delivered':
        return 'Đã giao (Chờ xác nhận)';
      case 'completed':
        return 'Đã hoàn thành';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return 'Không rõ';
    }
  }

  void _fetchAvailableOrders() {
    _availableOrdersStream = FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'ready')
        .where('shipperId', isNull: true)
        .where('orderType', isEqualTo: 'delivery')
        .snapshots();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _acceptOrder(String orderId) async {
    try {
      final shipperId = FirebaseAuth.instance.currentUser?.uid;
      if (shipperId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lỗi: Không tìm thấy ID Shipper.')),
          );
        }
        return;
      }

      await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
        'shipperId': shipperId,
        'status': 'picking up',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ShipperOrderDetailScreen(orderId: orderId),
          ),
        ).then((result) {
          if (mounted) {
            _setSelectedIndexFromBottomNav(1);
            _fetchAvailableOrders();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi nhận đơn: $e')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      );
    }
  }

  void _openChatWithCustomer(String orderId, String customerId, String customerName, String shipperId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          orderId: orderId,
          customerId: customerId,
          customerName: customerName,
          shipperId: shipperId,
        ),
      ),
    );
  }

  void _openChatOrders() async {
    final shipperId = FirebaseAuth.instance.currentUser?.uid;
    if (shipperId == null) return;

    try {
      final chatStatuses = ['picking up', 'in transit', 'delivered'];

      final query = await FirebaseFirestore.instance
          .collection('orders')
          .where('shipperId', isEqualTo: shipperId)
          .where('status', whereIn: chatStatuses)
          .orderBy('updatedAt', descending: true)
          .get();

      if (!mounted) return;

      if (query.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không có đơn hàng nào đang hoạt động để liên hệ.')),
        );
        return;
      }

      showModalBottomSheet(
        context: context,
        builder: (context) {
          return ListView(
            children: query.docs.map((doc) {
              final order = AppOrder.fromFirestore(doc);

              final String? customerId = order.userId;
              final String? currentShipperId = order.shipperId;

              if (currentShipperId == null || currentShipperId != shipperId) return const SizedBox.shrink();

              final String customerName = order.customerName;
              final orderId = order.id;
              final orderStatus = order.status;

              if (customerId == null || customerId.isEmpty) {
                return ListTile(
                  title: Text(customerName, style: GoogleFonts.poppins(fontSize: 16)),
                  subtitle: Text('Đơn hàng #${orderId.substring(0, 8)} - Trạng thái: ${_getVietnameseStatus(orderStatus)} (Lỗi ID Khách)'),
                  trailing: const Text('Không thể chat', style: TextStyle(color: Colors.red)),
                );
              }

              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(customerName, style: GoogleFonts.poppins(fontSize: 16)),
                subtitle: Text('Đơn hàng #${orderId.substring(0, 8)} - Trạng thái: ${_getVietnameseStatus(orderStatus)}'),
                trailing: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _openChatWithCustomer(orderId, customerId, customerName, currentShipperId);
                  },
                  child: const Text('Chat'),
                ),
              );
            }).toList(),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi tải đơn hàng chat: ${e.toString()}')),
        );
      }
    }
  }

  void _setSelectedIndexFromBottomNav(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _setSelectedIndexFromDrawer(int index) {
    Navigator.of(context).pop();
    setState(() {
      _selectedIndex = index;
    });
    if (index == 3) {
      _statsKey.currentState?.fetchRevenueAndTransactions();
    }
  }

  Widget _buildBody() {
    if (_selectedIndex == 0) {
      return StreamBuilder<QuerySnapshot>(
        stream: _availableOrdersStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Đã xảy ra lỗi: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = snapshot.data!.docs;
          if (orders.isEmpty) {
            return const Center(
              child: Text('Không có đơn hàng nào có sẵn.'),
            );
          }
          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = AppOrder.fromFirestore(orders[index]);
              final customerName = order.customerName ?? 'Khách hàng ẩn danh';
              final customerId = order.userId;
              final currentShipperId = FirebaseAuth.instance.currentUser?.uid ?? '';
              final customerPhoneNumber = order.customerPhoneNumber ?? 'Không có SĐT';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: ListTile(
                  title: Text('Đơn hàng: #${order.id.substring(0, 8)}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tổng tiền: ${NumberFormat('#,##0', 'vi_VN').format(order.totalAmount)} VNĐ'),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () {
                          if (customerPhoneNumber != 'Không có SĐT') {
                            _makePhoneCall(customerPhoneNumber);
                          } else {
                            _showSnackBar('Không có số điện thoại để gọi.');
                          }
                        },
                        onLongPress: () {
                          if (customerPhoneNumber != 'Không có SĐT') {
                            _copyToClipboard(customerPhoneNumber);
                          }
                        },
                        child: Row(
                          children: [
                            const Icon(Icons.phone, size: 16, color: Colors.green),
                            const SizedBox(width: 4),
                            Text(
                              customerPhoneNumber,
                              style: GoogleFonts.poppins(
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (customerPhoneNumber != 'Không có SĐT')
                              Icon(Icons.copy, size: 14, color: Colors.grey[600]),
                          ],
                        ),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (customerId.isNotEmpty && currentShipperId.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline, color: Colors.blue),
                          onPressed: () =>
                              _openChatWithCustomer(order.id, customerId, customerName, currentShipperId),
                          tooltip: 'Chat với khách hàng',
                        ),
                      ElevatedButton(
                        onPressed: () => _acceptOrder(order.id),
                        child: const Text('Nhận đơn'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } else if (_selectedIndex == 1) {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('shipperId', isEqualTo: _currentUserId)
            .where('status', whereIn: ['picking up', 'in transit', 'delivered'])
            .orderBy('updatedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Đã xảy ra lỗi: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = snapshot.data!.docs;
          if (orders.isEmpty) {
            return const Center(
              child: Text('Không có đơn hàng đang giao nào.'),
            );
          }

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = AppOrder.fromFirestore(orders[index]);
              final customerPhoneNumber = order.customerPhoneNumber ?? 'Không có SĐT';
              final customerName = order.customerName ?? 'Khách hàng ẩn danh';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: ListTile(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ShipperOrderDetailScreen(orderId: order.id),
                      ),
                    );
                  },
                  title: Text('Đơn hàng: #${order.id.substring(0, 8)}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Trạng thái: ${_getVietnameseStatus(order.status)}',
                          style: GoogleFonts.poppins(color: Colors.deepOrange, fontWeight: FontWeight.w500)),
                      Text('Tổng tiền: ${NumberFormat('#,##0', 'vi_VN').format(order.totalAmount)} VNĐ'),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () {
                          if (customerPhoneNumber != 'Không có SĐT') {
                            _makePhoneCall(customerPhoneNumber);
                          } else {
                            _showSnackBar('Không có số điện thoại để gọi.');
                          }
                        },
                        onLongPress: () {
                          if (customerPhoneNumber != 'Không có SĐT') {
                            _copyToClipboard(customerPhoneNumber);
                          }
                        },
                        child: Row(
                          children: [
                            const Icon(Icons.phone, size: 16, color: Colors.green),
                            const SizedBox(width: 4),
                            Text(
                              customerPhoneNumber,
                              style: GoogleFonts.poppins(
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (customerPhoneNumber != 'Không có SĐT')
                              Icon(Icons.copy, size: 14, color: Colors.grey[600]),
                          ],
                        ),
                      ),
                    ],
                  ),
                  trailing: (order.userId != null && _currentUserId.isNotEmpty)
                      ? IconButton(
                    icon: const Icon(Icons.chat_bubble, color: Colors.deepOrange),
                    onPressed: () =>
                        _openChatWithCustomer(order.id, order.userId!, customerName, _currentUserId),
                    tooltip: 'Chat',
                  )
                      : null,
                ),
              );
            },
          );
        },
      );
    } else if (_selectedIndex == 2) {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('shipperId', isEqualTo: _currentUserId)
            .where('status', whereIn: ['completed', 'cancelled'])
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Đã xảy ra lỗi: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = snapshot.data!.docs;
          if (orders.isEmpty) {
            return const Center(
              child: Text('Không có đơn hàng đã hoàn thành hoặc đã hủy nào.'),
            );
          }

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = AppOrder.fromFirestore(orders[index]);

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: ListTile(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ShipperOrderDetailScreen(orderId: order.id),
                      ),
                    );
                  },
                  title: Text('Đơn hàng: #${order.id.substring(0, 8)}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Trạng thái: ${_getVietnameseStatus(order.status)}',
                          style: GoogleFonts.poppins(color: (order.status == 'cancelled') ? Colors.red : Colors.green, fontWeight: FontWeight.w500)),
                      Text('Tổng tiền: ${NumberFormat('#,##0', 'vi_VN').format(order.totalAmount)} VNĐ'),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } else if (_selectedIndex == 3) {
      return ShipperStatisticsScreen(key: _statsKey);
    }
    return Container();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    String appBarTitle;
    if (_selectedIndex == 1) {
      appBarTitle = 'Đơn đang giao (Chưa hoàn thành)';
    } else if (_selectedIndex == 2) {
      appBarTitle = 'Đơn đã nhận (Hoàn thành)';
    } else if (_selectedIndex == 3) {
      appBarTitle = 'Thống kê';
    } else {
      appBarTitle = 'Đơn hàng có sẵn';
    }


    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle, style: GoogleFonts.poppins()),
        backgroundColor: Colors.deepOrange,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Liên hệ đơn hàng đang giao',
            onPressed: _openChatOrders,
          ),
        ],
      ),
      body: _buildBody(),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Colors.deepOrange,
              ),
              child: Text(
                'Menu Shipper',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline, color: Colors.green),
              title: Text('Đơn đã nhận (Hoàn thành)', style: GoogleFonts.poppins(fontWeight: _selectedIndex == 2 ? FontWeight.bold : FontWeight.normal)),
              selected: _selectedIndex == 2,
              onTap: () => _setSelectedIndexFromDrawer(2),
            ),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: Text('Thống kê', style: GoogleFonts.poppins(fontWeight: _selectedIndex == 3 ? FontWeight.bold : FontWeight.normal)),
              selected: _selectedIndex == 3,
              onTap: () => _setSelectedIndexFromDrawer(3),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text('Đăng xuất', style: GoogleFonts.poppins(color: Colors.red)),
              onTap: _signOut,
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping),
            label: 'Đơn hàng',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.delivery_dining),
            label: 'Đang giao',
          ),
        ],
        currentIndex: (_selectedIndex == 0 || _selectedIndex == 1) ? _selectedIndex : 0,
        selectedItemColor: Colors.deepOrange,
        onTap: _setSelectedIndexFromBottomNav,
      ),
    );
  }
}