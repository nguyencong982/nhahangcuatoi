import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:menufood/shared/models.dart';
import 'package:menufood/shared/cart_provider.dart';
import 'package:menufood/orders/cart_screen.dart';
import 'package:intl/intl.dart';
import 'package:menufood/shared/favorite_provider.dart';

class CategoryDishesScreen extends StatefulWidget {
  final Category category;
  final String restaurantId;

  const CategoryDishesScreen({
    super.key,
    required this.category,
    required this.restaurantId,
  });

  @override
  State<CategoryDishesScreen> createState() => _CategoryDishesScreenState();
}

class _CategoryDishesScreenState extends State<CategoryDishesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final currencyFormatter = NumberFormat('#,##0', 'vi_VN');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CartProvider>(context, listen: false).setRestaurantForDelivery(
        widget.restaurantId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.name, style: GoogleFonts.poppins()),
        centerTitle: true,
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('restaurants')
            .doc(widget.restaurantId)
            .collection('menuItems')
            .where('categoryId', isEqualTo: widget.category.id)
            .where('isAvailable', isEqualTo: true)
            .orderBy('order')
            .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print('Lỗi truy vấn món ăn: ${snapshot.error}');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 40),
                    const SizedBox(height: 10),
                    Text(
                      'Lỗi tải món ăn. Vui lòng kiểm tra lại kết nối hoặc dữ liệu menu.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(color: Colors.red),
                    ),
                  ],
                ),
              ),
            );
          }

          final menuItems = snapshot.data!.docs
              .map((doc) => MenuItem.fromFirestore(doc))
              .toList();

          if (menuItems.isEmpty) {
            return Center(
              child: Text(
                'Không có món ăn nào khả dụng trong danh mục ${widget.category.name} tại nhà hàng này.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: Colors.grey[600]),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: menuItems.length,
            itemBuilder: (context, index) {
              final item = menuItems[index];
              return _buildMenuItemTile(context, item);
            },
          );
        },
      ),
      floatingActionButton: Consumer<CartProvider>(
        builder: (context, cart, child) {
          return cart.itemCount > 0
              ? FloatingActionButton.extended(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => CartScreen(
                    restaurantId: widget.restaurantId,
                  ),
                ),
              );
            },
            backgroundColor: Colors.deepOrange,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.shopping_cart),
            label: Text(
              'Xem Giỏ Hàng (${cart.itemCount} món - ${currencyFormatter.format(cart.totalAmount)} VNĐ)',
              style: GoogleFonts.poppins(),
            ),
          )
              : Container();
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildMenuItemTile(BuildContext context, MenuItem item) {
    final favoriteProvider = Provider.of<FavoriteProvider>(context);
    final isFav = favoriteProvider.isFavorite(item.id);

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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav ? Colors.red : Colors.grey,
                        ),
                        onPressed: () async {
                          await favoriteProvider.toggleFavorite(item.id, widget.restaurantId);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isFav ? '${item.name} đã được xóa khỏi yêu thích.' : '${item.name} đã được thêm vào yêu thích.',
                                style: GoogleFonts.poppins(),
                              ),
                              duration: const Duration(milliseconds: 1500),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
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
                    item.description ?? '',
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${currencyFormatter.format(item.price)} VNĐ',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange,
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
                      icon: const Icon(Icons.add_circle, color: Colors.deepOrange),
                      onPressed: () {
                        Provider.of<CartProvider>(context, listen: false).addItem(item);
                      },
                    ),
                    Text('$quantity', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: Icon(Icons.remove_circle, color: quantity > 0 ? Colors.grey : Colors.grey[300]),
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
  }
}