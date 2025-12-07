import 'package:cloud_firestore/cloud_firestore.dart' as firestore_lib;

enum UserRole {
  customer,
  shipper,
  manager,
  superAdmin,
  unknown,
}

UserRole userRoleFromString(String? role) {
  if (role == null) return UserRole.unknown;
  try {
    return UserRole.values.firstWhere(
          (e) => e.toString().split('.').last == role.toLowerCase(),
    );
  } catch (e) {
    return UserRole.unknown;
  }
}

class MenuItem {
  final String id;
  final String name;
  final String? description;
  final double price;
  final String imageUrl;
  final bool isAvailable;
  final int order;
  final String categoryId;
  final double averageRating;
  final int totalReviews;
  final int? discountPercentage;

  MenuItem({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.imageUrl,
    required this.isAvailable,
    this.order = 0,
    required this.categoryId,
    this.averageRating = 0.0,
    this.totalReviews = 0,
    this.discountPercentage,
  });

  factory MenuItem.fromFirestore(firestore_lib.DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return MenuItem(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      price: (data['price'] is num) ? (data['price'] as num).toDouble() : 0.0,
      imageUrl: data['imageUrl'] ?? '',
      isAvailable: data['isAvailable'] ?? true,
      order: data['order'] ?? 0,
      categoryId: data['categoryId'] ?? '',
      averageRating: (data['averageRating'] is num) ? (data['averageRating'] as num).toDouble() : 0.0,
      totalReviews: data['totalReviews'] ?? 0,
      discountPercentage: data['discountPercentage'] as int?,
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
      'averageRating': averageRating,
      'totalReviews': totalReviews,
      'discountPercentage': discountPercentage ?? 0,
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
    final data = doc.data() as Map<String, dynamic>? ?? {};
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
  final bool isDeleted;
  final String orderType;

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
    this.isDeleted = false,
    this.orderType = "all",
  });

  factory Voucher.fromFirestore(firestore_lib.DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return Voucher(
      id: doc.id,
      code: data['code'] ?? '',
      description: data['description'] ?? '',
      type: data['type'] ?? 'all',
      discountAmount: (data['discountAmount'] is num)
          ? (data['discountAmount'] as num).toDouble()
          : 0.0,
      discountType: data['discountType'] ?? 'fixed',
      startDate: data['startDate'] is firestore_lib.Timestamp
          ? data['startDate']
          : firestore_lib.Timestamp.now(),
      endDate: data['endDate'] is firestore_lib.Timestamp
          ? data['endDate']
          : firestore_lib.Timestamp.now(),
      minOrderAmount: (data['minOrderAmount'] is num)
          ? (data['minOrderAmount'] as num).toDouble()
          : null,
      isForShipping: data['isForShipping'] ?? false,
      maxDiscountAmount: (data['maxDiscountAmount'] is num)
          ? (data['maxDiscountAmount'] as num).toDouble()
          : null,
      isDeleted: data['isDeleted'] ?? false,
      orderType: data['orderType'] ?? "all",
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
      'isDeleted': isDeleted,
      'orderType': orderType,
    };
  }
}

class CartItem {
  final MenuItem item;
  int quantity;
  String? notes;
  CartItem({required this.item, this.quantity = 1, this.notes});
  double get subtotal => item.price * quantity;
}


class Restaurant {
  final String id;
  final String name;
  final String? address;
  final String description;
  final String? logoUrl;
  final String? qrCodeContent;
  final String imageUrl;
  final firestore_lib.GeoPoint? location;
  final String? managerId;
  final List<String> galleryImages;

  Restaurant({
    required this.id,
    required this.name,
    this.address,
    this.description = '',
    this.logoUrl,
    this.qrCodeContent,
    required this.imageUrl,
    this.location,
    this.managerId,
    this.galleryImages = const [],
  });

  factory Restaurant.fromFirestore(firestore_lib.DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Restaurant(
      id: doc.id,
      name: data['name'] ?? 'Tên nhà hàng',
      address: data['address'] as String?,
      description: data['description'] ?? '',
      logoUrl: data['logoUrl'] as String?,
      qrCodeContent: data['qrCodeContent'] as String?,
      imageUrl: data['imageUrl'] ?? '',
      location: data['location'] as firestore_lib.GeoPoint?,
      managerId: data['managerId'] as String?,
      galleryImages: List<String>.from(data['galleryImages'] ?? []),
    );
  }
}

class AppOrder {
  final String id;
  final String restaurantId;
  final String? tableNumber;
  final String userId;
  final String customerId;
  final String customerName;
  final String? shipperId;
  final String status;
  final firestore_lib.Timestamp timestamp;
  final double totalAmount;
  final List<Map<String, dynamic>> items;
  final String? customerNotes;
  final String? deliveryOption;
  final String? deliveryAddress;
  final double? deliveryFee;
  final String paymentMethod;
  final String paymentStatus;
  final double? discountAmount;
  final String orderType;
  final String? voucherId;
  final firestore_lib.GeoPoint? deliveryLocation;
  final firestore_lib.GeoPoint? restaurantLocation;
  final String? shipperName;
  final String? customerPhoneNumber;
  final String? cancelledBy;
  final firestore_lib.Timestamp? cancelledAt;

