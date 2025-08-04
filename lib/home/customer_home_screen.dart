import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:menufood/welcome/welcomescreen.dart';
import 'category_dishes_screen.dart';
import 'package:menufood/shared/models.dart';
import 'package:menufood/orders/cart_screen.dart';
import 'package:menufood/home/voucher_screen.dart';
import 'package:menufood/orders/past_orders_screen.dart';
import 'package:marquee/marquee.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:menufood/orders/order_tracking_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final String _defaultDeliveryRestaurantId = 'my_restaurant_id';
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  StreamSubscription? _customerOrderReadySubscription;
  Set<String> _notifiedOrderIds = {};

  List<Category> _categories = [];
  StreamSubscription? _categorySubscription;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeLocalNotifications();
    _setupCustomerOrderReadyListener();
    _fetchCategoriesFromFirestore();
  }

  void _fetchCategoriesFromFirestore() {
    _categorySubscription = FirebaseFirestore.instance.collection('categories')
        .where('isAvailableForDelivery', isEqualTo: true)
        .orderBy('order')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _categories = snapshot.docs.map((doc) => Category.fromFirestore(doc)).toList();
          _isLoading = false;
        });
      }
    }, onError: (error) {
      print("Lỗi khi lấy danh mục từ Firestore: $error");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  void _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse notificationResponse) async {
        if (notificationResponse.payload != null) {
          debugPrint('notification payload: ${notificationResponse.payload}');
          if (context.mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => OrderTrackingScreen(orderId: notificationResponse.payload!),
              ),
            );
          }
        }
      },
    );
  }

  void _setupCustomerOrderReadyListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _customerOrderReadySubscription?.cancel();
      return;
    }

    final q = FirebaseFirestore.instance.collection('orders')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'ready')
        .snapshots();

    _customerOrderReadySubscription = q.listen((snapshot) {
      for (var doc in snapshot.docs) {
        final orderId = doc.id;
        if (!_notifiedOrderIds.contains(orderId)) {
          _showLocalNotification(orderId);
          _notifiedOrderIds.add(orderId);
        }
      }
    }, onError: (error) {
      print("Lỗi khi lắng nghe đơn hàng sẵn sàng: $error");
    });
  }

  void _showLocalNotification(String orderId) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'order_ready_channel',
      'Thông báo đơn hàng sẵn sàng',
      channelDescription: 'Thông báo khi đơn hàng của bạn đã sẵn sàng để lấy.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
      playSound: true,
      enableVibration: true,
    );
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
    DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'zapsplat_household_door_bell_ding_dong_impatient_multiple_fast_presses.mp3',
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      'Đơn hàng của bạn đã sẵn sàng!',
      'Đơn hàng #${orderId.substring(0, 8)} đã sẵn sàng để lấy. Vui lòng lại quầy nhận.',
      platformChannelSpecifics,
      payload: orderId,
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
  void dispose() {
    _customerOrderReadySubscription?.cancel();
    _categorySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color commonBackgroundColor = Color(0xFFFCF6E0);
    const Color primaryOrangeColor = Color(0xFFF96E21);

    final User? currentUser = FirebaseAuth.instance.currentUser;
    final String userEmail = currentUser?.email ?? 'Khách hàng';
    final String welcomeText = 'Chào mừng, ${userEmail.split('@')[0]}!';

    final List<Map<String, dynamic>> promoCards = [
      {
        'title': 'Gần tôi',
        'subtitle': 'Nhận ngay',
        'image': 'assets/images/vector-ngoi-nha-4-e1713323512902.jpg',
        'color': Colors.pink[100],
      },
      {
        'title': 'Deal Giảm Giá Nóng',
        'subtitle': 'Giảm đậm đến 50%',
        'image': 'assets/images/pngtree-hot-deal-png-image_3732894.jpg',
        'color': Colors.lightGreen[100],
      },
      {
        'title': 'Bữa Sáng Trưa Nè',
        'subtitle': 'Quảng cáo - Ăn no nê chỉ 0Đ',
        'image': 'assets/images/1người.png',
        'color': Colors.orange[100],
      },
      {
        'title': 'Một Người Ăn',
        'subtitle': 'Bao trọn gói',
        'image': 'assets/images/1.jpg',
        'color': Colors.yellow[100],
      },
    ];

    return Scaffold(
      backgroundColor: commonBackgroundColor,
      appBar: AppBar(
        backgroundColor: commonBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: SizedBox(
          height: kToolbarHeight,
          child: Marquee(
            text: welcomeText,
            style: GoogleFonts.poppins(
              color: Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            blankSpace: 20.0,
            velocity: 30.0,
            pauseAfterRound: const Duration(seconds: 1),
            startPadding: 0.0,
            accelerationDuration: const Duration(seconds: 1),
            accelerationCurve: Curves.easeOut,
            decelerationDuration: const Duration(milliseconds: 500),
            decelerationCurve: Curves.easeIn,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border, color: Colors.black),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Yêu thích')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long, color: Colors.black),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const PastOrdersScreen()),
              );
            },
            tooltip: 'Đơn hàng của bạn',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black),
            onPressed: () => _logout(context),
            tooltip: 'Đăng xuất',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            TextField(
              decoration: InputDecoration(
                hintText: 'Bạn đang tìm thêm gì nào?',
                hintStyle: GoogleFonts.poppins(color: Colors.grey[500]),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryOrangeColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Phí ship mới 12K',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Thêm deal giảm đến 50% mỗi ngày',
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Image.asset(
                    'assets/images/1người.png',
                    width: 60,
                    height: 60,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.card_giftcard, color: Colors.white, size: 60);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Chế độ Giao hàng')),
                      );
                    },
                    icon: const Icon(Icons.delivery_dining, color: Colors.black),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Giao hàng', style: GoogleFonts.poppins(color: Colors.black)),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const VoucherScreen()),
                      );
                    },
                    icon: const Icon(Icons.local_attraction, color: Colors.grey),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Voucher Của Quán', style: GoogleFonts.poppins(color: Colors.grey)),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Text(
              'Danh mục món ăn',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),

            _isLoading
                ? const Center(child: CircularProgressIndicator(color: primaryOrangeColor,))
                : _categories.isEmpty
                ? const Center(child: Text('Chưa có danh mục món ăn nào.'))
                : SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CategoryDishesScreen(
                            category: category,
                            restaurantId: _defaultDeliveryRestaurantId,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey[200],
                              image: DecorationImage(
                                image: NetworkImage(category.imageUrl),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          SizedBox(
                            width: 80,
                            child: Text(
                              category.name,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.black87),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Ưu đãi dành cho bạn',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10.0,
                mainAxisSpacing: 10.0,
                childAspectRatio: 1.0,
              ),
              itemCount: promoCards.length,
              itemBuilder: (context, index) {
                final card = promoCards[index];
                return Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  color: card['color'],
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                card['title'],
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                              ),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                card['subtitle'],
                                style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
                                maxLines: 2,
                              ),
                            ),
                          ],
                        ),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Image.asset(
                            card['image'],
                            width: 60,
                            height: 60,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.local_offer, size: 40, color: Colors.grey);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mở giỏ hàng')),
          );
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => CartScreen(
                restaurantId: _defaultDeliveryRestaurantId,
                tableNumber: 'Delivery',
              ),
            ),
          );
        },
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: const Icon(Icons.shopping_bag_outlined, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: Container(
        height: 60,
        color: primaryOrangeColor,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Row(
              children: [
                const Icon(Icons.timer, color: Colors.white, size: 18),
                const SizedBox(width: 5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '14 : 47',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
