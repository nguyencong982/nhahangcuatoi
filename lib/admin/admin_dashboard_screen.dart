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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Quản lý',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
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
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: 'Đăng xuất',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16.0,
          mainAxisSpacing: 16.0,
          childAspectRatio: 1.2,
          children: [
            _buildDashboardCard(
              context,
              icon: Icons.restaurant_menu,
              label: 'Quản lý Menu',
              color: const Color(0xFFFFA726),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AdminMenuScreen()));
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
              icon: Icons.analytics,
              label: 'Xem Thống kê',
              color: const Color(0xFF81C784),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AdminStatisticsScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard(
      BuildContext context, {
        required IconData icon,
        required String label,
        required Color color,
        required VoidCallback onTap,
      }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(2, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: Colors.black87),
            const SizedBox(height: 12),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