  AppOrder({
    this.id = '',
    required this.restaurantId,
    this.tableNumber,
    required this.userId,
    required this.customerId,
    required this.customerName,
    this.shipperId,
    required this.status,
    required this.timestamp,
    required this.totalAmount,
    required this.items,
    this.customerNotes,
    this.deliveryOption,
    this.deliveryAddress,
    this.deliveryFee,
    required this.paymentMethod,
    this.paymentStatus = 'unpaid',
    this.discountAmount,
    required this.orderType,
    this.voucherId,
    this.deliveryLocation,
    this.restaurantLocation,
    this.shipperName,
    this.customerPhoneNumber,
    this.cancelledBy,
    this.cancelledAt,
  });

  factory AppOrder.fromFirestore(firestore_lib.DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return AppOrder(
      id: doc.id,
      restaurantId: data['restaurantId'] ?? '',
      tableNumber: data['tableNumber'] as String?,
      userId: data['userId'] ?? '',
      customerId: data['customerId'] ?? '',
      customerName: data['customerName'] ?? '',
      shipperId: data['shipperId'] as String?,
      status: data['status'] ?? 'unknown',
      timestamp: data['timestamp'] is firestore_lib.Timestamp
          ? data['timestamp']
          : firestore_lib.Timestamp.now(),
      totalAmount:
      (data['totalAmount'] is num) ? (data['totalAmount'] as num).toDouble() : 0.0,
      items: List<Map<String, dynamic>>.from(data['items'] ?? []),
      customerNotes: data['customerNotes'] as String?,
      customerPhoneNumber: data['customerPhoneNumber'] as String?,
      deliveryOption: data['deliveryOption'] as String?,
      deliveryAddress: data['deliveryAddress'] as String?,
      deliveryFee: (data['deliveryFee'] is num)
          ? (data['deliveryFee'] as num).toDouble()
          : null,
      paymentMethod: data['paymentMethod'] ?? 'cash',
      paymentStatus: data['paymentStatus'] ?? 'unpaid',
      discountAmount: (data['discountAmount'] is num)
          ? (data['discountAmount'] as num).toDouble()
          : null,
      orderType: data['orderType'] ?? 'delivery',
      voucherId: data['voucherId'] as String?,
      deliveryLocation: data['deliveryLocation'] as firestore_lib.GeoPoint?,
      restaurantLocation: data['restaurantLocation'] as firestore_lib.GeoPoint?,
      shipperName: data['shipperName'] as String?,
      cancelledBy: data['cancelledBy'] as String?,
      cancelledAt: data['cancelledAt'] as firestore_lib.Timestamp?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'restaurantId': restaurantId,
      'tableNumber': tableNumber,
      'userId': userId,
      'customerId': customerId,
      'customerName': customerName,
      'shipperId': shipperId,
      'status': status,
      'timestamp': timestamp,
      'items': items,
      'totalAmount': totalAmount,
      'customerNotes': customerNotes,
      'deliveryOption': deliveryOption,
      'deliveryAddress': deliveryAddress,
      'deliveryFee': deliveryFee,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'discountAmount': discountAmount,
      'orderType': orderType,
      'voucherId': voucherId,
      'deliveryLocation': deliveryLocation,
      'restaurantLocation': restaurantLocation,
      'shipperName': shipperName,
      'customerPhoneNumber': customerPhoneNumber,
      'cancelledBy': cancelledBy,
      'cancelledAt': cancelledAt,
    };
  }
}

class AppUser {
  final String id;
  final String email;
  final String name;
  final String? phone;
  final String? imageUrl;
  final UserRole role;
  final bool isDeleted;
  final String? fullName;
  final String? phoneNumber;

  AppUser({
    required this.id,
    required this.email,
    required this.name,
    this.phone,
    this.imageUrl,
    this.role = UserRole.customer,
    this.isDeleted = false,
    this.fullName,
    this.phoneNumber,
  });

  factory AppUser.fromFirestore(firestore_lib.DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final String name = data['name'] ?? '';
    final String email = data['email'] ?? '';
    final String roleString = data['role'] ?? 'customer';

    return AppUser(
      id: doc.id,
      email: email,
      name: name,
      phone: data['phone'] as String?,
      imageUrl: data['imageUrl'] as String?,
      role: UserRole.values.firstWhere(
            (e) => e.toString().split('.').last == roleString,
        orElse: () => UserRole.customer,
      ),
      isDeleted: data['isDeleted'] ?? false,
      fullName: data['name'] as String?,
      phoneNumber: data['phone'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'name': fullName,
      'phone': phoneNumber,
      'imageUrl': imageUrl,
      'role': role.toString().split('.').last,
      'isDeleted': isDeleted,
    };
  }
}

class Review {
  final String id;
  final String userId;
  final String userName;
  final String menuItemId;
  final double rating;
  final String? comment;
  final firestore_lib.Timestamp timestamp;
  final String? orderId;

  Review({
    required this.id,
    required this.userId,
    required this.userName,
    required this.menuItemId,
    required this.rating,
    this.comment,
    required this.timestamp,
    this.orderId,
  });

  factory Review.fromFirestore(firestore_lib.DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return Review(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Khách hàng ẩn danh',

      menuItemId: data['menuItemId'] ?? data['entityId'] ?? '',
      rating: (data['rating'] is num) ? (data['rating'] as num).toDouble() : 0.0,
      comment: data['comment'] as String?,
      timestamp: data['timestamp'] is firestore_lib.Timestamp
          ? data['timestamp']
          : firestore_lib.Timestamp.now(),
      orderId: data['orderId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'menuItemId': menuItemId,
      'rating': rating,
      'comment': comment,
      'timestamp': timestamp,
      'orderId': orderId,
    };
  }
}