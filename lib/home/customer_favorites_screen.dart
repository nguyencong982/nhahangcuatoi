import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:menufood/shared/models.dart';
import 'package:menufood/shared/favorite_provider.dart';
import 'package:menufood/shared/cart_provider.dart';
import 'package:menufood/orders/cart_screen.dart';

class CustomerFavoritesScreen extends StatelessWidget {
  const CustomerFavoritesScreen({super.key});

  Future<MenuItem?> _fetchMenuItemDetails(String menuItemId, String restaurantId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(restaurantId)
          .collection('menuItems')
          .doc(menuItemId)
          .get();

      if (doc.exists) {
        return MenuItem.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Lỗi khi tải chi tiết món ăn yêu thích: $e');
      return null;
    }
  }

  void _handleReorder(BuildContext context, MenuItem item, String restaurantId) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    if (cartProvider.currentRestaurantId != null && cartProvider.currentRestaurantId != restaurantId && cartProvider.itemCount > 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Xác nhận đặt hàng', style: GoogleFonts.poppins()),
          content: Text(
            'Giỏ hàng hiện tại của bạn đang có món của nhà hàng khác. Bạn có muốn xóa giỏ hàng cũ và thêm món này không?',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Hủy', style: GoogleFonts.poppins(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                cartProvider.clearCart();
                cartProvider.setRestaurantForDelivery(restaurantId);
                cartProvider.addItem(item);
                Navigator.of(ctx).pop();
                _navigateToCartScreen(context, restaurantId);
              },
              child: Text('Xóa & Thêm', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      );
    } else {
      if (cartProvider.currentRestaurantId != null && cartProvider.currentRestaurantId != restaurantId && cartProvider.itemCount > 0) {
        cartProvider.setRestaurantForDelivery(restaurantId);
      }
      cartProvider.addItem(item);
      _navigateToCartScreen(context, restaurantId);
    }
  }

  void _navigateToCartScreen(BuildContext context, String restaurantId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã thêm món vào giỏ hàng.', style: GoogleFonts.poppins()),
        duration: const Duration(milliseconds: 1000),
      ),
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CartScreen(restaurantId: restaurantId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Món ăn Yêu thích', style: GoogleFonts.poppins()),
          backgroundColor: Colors.deepOrange,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Text('Vui lòng đăng nhập để xem mục yêu thích.', style: GoogleFonts.poppins()),
        ),
      );
    }

    final favoriteProvider = Provider.of<FavoriteProvider>(context);
    final favoriteItemsMap = favoriteProvider.favoriteItemsMap;

    if (favoriteItemsMap.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Món ăn Yêu thích', style: GoogleFonts.poppins()),
          backgroundColor: Colors.deepOrange,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.favorite_border, color: Colors.grey, size: 60),
              const SizedBox(height: 10),
              Text(
                'Bạn chưa có món ăn yêu thích nào.',
                style: GoogleFonts.poppins(color: Colors.grey[600]),
              ),
              const SizedBox(height: 5),
              Text(
                'Nhấn vào biểu tượng trái tim để thêm món ăn.',
                style: GoogleFonts.poppins(color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      );
    }

    final List<Future<MenuItem?>> itemFutures = favoriteItemsMap.entries.map((entry) {
      return _fetchMenuItemDetails(entry.key, entry.value);
    }).toList();


    return Scaffold(
      appBar: AppBar(
        title: Text('Món ăn Yêu thích', style: GoogleFonts.poppins()),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<MenuItem?>>(
        future: Future.wait(itemFutures),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi tải chi tiết món ăn: ${snapshot.error}', style: GoogleFonts.poppins()));
          }

          final items = snapshot.data!.where((item) => item != null).cast<MenuItem>().toList();

          if (items.isEmpty) {
            return Center(child: Text('Không tìm thấy món ăn yêu thích nào khả dụng.', style: GoogleFonts.poppins()));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildFavoriteItemTile(context, item, favoriteProvider);
            },
          );
        },
      ),
    );
  }

  Widget _buildFavoriteItemTile(BuildContext context, MenuItem item, FavoriteProvider favoriteProvider) {
    final currencyFormatter = NumberFormat('#,##0', 'vi_VN');
    final isFav = favoriteProvider.isFavorite(item.id);
    final restaurantId = favoriteProvider.favoriteItemsMap[item.id] ?? '';

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
                  placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  errorWidget: (context, url, error) => const Icon(Icons.fastfood, size: 40, color: Colors.grey),
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
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description ?? '',
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  if (item.totalReviews > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${item.averageRating.toStringAsFixed(1)} (${item.totalReviews})',
                            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        'Chưa có đánh giá',
                        style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
                      ),
                    ),
                  Text(
                    '${currencyFormatter.format(item.price)} VNĐ',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _handleReorder(context, item, restaurantId),
                    icon: const Icon(Icons.shopping_bag_outlined, size: 20),
                    label: Text('Đặt hàng lại', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.deepOrange,
                      side: const BorderSide(color: Colors.deepOrange),
                    ),
                  ),
                ],
              ),
            ),

            IconButton(
              icon: Icon(
                isFav ? Icons.favorite : Icons.favorite_border,
                color: isFav ? Colors.red : Colors.grey,
              ),
              onPressed: () async {
                await favoriteProvider.toggleFavorite(item.id, restaurantId);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${item.name} đã được xóa khỏi yêu thích.',
                      style: GoogleFonts.poppins(),
                    ),
                    duration: const Duration(milliseconds: 1500),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}