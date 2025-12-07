import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:menufood/welcome/welcomescreen.dart';
import 'category_dishes_screen.dart';
import 'package:menufood/shared/models.dart';
import 'package:menufood/orders/cart_screen.dart';
import 'package:menufood/orders/past_orders_screen.dart';
import 'package:marquee/marquee.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:menufood/orders/order_tracking_screen.dart';
import 'voucher_screen.dart';
import 'package:intl/intl.dart';
import 'package:menufood/home/nearby_screen.dart';
import 'package:provider/provider.dart';
import 'package:menufood/shared/cart_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:menufood/home/customer_favorites_screen.dart';
import 'package:menufood/home/hot_deals_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

const Color commonBackgroundColor = Color(0xFFFCF6E0);
const Color primaryOrangeColor = Color(0xFFF96E21);

const double _MAX_DELIVERY_DISTANCE_METERS = 70000.0;

class CustomerHomeScreen extends StatefulWidget {
  final Restaurant initialRestaurant;
  const CustomerHomeScreen({super.key, required this.initialRestaurant});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  StreamSubscription? _customerOrderReadySubscription;
  Set<String> _notifiedOrderIds = {};

  List<Category> _categories = [];
  StreamSubscription? _categorySubscription;
  bool _isLoading = true;

  late Restaurant _currentRestaurant;
  late String _currentRestaurantId;

  String _currentTime = '';
  Timer? _timer;

