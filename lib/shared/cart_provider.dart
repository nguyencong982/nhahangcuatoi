import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:menufood/shared/models.dart'; // Đảm bảo models.dart có AppOrder và các class liên quan
import 'package:uuid/uuid.dart';

class CartProvider with ChangeNotifier {
  final Map<String, CartItem> _items = {};
  String? _currentRestaurantId;
  String? _currentTableNumber;
  String _orderType = 'dine_in';
  String? _selectedDeliveryOption;
  String? _deliveryAddress;
  GeoPoint? _deliveryLocation;
  String? _customerPhoneNumber;
  GeoPoint? _currentRestaurantLocation;
  double _deliveryFee = 0.0;
  String _paymentMethod = 'cash';
  Voucher? _appliedVoucher;
  String? _customerNotes;
  double _discountAmount = 0.0;

  Map<String, CartItem> get items => _items;
  String? get currentRestaurantId => _currentRestaurantId;
  String? get currentTableNumber => _currentTableNumber;
  String get orderType => _orderType;
  String? get selectedDeliveryOption => _selectedDeliveryOption;
  double get deliveryFee => _deliveryFee;
  String? get deliveryAddress => _deliveryAddress;
  GeoPoint? get deliveryLocation => _deliveryLocation;

  String? get customerPhoneNumber => _customerPhoneNumber;
  GeoPoint? get currentRestaurantLocation => _currentRestaurantLocation;
  String get paymentMethod => _paymentMethod;
  Voucher? get appliedVoucher => _appliedVoucher;
  String? get customerNotes => _customerNotes;
  double get discountAmount => _discountAmount;

  double get subtotalAmount {
    double total = 0.0;
    _items.forEach((key, cartItem) {
      total += cartItem.subtotal;
    });
    return total;
  }

  double get totalAmount {
    double total = subtotalAmount + _deliveryFee - _discountAmount;
    return total > 0 ? total : 0.0;
  }

  int get itemCount {
    return _items.length;
  }

  void setDeliveryInfo(String? address, GeoPoint? location) {
    _deliveryAddress = address;
    _deliveryLocation = location;
    notifyListeners();
  }

  void setCustomerPhoneNumber(String? phoneNumber) {
    _customerPhoneNumber = phoneNumber;
    notifyListeners();
  }

  void setOrderType(String type) {
    if (_orderType != type) {
      _orderType = type;
      if (type == 'dine_in') {
        _selectedDeliveryOption = null;
        _deliveryAddress = null;
        _deliveryLocation = null;
        _deliveryFee = 0.0;
      } else if (type == 'delivery') {
        _currentTableNumber = null;
      }
      _appliedVoucher = null;
      _recalculateTotals();
      notifyListeners();
    }
  }

  Future<void> setRestaurantForDelivery(String restaurantId) async {
    if (_currentRestaurantId != restaurantId) {
      _currentRestaurantId = restaurantId;
      final doc = await FirebaseFirestore.instance.collection('restaurants').doc(restaurantId).get();
      if (doc.exists) {
        _currentRestaurantLocation = (doc.data()?['location'] as GeoPoint?);
      }
      _items.clear();
      _appliedVoucher = null;
      _customerNotes = null;
      _recalculateTotals();
    }
    _currentTableNumber = null;
    setOrderType('delivery');
  }

  Future<void> setRestaurantAndTableForDineIn(String restaurantId, String? tableNumber) async {
    if (_currentRestaurantId != restaurantId) {
      _currentRestaurantId = restaurantId;
      final doc = await FirebaseFirestore.instance.collection('restaurants').doc(restaurantId).get();
      if (doc.exists) {
        _currentRestaurantLocation = (doc.data()?['location'] as GeoPoint?);
      }
      _items.clear();
      _appliedVoucher = null;
      _customerNotes = null;
      _recalculateTotals();
    }
    _currentTableNumber = tableNumber;
    setOrderType('dine_in');
  }

  void setDeliveryOption(String? option, double fee) {
    _selectedDeliveryOption = option;
    _deliveryFee = fee;
    _appliedVoucher = null;
    _recalculateTotals();
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

  Future<bool> hasUserUsedVoucher(String voucherId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return false;
    }
    final usedVoucherQuery = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('usedVouchers')
        .where('voucherId', isEqualTo: voucherId)
        .limit(1)
        .get();
    return usedVoucherQuery.docs.isNotEmpty;
  }

  Future<bool> checkVoucherValidity(Voucher voucher) async {
    final now = Timestamp.now();
    final subtotal = subtotalAmount;
    if (now.compareTo(voucher.startDate) < 0 || now.compareTo(voucher.endDate) > 0) {
      print('Voucher đã hết hạn hoặc chưa đến ngày hiệu lực');
      return false;
    }
    if (voucher.isForShipping && _orderType != 'delivery') {
      print('Voucher phí ship chỉ áp dụng cho đơn hàng giao hàng');
      return false;
    }
    if (!voucher.isForShipping && voucher.type != 'all' && voucher.type != _orderType) {
      print('Loại đơn hàng không phù hợp với voucher');
      return false;
    }
    if (voucher.minOrderAmount != null && subtotal < voucher.minOrderAmount!) {
      print('Tổng đơn hàng chưa đủ giá trị tối thiểu');
      return false;
    }
    final hasUsed = await hasUserUsedVoucher(voucher.id);
    if (hasUsed) {
      print('Người dùng đã sử dụng voucher này');
      return false;
    }
    print('Voucher hợp lệ');
    return true;
  }

