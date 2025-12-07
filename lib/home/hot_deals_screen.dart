import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:menufood/shared/models.dart';
import 'package:menufood/shared/cart_provider.dart';

const Color commonBackgroundColor = Color(0xFFFCF6E0);
const Color primaryOrangeColor = Color(0xFFF96E21);

class HotDealsScreen extends StatelessWidget {
  final String restaurantId;
  final String restaurantName;
  final NumberFormat currencyFormatter = NumberFormat('#,##0', 'vi_VN');

  HotDealsScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  Stream<List<MenuItem>> getHotDealsStream() {
    if (restaurantId.isEmpty) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('restaurants')
        .doc(restaurantId)
        .collection('menuItems')
        .where('isAvailable', isEqualTo: true)
        .where('discountPercentage', isGreaterThanOrEqualTo: 50)
        .orderBy('discountPercentage', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => MenuItem.fromFirestore(doc))
              .toList();
        });
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
                        Text(
                          ' ${avgRating.toStringAsFixed(1)} ($totalReviews)',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
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
                      color: Colors.green.shade700,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: commonBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 28),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          '🔥 Deal Giảm Giá Nóng',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        backgroundColor: commonBackgroundColor,
        elevation: 0,
      ),
      body: StreamBuilder<List<MenuItem>>(
        stream: getHotDealsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: primaryOrangeColor),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Lỗi tải Deal. Vui lòng kiểm tra Firebase Index nếu có thông báo: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: Colors.red),
                ),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                'Hiện không có Deal giảm giá 50% trở lên nào tại ${restaurantName}!',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            );
          }

          final hotDeals = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: hotDeals.length,
            itemBuilder: (context, index) {
              return _buildMenuItemTile(context, hotDeals[index]);
            },
          );
        },
      ),
    );
  }
}
