import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:menufood/welcome/welcomescreen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:menufood/admin/admin_orders_screen.dart';
import 'package:menufood/admin/admin_menu_screen.dart';
import 'package:menufood/admin/admin_category_screen.dart';
import 'package:menufood/admin/admin_statistics_screen.dart';
import 'package:menufood/admin/ManagerVoucherScreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:menufood/admin/admin_add_shipper_screen.dart';
import 'package:menufood/admin/admin_add_restaurant_screen.dart';
import '../shared/models.dart';
import 'admin_staff_management_screen.dart';
import 'admin_profile_screen.dart';
import 'package:menufood/admin/admin_qr_code_generator_screen.dart';
import 'package:menufood/admin/AdminRestaurantSelectorScreen.dart';
import 'package:menufood/admin/AdminRestaurantListScreen.dart';
import 'package:menufood/admin/AdminReviewManagementScreen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _pendingOrdersCount = 0;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isNotificationActive = false;
  UserRole _currentUserRole = UserRole.superAdmin;

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _listenForPendingOrders();
  }

  @override
  void dispose() {
    _stopNotificationSoundAndVibration();
    _audioPlayer.dispose();
    super.dispose();
  }


  void _listenForPendingOrders() {
    _firestore
        .collection('orders')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) async {
      final newPendingCount = snapshot.docs.length;

      if (newPendingCount > _pendingOrdersCount && !_isNotificationActive) {
        if (await Vibration.hasVibrator() ?? false) {
          Vibration.vibrate(duration: 1000000, pattern: [0, 1000, 1000], repeat: 0);
        }
        await _audioPlayer.setReleaseMode(ReleaseMode.loop);
        await _audioPlayer.play(AssetSource('sounds/zapsplat_household_door_bell_ding_dong_impatient_x3.mp3'));
        _isNotificationActive = true;

        if (context.mounted) {
          _showNewOrderNotification(newPendingCount);
        }
      } else if (newPendingCount < _pendingOrdersCount || (newPendingCount == 0 && _isNotificationActive)) {
        _stopNotificationSoundAndVibration();
      }

      setState(() {
        _pendingOrdersCount = newPendingCount;
      });
    }, onError: (error) {
      print("Lỗi khi lắng nghe đơn hàng đang chờ xử lý: $error");
      _stopNotificationSoundAndVibration();
    });
  }

  void _stopNotificationSoundAndVibration() {
    if (_isNotificationActive) {
      _audioPlayer.stop();
      Vibration.cancel();
      _isNotificationActive = false;
      print("Âm thanh và rung thông báo đã dừng.");
    }
  }

  void _showNewOrderNotification(int count) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Thông báo đơn hàng mới!',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.deepOrange),
          ),
          content: Text(
            'Có $count đơn hàng mới đang chờ xử lý. Vui lòng kiểm tra ngay!',
            style: GoogleFonts.poppins(fontSize: 16),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Đóng',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
              onPressed: () {
                _stopNotificationSoundAndVibration();
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Xem ngay',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                _stopNotificationSoundAndVibration();
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const AdminOrdersScreen()),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
            (Route<dynamic> route) => false,
      );
    }
  }

  void _navigateToQrGenerator(BuildContext context) async {
    final selectedRestaurant = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AdminRestaurantSelectorScreen(),
      ),
    );

    if (selectedRestaurant != null && selectedRestaurant is Restaurant) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AdminQRCodeGeneratorScreen(
            restaurant: selectedRestaurant,
          ),
        ),
      );
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn một nhà hàng để tạo mã QR.'),
          backgroundColor: Colors.blueGrey,
        ),
      );
    }
  }

  Widget _buildDashboardCard(
      BuildContext context, {
        required IconData icon,
        required String label,
        required Color color,
        required VoidCallback onTap,
        Widget? trailing,
      }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildMainDashboardTab();
      case 1:
        return _buildRestaurantAndMenuTab();
      case 2:
        return _buildOrdersAndVouchersTab();
      case 3:
        return const AdminStatisticsScreen();
      default:
        return const Center(child: Text('Nội dung không xác định'));
    }
  }

  Widget _buildMainDashboardTab() {
    final List<Widget> cards = [
      _buildHighlightCard(
        title: 'Đơn hàng đang chờ',
        value: '$_pendingOrdersCount',
        icon: Icons.notifications_active,
        color: Colors.redAccent,
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AdminOrdersScreen()));
        },
      ),
      _buildDashboardCard(
        context,
        icon: Icons.person_pin,
        label: 'Quản lý Hồ sơ',
        color: Colors.indigoAccent,
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AdminProfileScreen()));
        },
      ),
    ];

    if (_currentUserRole == UserRole.superAdmin) {
      cards.add(
        _buildDashboardCard(
          context,
          icon: Icons.group_add,
          label: 'Quản lý Nhân viên',
          color: Colors.deepOrange,
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AdminStaffManagementScreen()));
          },
        ),
      );
    }

    cards.add(
      _buildDashboardCard(
        context,
        icon: Icons.local_shipping,
        label: 'Quản lý Shipper',
        color: Colors.blueGrey,
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AdminAddShipperScreen()));
        },
      ),
    );

    return ListView(
      padding: const EdgeInsets.only(top: 10, bottom: 80),
      children: cards,
    );
  }

  Widget _buildRestaurantAndMenuTab() {
    return ListView(
      padding: const EdgeInsets.only(top: 10, bottom: 80),
      children: [
        _buildDashboardCard(
          context,
          icon: Icons.list_alt,
          label: 'Danh sách Nhà hàng',
          color: Colors.pinkAccent,
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AdminRestaurantListScreen()));
          },
        ),
        _buildDashboardCard(
          context,
          icon: Icons.add_business,
          label: 'Thêm Nhà Hàng',
          color: Colors.teal,
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AdminRestaurantDetailScreen()));
          },
        ),
        _buildDashboardCard(
          context,
          icon: Icons.restaurant_menu,
          label: 'Quản lý Menu',
          color: const Color(0xFFFFA726),
          onTap: () async {
            final selectedRestaurant = await Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const AdminRestaurantSelectorScreen()),
            );
            if (selectedRestaurant != null && selectedRestaurant is Restaurant) {
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => AdminMenuScreen(restaurant: selectedRestaurant)));
            } else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn một nhà hàng để quản lý Menu.')));
            }
          },
        ),
        _buildDashboardCard(
          context,
          icon: Icons.category,
          label: 'Quản lý Danh mục',
          color: const Color(0xFFBA68C8),
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AdminCategoryScreen()));
          },
        ),
        _buildDashboardCard(
          context,
          icon: Icons.qr_code_scanner,
          label: 'Tạo QR Bàn',
          color: const Color(0xFFFFCC80),
          onTap: () => _navigateToQrGenerator(context),
        ),
      ],
    );
  }

  Widget _buildOrdersAndVouchersTab() {
    return ListView(
      padding: const EdgeInsets.only(top: 10, bottom: 80),
      children: [
        _buildDashboardCard(
          context,
          icon: Icons.receipt_long,
          label: 'Quản lý Đơn hàng',
          color: const Color(0xFF4FC3F7),
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AdminOrdersScreen()));
          },
        ),
        _buildDashboardCard(
          context,
          icon: Icons.confirmation_number,
          label: 'Quản lý Voucher',
          color: const Color(0xFFE57373),
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ManagerVoucherScreen()));
          },
        ),
        _buildDashboardCard(
          context,
          icon: Icons.reviews,
          label: 'Quản lý Đánh giá',
          color: const Color(0xFF4DB6AC),
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AdminReviewManagementScreen()));
          },
        ),
      ],
    );
  }


  Widget _buildHighlightCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20, top: 10, left: 16, right: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(fontSize: 16, color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
            Icon(icon, size: 40, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    String appBarTitle;
    switch (_selectedIndex) {
      case 0:
        appBarTitle = 'Tổng Quan & Quản Lý Chung';
        break;
      case 1:
        appBarTitle = 'Quản Lý Menu & Nhà Hàng';
        break;
      case 2:
        appBarTitle = 'Đơn Hàng & Khuyến Mãi';
        break;
      case 3:
        appBarTitle = 'Thống Kê Doanh Thu';
        break;
      default:
        appBarTitle = 'Quản Lý';
    }


    return Scaffold(
      appBar: AppBar(
        title: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Text(
            appBarTitle,
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
            maxLines: 1,
            softWrap: false,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.deepOrange,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications, color: Colors.white),
                onPressed: () {
                  _stopNotificationSoundAndVibration();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const AdminOrdersScreen()),
                  );
                },
                tooltip: 'Xem đơn hàng đang chờ xử lý',
              ),
              if (_pendingOrdersCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$_pendingOrdersCount',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => _logout(context),
            tooltip: 'Đăng xuất',
          ),
        ],
      ),
      body: _buildBody(),

      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.deepOrange,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Tổng quan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant),
            label: 'Menu/NH',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt),
            label: 'Đơn hàng',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Thống kê',
          ),
        ],
      ),
    );
  }
}