  final currencyFormatter = NumberFormat('#,##0', 'vi_VN');
  Stream<List<MenuItem>> getHotDealsStream() {
    if (_currentRestaurantId.isEmpty) return const Stream.empty();

    return _firestore
        .collection('restaurants')
        .doc(_currentRestaurantId)
        .collection('menuItems')
        .where('isAvailable', isEqualTo: true)
        .where('discountPercentage', isGreaterThanOrEqualTo: 50)
        .limit(10)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => MenuItem.fromFirestore(doc))
              .toList();
        });
  }

  Future<Restaurant?> _findNearestRestaurant() async {
    Position? currentPosition;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Dịch vụ định vị bị tắt. Không thể tự động chọn quán.',
              ),
            ),
          );
        }
        return null;
      }

      // 2. Kiểm tra và yêu cầu quyền
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Quyền truy cập vị trí bị từ chối. Không thể tự động chọn quán.',
                ),
              ),
            );
          }
          return null;
        }
      }

      try {
        currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 5),
        );
      } catch (e) {
        debugPrint('Lỗi getCurrentPosition, chuyển sang LastKnownPosition: $e');
        currentPosition = await Geolocator.getLastKnownPosition();
      }
    } catch (e) {
      debugPrint('Lỗi lấy vị trí tổng quát: $e');
      return null;
    }

    if (currentPosition == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể xác định vị trí hiện tại. Vui lòng chọn quán thủ công.'),
          ),
        );
      }
      return null;
    }

    final allRestaurantsSnapshot =
    await _firestore.collection('restaurants').get();
    Restaurant? nearestRestaurant;
    double minDistance = double.infinity;

    for (var doc in allRestaurantsSnapshot.docs) {
      final restaurant = Restaurant.fromFirestore(doc);
      final data = doc.data();
      final GeoPoint? location =
      data.containsKey('location') ? data['location'] : null;
      final LatLng? position =
      location != null
          ? LatLng(location.latitude, location.longitude)
          : null;

      if (position != null) {
        final double distanceInMeters = Geolocator.distanceBetween(
          currentPosition.latitude,
          currentPosition.longitude,
          position.latitude,
          position.longitude,
        );

        if (distanceInMeters < minDistance &&
            distanceInMeters <= _MAX_DELIVERY_DISTANCE_METERS) {
          minDistance = distanceInMeters;
          nearestRestaurant = restaurant;
        }
      }
    }
    return nearestRestaurant;
  }

  void _changeRestaurant(Restaurant newRestaurant) {
    if (mounted) {
      setState(() {
        _currentRestaurant = newRestaurant;
        _currentRestaurantId = newRestaurant.id;
        _isLoading = true;
      });
      Provider.of<CartProvider>(context, listen: false).clearCart();
      Provider.of<CartProvider>(
        context,
        listen: false,
      ).setRestaurantForDelivery(newRestaurant.id);
      _fetchCategoriesFromFirestore(newRestaurant.id);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã chọn quán: ${newRestaurant.name}')),
      );
    }
  }

  Future<void> _autoSelectNearestRestaurant() async {
    _currentRestaurant = widget.initialRestaurant;
    _currentRestaurantId = widget.initialRestaurant.id;

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    final nearestRestaurant = await _findNearestRestaurant();

    if (nearestRestaurant != null &&
        nearestRestaurant.id != _currentRestaurantId) {
      _changeRestaurant(nearestRestaurant);
    } else {
      Provider.of<CartProvider>(
        context,
        listen: false,
      ).setRestaurantForDelivery(_currentRestaurantId);
      _fetchCategoriesFromFirestore(_currentRestaurantId);

      if (nearestRestaurant == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không tìm thấy quán gần bạn. Đang sử dụng quán mặc định: ${_currentRestaurant.name ?? 'Đang tải...'}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeLocalNotifications();
    _setupCustomerOrderReadyListener();

    _autoSelectNearestRestaurant();

    _updateTime();
    _timer = Timer.periodic(
      const Duration(seconds: 60),
      (Timer t) => _updateTime(),
    );
  }

  void _handleHotDealsTap() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => HotDealsScreen(
              restaurantId: _currentRestaurantId,
              restaurantName: _currentRestaurant.name ?? 'Quán',
            ),
      ),
    );
  }

  void _fetchCategoriesFromFirestore(String restaurantId) {
    _categorySubscription?.cancel();

    _categorySubscription = FirebaseFirestore.instance
        .collection('restaurants')
        .doc(restaurantId)
        .collection('categories')
        .where('isAvailableForDelivery', isEqualTo: true)
        .orderBy('order')
        .snapshots()
        .listen(
          (snapshot) {
            if (mounted) {
              setState(() {
                _categories =
                    snapshot.docs
                        .map((doc) => Category.fromFirestore(doc))
                        .toList();
                _isLoading = false;
              });
            }
          },
          onError: (error) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Lỗi tải danh mục: ${error.toString()}'),
                  ),
                );
              });
            }
          },
        );
  }

  Future<void> _handleManualRestaurantSelection() async {
    final selectedRestaurant = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const NearbyScreen()));

    if (selectedRestaurant != null &&
        selectedRestaurant is Restaurant &&
        mounted) {
      if (selectedRestaurant.id != _currentRestaurantId) {
        _changeRestaurant(selectedRestaurant);
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    }
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

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (
        NotificationResponse notificationResponse,
      ) async {
        if (notificationResponse.payload != null) {
          debugPrint('notification payload: ${notificationResponse.payload}');
          if (context.mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder:
                    (context) => OrderTrackingScreen(
                      orderId: notificationResponse.payload!,
                    ),
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

    final q =
        FirebaseFirestore.instance
            .collection('orders')
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
    }, onError: (error) {});
  }

  void _showLocalNotification(String orderId) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'order_ready_channel',
          'Thông báo đơn hàng sẵn sàng',
          channelDescription:
              'Thông báo khi đơn hàng của bạn đã sẵn sàng để lấy.',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: false,
          playSound: true,
          enableVibration: true,
        );
    const DarwinNotificationDetails
    iOSPlatformChannelSpecifics = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound:
          'zapsplat_household_door_bell_ding_dong_impatient_multiple_fast_presses.mp3',
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

  void _updateTime() {
    final now = DateTime.now();
    final formatter = DateFormat('HH : mm');
    setState(() {
      _currentTime = formatter.format(now);
    });
  }

  @override
  void dispose() {
    _customerOrderReadySubscription?.cancel();
    _categorySubscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  Future<bool> _isUserManager() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final doc =
        await FirebaseFirestore.instance
            .collection('restaurants')
            .doc(_currentRestaurantId)
            .get();

    return doc.exists && doc.data()?['managerId'] == user.uid;
  }

  Widget _buildMenuItemTile(BuildContext context, MenuItem item) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final double avgRating = item.averageRating ?? 0.0;
    final int totalReviews = item.totalReviews ?? 0;

    final int? discount = item.discountPercentage;
    final double originalPrice = item.price;
    final double finalPrice =
        discount != null && discount > 0
            ? originalPrice * (1 - discount / 100)
            : originalPrice;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                if ((item.imageUrl).isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: CachedNetworkImage(
                      imageUrl: item.imageUrl,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      placeholder:
                          (context, url) => const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      errorWidget:
                          (context, url, error) => const Icon(
                            Icons.fastfood,
                            size: 40,
                            color: Colors.grey,
                          ),
                    ),
                  ),
                if (discount != null && discount > 0)
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade700,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8.0),
                          bottomRight: Radius.circular(8.0),
                        ),
                      ),
                      child: Text(
                        '-$discount%',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (totalReviews > 0)
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          avgRating.toStringAsFixed(1),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          ' ($totalReviews)',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      'Chưa có đánh giá',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),

                  const SizedBox(height: 4),
                  Text(
                    item.description ?? '',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  if (discount != null && discount > 0)
                    Text(
                      '${currencyFormatter.format(originalPrice)} VNĐ',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  Text(
                    '${currencyFormatter.format(finalPrice)} VNĐ',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color:
                          discount != null && discount > 0
                              ? Colors.green.shade700
                              : primaryOrangeColor,
                    ),
                  ),
                ],
              ),
            ),
            Selector<CartProvider, int>(
              selector: (_, cart) => cart.items[item.id]?.quantity ?? 0,
              builder: (_, quantity, __) {
                return Column(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.add_circle,
                        color: primaryOrangeColor,
                      ),
                      onPressed: () {
                        cartProvider.addItem(item);
                      },
                    ),
                    Text(
                      '$quantity',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.remove_circle,
                        color: quantity > 0 ? Colors.grey : Colors.grey[300],
                      ),
                      onPressed:
                          quantity > 0
                              ? () {
                                cartProvider.updateItemQuantity(
                                  item.id,
                                  quantity - 1,
                                );
                              }
                              : null,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllDishesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          'Tất cả Món ăn của Quán (Xếp hạng)',
          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),
        StreamBuilder<QuerySnapshot>(
          stream:
              _firestore
                  .collection('restaurants')
                  .doc(_currentRestaurantId)
                  .collection('menuItems')
                  .where('isAvailable', isEqualTo: true)
                  .orderBy('averageRating', descending: true)
                  .orderBy('order')
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: primaryOrangeColor),
              );
            }
            if (snapshot.hasError) {
              return Center(child: Text('Lỗi tải món ăn: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Text(
                  'Quán ${_currentRestaurant.name ?? 'này'} chưa có món ăn khả dụng.',
                  style: GoogleFonts.poppins(color: Colors.grey[600]),
                ),
              );
            }

            final menuItems =
                snapshot.data!.docs
                    .map((doc) => MenuItem.fromFirestore(doc))
                    .toList();

            return ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                return _buildMenuItemTile(context, menuItems[index]);
              },
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    final String userEmail = currentUser?.email ?? 'Khách hàng';
    final String welcomeText = 'Chào mừng, ${userEmail.split('@')[0]}!';

    final List<Map<String, dynamic>> promoCards = [
      {
        'title': 'Quán gần tôi',
        'subtitle': 'Đổi quán',
        'image': 'assets/images/vector-ngoi-nha-4-e1713323512902.jpg',
        'color': Colors.pink[100],
        'onTap': _handleManualRestaurantSelection,
      },
      {
        'title': 'Deal Giảm Giá Nóng',
        'subtitle': 'Giảm đậm đến 50%',
        'image': 'assets/images/pngtree-hot-deal-png-image_3732894.jpg',
        'color': Colors.lightGreen[100],
        'onTap': _handleHotDealsTap,
      },
    ];

    return FutureBuilder<bool>(
      future: _isUserManager(),
      builder: (context, snapshot) {
        final bool isManager = snapshot.data ?? false;

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
              if (isManager)
                IconButton(
                  icon: const Icon(Icons.settings, color: primaryOrangeColor),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Màn hình Quản lý Trang chủ đã bị vô hiệu hóa.',
                        ),
                      ),
                    );
                  },
                  tooltip: 'Quản lý Trang Chủ',
                ),

              IconButton(
                icon: const Icon(Icons.favorite_border, color: Colors.black),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const CustomerFavoritesScreen(),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.receipt_long, color: Colors.black),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const PastOrdersScreen(),
                    ),
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
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Image.asset(
                        'assets/images/1người.png',
                        width: 60,
                        height: 60,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.card_giftcard,
                            color: Colors.white,
                            size: 60,
                          );
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
                        icon: const Icon(
                          Icons.delivery_dining,
                          color: Colors.black,
                        ),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Giao hàng',
                            style: GoogleFonts.poppins(color: Colors.black),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
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
                            MaterialPageRoute(
                              builder:
                                  (context) => const VoucherScreen(
                                    orderType: 'delivery',
                                  ),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.local_attraction,
                          color: Colors.grey,
                        ),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Voucher Của Quán',
                            style: GoogleFonts.poppins(color: Colors.grey),
                          ),
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
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: primaryOrangeColor,
                      ),
                    )
                    : _categories.isEmpty
                    ? Center(
                      child: Text(
                        'Chưa có danh mục món ăn nào từ ${_currentRestaurant.name ?? 'quán này'}',
                      ),
                    )
                    : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quán đang đặt: ${_currentRestaurant.name ?? 'Đang tải...'}',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey,
                          ),
                        ),
                        const SizedBox(height: 10),

                        SizedBox(
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
                                      builder:
                                          (context) => CategoryDishesScreen(
                                            category: category,
                                            restaurantId: _currentRestaurantId,
                                          ),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.grey[200],
                                          image:
                                              category.imageUrl.isNotEmpty
                                                  ? DecorationImage(
                                                    image: NetworkImage(
                                                      category.imageUrl,
                                                    ),
                                                    fit: BoxFit.cover,
                                                  )
                                                  : null,
                                        ),
                                        child:
                                            category.imageUrl.isEmpty
                                                ? const Icon(
                                                  Icons.fastfood,
                                                  color: Colors.grey,
                                                  size: 40,
                                                )
                                                : null,
                                      ),
                                      const SizedBox(height: 5),
                                      SizedBox(
                                        width: 80,
                                        child: Text(
                                          category.name,
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.black87,
                                          ),
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
                      ],
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
                    return GestureDetector(
                      onTap: () async {
                        if (card['title'] == 'Quán gần tôi') {
                          await _handleManualRestaurantSelection();
                        } else if (card['title'] == 'Deal Giảm Giá Nóng') {
                          (card['onTap'] as VoidCallback).call();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${card['title']} đang được phát triển.',
                              ),
                            ),
                          );
                        }
                      },
                      child: Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side:
                              card['title'] == 'Deal Giảm Giá Nóng'
                                  ? BorderSide(
                                    color: Colors.green.shade700,
                                    width: 2,
                                  )
                                  : BorderSide.none,
                        ),
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
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
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
                                    return const Icon(
                                      Icons.local_offer,
                                      size: 40,
                                      color: Colors.grey,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

                if (!_isLoading && _currentRestaurantId.isNotEmpty)
                  _buildAllDishesList(),

                const SizedBox(height: 80),
              ],
            ),
          ),
          floatingActionButton: Consumer<CartProvider>(
            builder: (context, cart, child) {
              return FloatingActionButton(
                onPressed: () {
                  if (_currentRestaurantId.isNotEmpty) {
                    if (context.mounted) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (context) => CartScreen(
                                restaurantId: _currentRestaurantId,
                                tableNumber: 'Delivery',
                              ),
                        ),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Không có nhà hàng nào được chọn.'),
                      ),
                    );
                  }
                },
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Badge(
                  label: Text(
                    cart.itemCount.toString(),
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                  isLabelVisible: cart.itemCount > 0,
                  alignment: Alignment.topRight,
                  backgroundColor: Colors.black,
                  textColor: Colors.white,
                  child: const Icon(Icons.shopping_bag_outlined, size: 30),
                ),
              );
            },
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
                        _currentTime,
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
      },
    );
  }
}
