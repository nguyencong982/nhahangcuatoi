import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:menufood/shared/models.dart';
import 'package:menufood/shared/cart_provider.dart';
import 'package:menufood/orders/cart_screen.dart';
import 'package:menufood/orders/dine_in_cart_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:menufood/orders/order_tracking_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:menufood/qr_scanner_screen.dart';
import 'package:intl/intl.dart';

class MenuScreen extends StatefulWidget {
  final String? restaurantId;
  final String? tableNumber;

  const MenuScreen({
    super.key,
    this.restaurantId,
    this.tableNumber,
  });

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  Restaurant? _restaurant;
  List<Category> _categories = [];
  List<MenuItem> _menuItems = [];
  bool _isLoading = true;
  String? _errorMessage;

  String? _activeOrderId;
  StreamSubscription<QuerySnapshot>? _orderSubscription;
  StreamSubscription<QuerySnapshot>? _menuItemsSubscription;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _hasNotifiedOrderReady = false;
  bool _showOrderReadyBanner = false;

  final currencyFormatter = NumberFormat('#,##0', 'vi_VN');

  @override
  void initState() {
    super.initState();
    _fetchMenuData();
    _setupOrderListener();
    if (widget.restaurantId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Provider.of<CartProvider>(context, listen: false).setRestaurantForDelivery(widget.restaurantId!);
      });
    }
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    _menuItemsSubscription?.cancel();
    _stopNotificationSoundAndVibration();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _stopNotificationSoundAndVibration() {
    _audioPlayer.stop();
    Vibration.cancel();
  }

  Future<void> _playNewOrderNotification() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 1000000, pattern: [0, 1000, 1000], repeat: 0);
    }
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.play(AssetSource('sounds/zapsplat_household_door_bell_ding_dong_impatient_multiple_fast_presses.mp3'));
  }

  void _setupOrderListener() {
    _orderSubscription?.cancel();
    _orderSubscription = null;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _activeOrderId = null;
        _showOrderReadyBanner = false;
      });
      return;
    }
    if (widget.tableNumber == null || widget.tableNumber!.isEmpty) {
      setState(() {
        _activeOrderId = null;
        _showOrderReadyBanner = false;
      });
      return;
    }

    final q = FirebaseFirestore.instance.collection('orders')
        .where('userId', isEqualTo: user.uid)
        .where('tableNumber', isEqualTo: widget.tableNumber)
        .where('orderType', isEqualTo: 'dine_in')
        .where('status', whereIn: ['pending', 'preparing', 'ready'])
        .orderBy('timestamp', descending: true)
        .limit(1);

    _orderSubscription = q.snapshots().listen((snapshot) async {
      if (snapshot.docs.isNotEmpty) {
        final newOrder = AppOrder.fromFirestore(snapshot.docs.first);
        final newOrderId = newOrder.id;

        setState(() {
          _activeOrderId = newOrderId;
        });

        if (newOrder.status == 'ready' && !_hasNotifiedOrderReady) {
          await _playNewOrderNotification();
          setState(() {
            _hasNotifiedOrderReady = true;
            _showOrderReadyBanner = true;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Món của bạn đã sẵn sàng! Vui lòng kiểm tra đơn hàng.',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
                backgroundColor: Colors.purple,
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'Xem',
                  textColor: Colors.white,
                  onPressed: () {
                    if (_activeOrderId != null) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => OrderTrackingScreen(orderId: _activeOrderId!),
                        ),
                      );
                    }
                  },
                ),
              ),
            );
          }
        } else if (newOrder.status != 'ready' && _hasNotifiedOrderReady) {
          _stopNotificationSoundAndVibration();
          setState(() {
            _hasNotifiedOrderReady = false;
            _showOrderReadyBanner = false;
          });
        }
      } else {
        setState(() {
          _activeOrderId = null;
        });
        if (_hasNotifiedOrderReady) {
          _stopNotificationSoundAndVibration();
          _hasNotifiedOrderReady = false;
        }
      }
    }, onError: (error) {
      setState(() {
        _errorMessage = 'Lỗi lắng nghe đơn hàng: $error';
        _activeOrderId = null;
        _showOrderReadyBanner = false;
      });
      if (_hasNotifiedOrderReady) {
        _stopNotificationSoundAndVibration();
        _hasNotifiedOrderReady = false;
      }
    });
  }

  Future<void> _fetchMenuData() async {
    try {
      final restaurantId = widget.restaurantId;
      if (restaurantId == null || restaurantId.isEmpty) {
        setState(() {
          _errorMessage = 'Không có ID nhà hàng được cung cấp.';
          _isLoading = false;
        });
        return;
      }

      final restaurantDoc = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(restaurantId)
          .get();

      if (!restaurantDoc.exists) {
        setState(() {
          _errorMessage = 'Không tìm thấy nhà hàng này.';
          _isLoading = false;
        });
        return;
      }

      _restaurant = Restaurant.fromFirestore(restaurantDoc);

      final categoriesSnapshot = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(restaurantId)
          .collection('categories')
          .orderBy('order')
          .get();

      List<Category> fetchedCategories = [];
      for (var doc in categoriesSnapshot.docs) {
        final category = Category.fromFirestore(doc);
        if (category.isAvailableForDineIn) {
          fetchedCategories.add(category);
        }
      }
      _categories = fetchedCategories;

      _menuItemsSubscription?.cancel();

      _menuItemsSubscription = FirebaseFirestore.instance
          .collection('restaurants')
          .doc(restaurantId)
          .collection('menuItems')
          .snapshots()
          .listen((snapshot) {

        final updatedMenuItems = snapshot.docs
            .map((doc) => MenuItem.fromFirestore(doc))
            .toList();

        setState(() {
          _menuItems = updatedMenuItems;
          if (_isLoading) {
            _isLoading = false;
          }
        });

      }, onError: (e) {

        setState(() {
          _errorMessage = 'Lỗi lắng nghe menu: $e';
          _isLoading = false;
        });
        print('LỖI LẮNG NGHE MENU FIRESTORE: $e');
      });

      if (_isLoading && mounted) {
        setState(() {
          _isLoading = false;
        });
      }

    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi tải dữ liệu: $e';
        _isLoading = false;
      });
      print('LỖI TẢI MENU FIRESTORE: $e');
    }
  }

  List<MenuItem> _getItemsForCategory(String categoryId) {
    return _menuItems.where((item) => item.categoryId == categoryId).toList();
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: Text('Lỗi', style: GoogleFonts.poppins())),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.red, fontSize: 18),
            ),
          ),
        ),
      );
    }

    if (_restaurant == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Lỗi', style: GoogleFonts.poppins())),
        body: Center(
          child: Text(
            'Không tìm thấy thông tin nhà hàng.',
            style: GoogleFonts.poppins(color: Colors.red),
          ),
        ),
      );
    }

    if (_categories.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.deepOrange,
          elevation: 0,
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_restaurant!.name, style: GoogleFonts.poppins(color: Colors.white)),
                    if (widget.tableNumber != null && widget.tableNumber!.isNotEmpty)
                      Text('Bàn số: ${widget.tableNumber}', style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70))
                    else
                      Text('Đặt hàng giao tận nơi', style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70)),
                  ],
                ),
              ),
              if (_activeOrderId != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: IconButton(
                    icon: const Icon(Icons.receipt_long, color: Colors.white),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => OrderTrackingScreen(orderId: _activeOrderId!),
                        ),
                      );
                    },
                    tooltip: 'Theo dõi đơn hàng của bạn',
                  ),
                ),
            ],
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Text(
              'Menu/Danh mục chưa được thiết lập cho nhà hàng này, hoặc không có danh mục nào khả dụng cho ăn tại quán (Dine-In).',
              style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: _categories.length,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.deepOrange,
          elevation: 0,
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_restaurant!.name, style: GoogleFonts.poppins(color: Colors.white)),
                    if (widget.tableNumber != null && widget.tableNumber!.isNotEmpty)
                      Text('Bàn số: ${widget.tableNumber}', style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70))
                    else
                      Text('Đặt hàng giao tận nơi', style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70)),
                  ],
                ),
              ),
              if (_activeOrderId != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: IconButton(
                    icon: const Icon(Icons.receipt_long, color: Colors.white),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => OrderTrackingScreen(orderId: _activeOrderId!),
                        ),
                      );
                    },
                    tooltip: 'Theo dõi đơn hàng của bạn',
                  ),
                ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: Container(
              color: Colors.deepOrange,
              child: TabBar(
                isScrollable: true,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: _categories.map((c) {
                  return Tab(text: c.name);
                }).toList(),
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            Visibility(
              visible: _showOrderReadyBanner,
              child: Container(
                margin: const EdgeInsets.all(8.0),
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.purple, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Món của bạn đã sẵn sàng!',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple.shade800,
                            ),
                          ),
                          Text(
                            'Vui lòng lại quầy nhận món.',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.purple.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, color: Colors.purple),
                      onPressed: () {
                        if (_activeOrderId != null) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => OrderTrackingScreen(orderId: _activeOrderId!),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: _categories.map((category) {
                  final itemsForCategory = _getItemsForCategory(category.id);
                  if (itemsForCategory.isEmpty) {
                    return Center(
                      child: Text(
                        'Chưa có món ăn nào trong danh mục ${category.name}.',
                        style: GoogleFonts.poppins(color: Colors.grey[600]),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: itemsForCategory.length,
                    itemBuilder: (context, index) {
                      final item = itemsForCategory[index];

                      // 💡 LOGIC TÍNH GIÁ SAU GIẢM GIÁ ĐÃ THÊM VÀO
                      final int? discount = item.discountPercentage;
                      final double originalPrice = item.price;
                      final double finalPrice = discount != null && discount > 0
                          ? originalPrice * (1 - discount / 100)
                          : originalPrice;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        elevation: 4,
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
                                        placeholder: (context, url) => const CircularProgressIndicator(),
                                        errorWidget: (context, url, error) => const Icon(Icons.fastfood),
                                      ),
                                    ),
                                  // 💡 HIỂN THỊ NHÃN GIẢM GIÁ
                                  if (discount != null && discount > 0)
                                    Positioned(
                                      top: 0,
                                      left: 0,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
                                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    if (item.totalReviews > 0)
                                      Row(
                                        children: [
                                          const Icon(Icons.star, color: Colors.amber, size: 16),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${item.averageRating.toStringAsFixed(1)} (${item.totalReviews})',
                                            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700]),
                                          ),
                                        ],
                                      )
                                    else
                                      Text(
                                        'Chưa có đánh giá',
                                        style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
                                      ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.description ?? '',
                                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),

                                    // 💡 HIỂN THỊ GIÁ CŨ (NẾU CÓ GIẢM GIÁ)
                                    if (discount != null && discount > 0)
                                      Text(
                                        '${currencyFormatter.format(originalPrice)} VNĐ',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: Colors.grey,
                                          decoration: TextDecoration.lineThrough,
                                        ),
                                      ),
                                    // 💡 HIỂN THỊ GIÁ MỚI (SAU GIẢM GIÁ)
                                    Text(
                                      '${currencyFormatter.format(finalPrice)} VNĐ',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: discount != null && discount > 0 ? Colors.green.shade700 : Colors.deepOrange,
                                      ),
                                    ),

                                    if (!item.isAvailable)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Text(
                                          'Hết hàng',
                                          style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (item.isAvailable)
                                Selector<CartProvider, int>(
                                  selector: (_, cart) => cart.items[item.id]?.quantity ?? 0,
                                  builder: (_, quantity, __) {
                                    return Column(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.add_circle, color: Colors.green),
                                          onPressed: () {
                                            Provider.of<CartProvider>(context, listen: false).addItem(item);
                                          },
                                        ),
                                        Text('$quantity', style: GoogleFonts.poppins()),
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                                          onPressed: quantity > 0
                                              ? () {
                                            Provider.of<CartProvider>(context, listen: false)
                                                .updateItemQuantity(item.id, quantity - 1);
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
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Visibility(
              visible: _activeOrderId != null,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: FloatingActionButton.extended(
                  onPressed: () {
                    if (_activeOrderId != null) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => OrderTrackingScreen(orderId: _activeOrderId!),
                        ),
                      );
                    }
                  },
                  backgroundColor: Colors.blueGrey,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.track_changes),
                  label: Text('Theo dõi đơn hàng', style: GoogleFonts.poppins()),
                ),
              ),
            ),
            Consumer<CartProvider>(
              builder: (context, cart, child) {
                return cart.itemCount > 0
                    ? FloatingActionButton.extended(
                  onPressed: () {
                    if (widget.tableNumber != null && widget.tableNumber!.isNotEmpty) {

                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => DineInCartScreen(
                            restaurantId: widget.restaurantId!,
                            tableNumber: widget.tableNumber,
                          ),
                        ),
                      );
                    } else {

                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => CartScreen(
                            restaurantId: widget.restaurantId!,
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.shopping_cart),
                  label: Text(
                    'Xem Giỏ Hàng (${cart.itemCount} món - ${currencyFormatter.format(cart.totalAmount)} VNĐ)',
                    style: GoogleFonts.poppins(),
                  ),
                )
                    : Container();
              },
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }
}