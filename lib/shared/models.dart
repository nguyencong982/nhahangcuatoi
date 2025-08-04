import 'package:cloud_firestore/cloud_firestore.dart' as firestore_lib;

class MenuItem {
  final String id;
  final String name;
  final String? description;
  final double price;
  final String imageUrl;
  final bool isAvailable;
  final int order;
  final String categoryId;

  MenuItem({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.imageUrl,
    required this.isAvailable,
    this.order = 0,
    required this.categoryId,
  });

  factory MenuItem.fromFirestore(firestore_lib.DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return MenuItem(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      price: (data['price'] ?? 0).toDouble(),
      imageUrl: data['imageUrl'] ?? '',
      isAvailable: data['isAvailable'] ?? true,
      order: data['order'] ?? 0,
      categoryId: data['categoryId'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'isAvailable': isAvailable,
      'order': order,
      'categoryId': categoryId,
    };
  }
}

class Category {
  final String id;
  final String name;
  final int order;
  final bool isAvailableForDelivery;
  final bool isAvailableForDineIn;
  final String imageUrl;
  final List<MenuItem> items;

  Category({
    required this.id,
    required this.name,
    required this.order,
    this.isAvailableForDelivery = true,
    this.isAvailableForDineIn = true,
    this.imageUrl = '',
    this.items = const [],
  });

  factory Category.fromFirestore(firestore_lib.DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Category(
      id: doc.id,
      name: data['name'] ?? '',
      order: data['order'] ?? 0,
      isAvailableForDelivery: data['isAvailableForDelivery'] ?? true,
      isAvailableForDineIn: data['isAvailableForDineIn'] ?? true,
      imageUrl: data['imageUrl'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'order': order,
      'isAvailableForDelivery': isAvailableForDelivery,
      'isAvailableForDineIn': isAvailableForDineIn,
      'imageUrl': imageUrl,
    };
  }
}

class Voucher {
  final String id;
  final String code;
  final String description;
  final String type;
  final double discountAmount;
  final String discountType;
  final firestore_lib.Timestamp startDate;
  final firestore_lib.Timestamp endDate;
  final double? minOrderAmount;
  final bool isForShipping;
  final double? maxDiscountAmount;

  Voucher({
    required this.id,
    required this.code,
    required this.description,
    required this.type,
    required this.discountAmount,
    required this.discountType,
    required this.startDate,
    required this.endDate,
    this.minOrderAmount,
    this.isForShipping = false,
    this.maxDiscountAmount,
  });

  factory Voucher.fromFirestore(firestore_lib.DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Voucher(
      id: doc.id,
      code: data['code'] ?? '',
      description: data['description'] ?? '',
      type: data['type'] ?? 'all',
      discountAmount: (data['discountAmount'] ?? 0).toDouble(),
      discountType: data['discountType'] ?? 'fixed',
      startDate: data['startDate'] ?? firestore_lib.Timestamp.now(),
      endDate: data['endDate'] ?? firestore_lib.Timestamp.now(),
      minOrderAmount: (data['minOrderAmount'] ?? 0).toDouble(),
      isForShipping: data['isForShipping'] ?? false,
      maxDiscountAmount: (data['maxDiscountAmount'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'code': code,
      'description': description,
      'type': type,
      'discountAmount': discountAmount,
      'discountType': discountType,
      'startDate': startDate,
      'endDate': endDate,
      'minOrderAmount': minOrderAmount,
      'isForShipping': isForShipping,
      'maxDiscountAmount': maxDiscountAmount,
    };
  }
}

class CartItem {
  final MenuItem item;
  int quantity;
  String? notes;

  CartItem({
    required this.item,
    this.quantity = 1,
    this.notes,
  });

  double get subtotal => item.price * quantity;
}

class AppOrder {
  final String id;
  final String restaurantId;
  final String? tableNumber;
  final String userId;
  final String status;
  final firestore_lib.Timestamp timestamp;
  final double totalAmount;
  final List<Map<String, dynamic>> items;
  final String? customerNotes;
  final String? deliveryOption;
  final String? deliveryAddress;
  final double? deliveryFee;
  final String paymentMethod;
  final double? discountAmount;
  final String orderType;

  AppOrder({
    this.id = '',
    required this.restaurantId,
    this.tableNumber,
    required this.userId,
    required this.status,
    required this.timestamp,
    required this.totalAmount,
    required this.items,
    this.customerNotes,
    this.deliveryOption,
    this.deliveryAddress,
    this.deliveryFee,
    required this.paymentMethod,
    this.discountAmount,
    required this.orderType,
  });

  factory AppOrder.fromFirestore(firestore_lib.DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return AppOrder(
      id: doc.id,
      restaurantId: data['restaurantId'] ?? '',
      tableNumber: data['tableNumber'],
      userId: data['userId'] ?? '',
      status: data['status'] ?? 'unknown',
      timestamp: data['timestamp'] ?? firestore_lib.Timestamp.now(),
      totalAmount: (data['totalAmount'] ?? 0.0).toDouble(),
      items: List<Map<String, dynamic>>.from(data['items'] ?? []),
      customerNotes: data['customerNotes'],
      deliveryOption: data['deliveryOption'],
      deliveryAddress: data['deliveryAddress'],
      deliveryFee: (data['deliveryFee'] ?? 0.0).toDouble(),
      paymentMethod: data['paymentMethod'] ?? 'cash',
      discountAmount: (data['discountAmount'] ?? 0.0).toDouble(),
      orderType: data['orderType'] ?? 'delivery',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'restaurantId': restaurantId,
      'tableNumber': tableNumber,
      'userId': userId,
      'status': status,
      'timestamp': timestamp,
      'items': items,
      'totalAmount': totalAmount,
      'customerNotes': customerNotes,
      'deliveryOption': deliveryOption,
      'deliveryAddress': deliveryAddress,
      'deliveryFee': deliveryFee,
      'paymentMethod': paymentMethod,
      'discountAmount': discountAmount,
      'orderType': orderType,
    };
  }
}

class Restaurant {
  final String id;
  final String name;
  final String? address;
  final String? description;
  final String? logoUrl;
  final String? qrCodeContent;
  final String imageUrl;

  Restaurant({
    required this.id,
    required this.name,
    this.address,
    this.description,
    this.logoUrl,
    this.qrCodeContent,
    required this.imageUrl
  });

  factory Restaurant.fromFirestore(firestore_lib.DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Restaurant(
      id: doc.id,
      name: data['name'] ?? 'Tên nhà hàng',
      address: data['address'],
      description: data['description'],
      logoUrl: data['logoUrl'],
      qrCodeContent: data['qrCodeContent'],
      imageUrl: data['imageUrl'] ?? '',
    );
  }
}
