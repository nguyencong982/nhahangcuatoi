import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:menufood/shared/models.dart';

class CartProvider with ChangeNotifier {
  final Map<String, CartItem> _items = {};
  String? _currentRestaurantId;
  String? _currentTableNumber;

  String? _selectedDeliveryOption;
  String? _deliveryAddress;
  double _deliveryFee = 0.0;
  String _paymentMethod = 'cash';
  Voucher? _appliedVoucher;
  String? _customerNotes;

  Map<String, CartItem> get items => _items;
  String? get currentRestaurantId => _currentRestaurantId;
  String? get currentTableNumber => _currentTableNumber;
  String? get selectedDeliveryOption => _selectedDeliveryOption;
  double get deliveryFee => _deliveryFee;
  String? get deliveryAddress => _deliveryAddress;
  String get paymentMethod => _paymentMethod;
  Voucher? get appliedVoucher => _appliedVoucher;
  String? get customerNotes => _customerNotes;

  double get subtotalAmount {
    double total = 0.0;
    _items.forEach((key, cartItem) {
      total += cartItem.subtotal;
    });
    return total;
  }

  double get discountAmount {
    if (_appliedVoucher == null) return 0.0;

    if (_appliedVoucher!.isForShipping) {
      return _deliveryFee;
    }

    double calculatedDiscount = 0.0;
    if (_appliedVoucher!.discountType == 'fixed') {
      calculatedDiscount = _appliedVoucher!.discountAmount;
    } else if (_appliedVoucher!.discountType == 'percentage') {
      calculatedDiscount = subtotalAmount * (_appliedVoucher!.discountAmount / 100);
    }
    if (_appliedVoucher!.maxDiscountAmount != null && calculatedDiscount > _appliedVoucher!.maxDiscountAmount!) {
      return _appliedVoucher!.maxDiscountAmount!;
    }

    return calculatedDiscount;
  }

  double get totalAmount {
    double finalDeliveryFee = (_appliedVoucher != null && _appliedVoucher!.isForShipping) ? 0.0 : _deliveryFee;
    return subtotalAmount + finalDeliveryFee - discountAmount;
  }

  int get itemCount {
    return _items.length;
  }

  void setRestaurant(String restaurantId) {
    if (_currentRestaurantId != restaurantId) {
      _currentRestaurantId = restaurantId;
      _items.clear();
      _currentTableNumber = null;
      notifyListeners();
    }
  }

  void setRestaurantAndTable(String restaurantId, String? tableNumber) {
    if (_currentRestaurantId != restaurantId || _currentTableNumber != tableNumber) {
      _currentRestaurantId = restaurantId;
      _currentTableNumber = tableNumber;
      clearCart();
    }
  }

  void setDeliveryOption(String? option, double fee) {
    _selectedDeliveryOption = option;
    _deliveryFee = fee;
    _checkAndRemoveVoucher();
    notifyListeners();
  }

  void setDeliveryAddress(String? address) {
    _deliveryAddress = address;
    notifyListeners();
  }

  void setPaymentMethod(String method) {
    _paymentMethod = method;
    notifyListeners();
  }

  void setCustomerNotes(String? notes) {
    _customerNotes = notes;
    notifyListeners();
  }

  bool checkVoucherValidity(Voucher voucher) {
    final now = Timestamp.now();
    final subtotal = subtotalAmount;
    final orderType = _currentTableNumber != null ? 'dine_in' : 'delivery';

    if (now.compareTo(voucher.startDate) < 0 || now.compareTo(voucher.endDate) > 0) {
      print('DEBUG: Voucher không hợp lệ: Hết hạn hoặc chưa đến ngày sử dụng. Now: $now, Start: ${voucher.startDate}, End: ${voucher.endDate}');
      return false;
    }

    if (voucher.minOrderAmount != null && subtotal < voucher.minOrderAmount!) {
      print('DEBUG: Voucher không hợp lệ: Tổng tiền chưa đạt mức tối thiểu. Cần: ${voucher.minOrderAmount}, hiện tại: $subtotal');
      return false;
    }

    if (voucher.isForShipping && orderType != 'delivery') {
      print('DEBUG: Voucher không hợp lệ: Voucher phí ship nhưng là đơn ăn tại quán.');
      return false;
    }

    if (voucher.type != 'all' && voucher.type != orderType) {
      print('DEBUG: Voucher không hợp lệ: Loại đơn hàng không phù hợp. Cần: ${voucher.type}, hiện tại: $orderType');
      return false;
    }

    print('DEBUG: Voucher hợp lệ.');
    return true;
  }

