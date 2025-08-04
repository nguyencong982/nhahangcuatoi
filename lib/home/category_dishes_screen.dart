import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:menufood/shared/models.dart';
import 'package:menufood/shared/cart_provider.dart';
import 'package:menufood/orders/cart_screen.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CartProvider>(context, listen: false).setRestaurantAndTable(
        widget.restaurantId,
        null,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.name),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('menuItems')
            .where('categoryId', isEqualTo: widget.category.id)
            .orderBy('order')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi tải món ăn: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'Chưa có món ăn nào trong danh mục ${widget.category.name}.',
                style: GoogleFonts.poppins(color: Colors.grey[600]),
              ),
            );
          }

          final menuItems = snapshot.data!.docs
              .map((doc) => MenuItem.fromFirestore(doc))
              .where((item) => item.isAvailable)
              .toList();

          if (menuItems.isEmpty) {
            return Center(
              child: Text(
                'Không có món ăn nào khả dụng trong danh mục ${widget.category.name}.',
                style: GoogleFonts.poppins(color: Colors.grey[600]),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: menuItems.length,
            itemBuilder: (context, index) {
              final item = menuItems[index];
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
                                Text('$quantity', style: GoogleFonts.poppins(fontSize: 16)),
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
                    tableNumber: 'Delivery',
                  ),
                ),
              );
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
