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

class MenuScreen extends StatefulWidget {
  final String restaurantId;
  final String? tableNumber;

  const MenuScreen({
    super.key,
    required this.restaurantId,
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
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _hasNotifiedOrderReady = false;
  bool _showOrderReadyBanner = false;

  @override
  void initState() {
    super.initState();
    print('MenuScreen initState: restaurantId=${widget.restaurantId}, tableNumber=${widget.tableNumber}');
    _fetchMenuData();
    _setupOrderListener();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CartProvider>(context, listen: false).setRestaurantAndTable(
        widget.restaurantId,
        widget.tableNumber,
      );
    });
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    _stopNotificationSoundAndVibration();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _stopNotificationSoundAndVibration() {
    _audioPlayer.stop();
    Vibration.cancel();
    print("New order notification sound and vibration stopped.");
  }

  Future<void> _playNewOrderNotification() async {
    print("Playing new order notification...");
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 1000000, pattern: [0, 1000, 1000], repeat: 0);
    }
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.play(AssetSource('sounds/zapsplat_household_door_bell_ding_dong_impatient_multiple_fast_presses.mp3'));
  }

  void _setupOrderListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("Order Listener: User is null.");
      setState(() {
        _activeOrderId = null;
        _showOrderReadyBanner = false;
      });
      return;
    }
    if (widget.tableNumber == null || widget.tableNumber!.isEmpty) {
      print("Order Listener: tableNumber is null or empty. Cannot track dine-in order.");
      setState(() {
        _activeOrderId = null;
        _showOrderReadyBanner = false;
      });
      return;
    }

    print("Order Listener: Listening for user ${user.uid} at table ${widget.tableNumber}");

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
          print("Active Dine-in Order Found: $_activeOrderId");
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
          print("No Active Dine-in Order Found.");
        });
        if (_hasNotifiedOrderReady) {
          _stopNotificationSoundAndVibration();
          setState(() {
            _hasNotifiedOrderReady = false;
            _showOrderReadyBanner = false;
          });
        }
      }
    }, onError: (error) {
      print("Lỗi lắng nghe đơn hàng đang hoạt động: $error");
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
      final restaurantDoc = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId)
          .get();

      if (!restaurantDoc.exists) {
        setState(() {
          _errorMessage = 'Không tìm thấy nhà hàng này.';
          _isLoading = false;
        });
        print("Restaurant not found: ${widget.restaurantId}");
        return;
      }

      _restaurant = Restaurant.fromFirestore(restaurantDoc);
      print("Restaurant loaded: ${_restaurant!.name}");

      final categoriesSnapshot = await FirebaseFirestore.instance
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
      print("Fetched Categories for Dine-in: ${_categories.map((c) => c.name).join(', ')}");

      final menuItemsSnapshot = await FirebaseFirestore.instance
          .collection('menuItems')
          .get();

      _menuItems = menuItemsSnapshot.docs
          .map((doc) => MenuItem.fromFirestore(doc))
          .toList();
      print("Fetched Menu Items count: ${_menuItems.length}");

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi tải menu: $e';
        _isLoading = false;
      });
      print("Error fetching menu data: $e");
    }
  }

  List<MenuItem> _getItemsForCategory(String categoryId) {
    final items = _menuItems.where((item) => item.categoryId == categoryId).toList();
    print("Items for category $categoryId: ${items.length} items");
    return items;
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

    print("Building MenuScreen. Categories count: ${_categories.length}");

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
          child: Text(
            'Không có danh mục món ăn nào khả dụng cho ăn tại quán. Vui lòng kiểm tra cài đặt danh mục trong Admin Dashboard.',
            style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey[700]),
            textAlign: TextAlign.center,
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
                  print("Building Tab for category: ${c.name}");
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
                    Icon(Icons.check_circle, color: Colors.purple, size: 28),
                    SizedBox(width: 10),
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
                      icon: Icon(Icons.arrow_forward_ios, color: Colors.purple),
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
                  print("Building TabBarView content for category: ${category.name}");
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
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                    Text(
                                      item.description ?? '',
                                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${item.price.toStringAsFixed(0)} VNĐ',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepOrange,
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
                            restaurantId: widget.restaurantId,
                            tableNumber: widget.tableNumber,
                          ),
                        ),
                      );
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => CartScreen(
                            restaurantId: widget.restaurantId,
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.shopping_cart),
                  label: Text(
                    'Xem Giỏ Hàng (${cart.itemCount} món - ${cart.totalAmount.toStringAsFixed(0)} VNĐ)',
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