  bool applyVoucher(Voucher voucher) {
    if (checkVoucherValidity(voucher)) {
      _appliedVoucher = voucher;
      notifyListeners();
      return true;
    }
    return false;
  }

  void removeVoucher() {
    _appliedVoucher = null;
    notifyListeners();
  }

  void _checkAndRemoveVoucher() {
    if (_appliedVoucher != null && !checkVoucherValidity(_appliedVoucher!)) {
      removeVoucher();
    }
  }

  void addItem(MenuItem item) {
    if (_items.containsKey(item.id)) {
      _items.update(
        item.id,
            (existingItem) => CartItem(
          item: existingItem.item,
          quantity: existingItem.quantity + 1,
          notes: existingItem.notes,
        ),
      );
    } else {
      _items.putIfAbsent(
        item.id,
            () => CartItem(item: item),
      );
    }
    _checkAndRemoveVoucher();
    notifyListeners();
  }

  void removeItem(String productId) {
    _items.remove(productId);
    _checkAndRemoveVoucher();
    notifyListeners();
  }

  void removeSingleItem(String productId) {
    if (!_items.containsKey(productId)) {
      return;
    }
    if (_items[productId]!.quantity > 1) {
      _items.update(
        productId,
            (existingItem) => CartItem(
          item: existingItem.item,
          quantity: existingItem.quantity - 1,
          notes: existingItem.notes,
        ),
      );
    } else {
      _items.remove(productId);
    }
    _checkAndRemoveVoucher();
    notifyListeners();
  }

  void updateItemQuantity(String productId, int newQuantity) {
    if (!_items.containsKey(productId)) {
      return;
    }
    if (newQuantity <= 0) {
      _items.remove(productId);
    } else {
      _items.update(
        productId,
            (existingItem) => CartItem(
          item: existingItem.item,
          quantity: newQuantity,
          notes: existingItem.notes,
        ),
      );
    }
    _checkAndRemoveVoucher();
    notifyListeners();
  }

  void updateItemNotes(String productId, String? notes) {
    if (_items.containsKey(productId)) {
      _items.update(
        productId,
            (existingItem) => CartItem(
          item: existingItem.item,
          quantity: existingItem.quantity,
          notes: notes,
        ),
      );
      notifyListeners();
    }
  }

  void clearCart() {
    _items.clear();
    _selectedDeliveryOption = null;
    _deliveryAddress = null;
    _deliveryFee = 0.0;
    _paymentMethod = 'cash';
    _appliedVoucher = null;
    _customerNotes = null;
    notifyListeners();
  }

  Future<String?> placeOrder({String? customerNotes, required String orderType}) async {
    if (_items.isEmpty) {
      throw Exception('Giỏ hàng trống!');
    }
    if (_currentRestaurantId == null) {
      throw Exception('Chưa xác định nhà hàng.');
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Người dùng chưa đăng nhập.');
    }

    if (orderType == 'delivery') {
      if (_selectedDeliveryOption == null) {
        throw Exception('Vui lòng chọn tùy chọn giao hàng.');
      }
      if (_deliveryAddress == null || _deliveryAddress!.isEmpty) {
        throw Exception('Vui lòng nhập địa chỉ giao hàng.');
      }
    } else if (orderType == 'dine_in') {
      if (_currentTableNumber == null || _currentTableNumber!.isEmpty) {
        throw Exception('Vui lòng cung cấp số bàn cho đơn hàng ăn tại quán.');
      }
    }

    final orderItems = _items.values.map((cartItem) {
      return {
        'menuItemId': cartItem.item.id,
        'name': cartItem.item.name,
        'quantity': cartItem.quantity,
        'price': cartItem.item.price,
        'notes': cartItem.notes,
      };
    }).toList();

    double finalDeliveryFee = (_appliedVoucher != null && _appliedVoucher!.isForShipping) ? 0.0 : _deliveryFee;

    final newOrder = AppOrder(
      restaurantId: _currentRestaurantId!,
      tableNumber: _currentTableNumber,
      userId: user.uid,
      status: 'pending',
      timestamp: Timestamp.now(),
      totalAmount: totalAmount,
      items: orderItems,
      customerNotes: customerNotes ?? _customerNotes,
      deliveryOption: _selectedDeliveryOption,
      deliveryAddress: _deliveryAddress,
      deliveryFee: finalDeliveryFee,
      paymentMethod: _paymentMethod,
      discountAmount: discountAmount,
      orderType: orderType,
    );

    try {
      final docRef = await FirebaseFirestore.instance.collection('orders').add(newOrder.toFirestore());
      clearCart();
      return docRef.id;
    } catch (e) {
      print('Lỗi khi đặt hàng: $e');
      rethrow;
    }
  }
}