  void _recalculateTotals() {
    double tempDiscount = 0.0;
    if (_appliedVoucher != null) {
      if (_appliedVoucher!.isForShipping && _orderType == 'delivery') {
        tempDiscount = _deliveryFee;
      } else {
        if (_appliedVoucher!.discountType == 'fixed') {
          tempDiscount = _appliedVoucher!.discountAmount;
        } else if (_appliedVoucher!.discountType == 'percentage') {
          double calculatedDiscount = subtotalAmount * (_appliedVoucher!.discountAmount / 100);
          if (_appliedVoucher!.maxDiscountAmount != null && calculatedDiscount > _appliedVoucher!.maxDiscountAmount!) {
            tempDiscount = _appliedVoucher!.maxDiscountAmount!;
          } else {
            tempDiscount = calculatedDiscount;
          }
        }
      }
    }
    _discountAmount = tempDiscount;
  }

  Future<bool> applyVoucher(Voucher voucher) async {
    try {
      if (await checkVoucherValidity(voucher)) {
        _appliedVoucher = voucher;
        _recalculateTotals();
        print('Voucher đã được áp dụng thành công');
        notifyListeners();
        return true;
      }
    } catch (e) {
      print('Lỗi khi áp dụng voucher: $e');
    }
    _appliedVoucher = null;
    notifyListeners();
    return false;
  }

  void removeVoucher() {
    _appliedVoucher = null;
    _recalculateTotals();
    notifyListeners();
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
    _recalculateTotals();
    notifyListeners();
  }

  void removeItem(String productId) {
    _items.remove(productId);
    _recalculateTotals();
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
    _recalculateTotals();
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
    _recalculateTotals();
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
    _appliedVoucher = null;
    _customerNotes = null;
    _customerPhoneNumber = null;
    _recalculateTotals();
    notifyListeners();
  }

  Future<String?> placeOrder({
    String? customerNotes,
    required String orderType,
    required String customerId,
    required String customerName,
    String? paymentStatus,
  }) async {
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
      if (_currentRestaurantLocation == null) {
        throw Exception('Chưa xác định vị trí nhà hàng.');
      }
      if (_selectedDeliveryOption == null) {
        throw Exception('Vui lòng chọn tùy chọn giao hàng.');
      }
      if (_deliveryAddress == null || _deliveryAddress!.isEmpty) {
        throw Exception('Vui lòng nhập địa chỉ giao hàng.');
      }
      // KIỂM TRA SỐ ĐIỆN THOẠI
      if (_customerPhoneNumber == null || _customerPhoneNumber!.isEmpty) {
        throw Exception('Vui lòng cung cấp số điện thoại liên lạc để giao hàng.');
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

    _recalculateTotals();

    GeoPoint finalRestaurantLocation = _currentRestaurantLocation ?? (orderType == 'dine_in' ? const GeoPoint(0, 0) : throw Exception('Không thể xác định vị trí nhà hàng để tạo đơn hàng giao tận nơi.'));

    String finalPaymentStatus = paymentStatus ?? (_paymentMethod == 'cash' ? 'pending' : 'awaiting_payment');


    final newOrder = AppOrder(
      restaurantId: _currentRestaurantId!,
      tableNumber: _currentTableNumber,
      userId: user.uid,
      customerId: customerId,
      customerName: customerName,
      status: 'pending',
      timestamp: Timestamp.now(),
      totalAmount: totalAmount,
      items: orderItems,
      customerNotes: customerNotes ?? _customerNotes,
      // LƯU SỐ ĐIỆN THOẠI VÀO ĐƠN HÀNG
      customerPhoneNumber: _customerPhoneNumber,
      deliveryOption: _selectedDeliveryOption,
      deliveryAddress: _deliveryAddress,
      deliveryLocation: _deliveryLocation,
      deliveryFee: _deliveryFee,
      paymentMethod: _paymentMethod, // Lấy từ Provider
      discountAmount: discountAmount,
      orderType: orderType,
      voucherId: _appliedVoucher?.id,
      restaurantLocation: finalRestaurantLocation,
      paymentStatus: finalPaymentStatus,
    );
    try {
      final docRef = await FirebaseFirestore.instance.collection('orders').add(newOrder.toFirestore());
      if (_appliedVoucher != null) {
        await FirebaseFirestore.instance.collection('usedVouchers').add({
          'userId': user.uid,
          'voucherId': _appliedVoucher!.id,
          'orderId': docRef.id,
          'timestamp': Timestamp.now(),
        });
      }
      clearCart();
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }
}