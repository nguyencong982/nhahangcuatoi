import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:menufood/shared/cart_provider.dart';
import 'package:menufood/shared/models.dart';
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart';
import 'package:menufood/orders/order_tracking_screen.dart'; // Thêm import này

class DineInCartScreen extends StatefulWidget {
  final String restaurantId;
  final String? tableNumber;

  const DineInCartScreen({Key? key, required this.restaurantId, this.tableNumber}) : super(key: key);

  @override
  State<DineInCartScreen> createState() => _DineInCartScreenState();
}

class _DineInCartScreenState extends State<DineInCartScreen> {
  Restaurant? _currentRestaurant;
  bool _isLoadingRestaurant = true;
  TextEditingController _customerNotesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchRestaurantDetails();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      cartProvider.setRestaurantAndTable(widget.restaurantId, widget.tableNumber);
      _customerNotesController.text = cartProvider.customerNotes ?? '';
    });
  }

  @override
  void dispose() {
    _customerNotesController.dispose();
    super.dispose();
  }

  Future<void> _fetchRestaurantDetails() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId)
          .get();
      if (doc.exists) {
        setState(() {
          _currentRestaurant = Restaurant.fromFirestore(doc);
          _isLoadingRestaurant = false;
        });
      } else {
        setState(() {
          _isLoadingRestaurant = false;
        });
        print('Không tìm thấy nhà hàng với ID: ${widget.restaurantId}');
      }
    } catch (e) {
      setState(() {
        _isLoadingRestaurant = false;
      });
      print('Lỗi khi tải thông tin nhà hàng: $e');
    }
  }

  void _showNotesDialog(CartItem cartItem) {
    TextEditingController notesController =
    TextEditingController(text: cartItem.notes);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Thêm ghi chú cho ${cartItem.item.name}'),
        content: TextField(
          controller: notesController,
          decoration: InputDecoration(hintText: 'Ví dụ: Ít đường, không đá...'),
          maxLines: 3,
        ),
        actions: <Widget>[
          TextButton(
            child: Text('Hủy'),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          ),
          ElevatedButton(
            child: Text('Lưu'),
            onPressed: () {
              Provider.of<CartProvider>(context, listen: false)
                  .updateItemNotes(cartItem.item.id, notesController.text);
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _placeDineInOrder() async {
    final cart = Provider.of<CartProvider>(context, listen: false);

    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Giỏ hàng của bạn đang trống!')),
      );
      return;
    }
    try {
      final String? orderId = await cart.placeOrder(
        customerNotes: _customerNotesController.text.isEmpty ? null : _customerNotesController.text,
        orderType: 'dine_in',
      );

      if (orderId != null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Món của bạn đã được đặt thành công!')),
          );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => OrderTrackingScreen(orderId: orderId),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi đặt món: ${e.toString()}')),
      );
    }
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,##0', 'vi_VN');
    return '${formatter.format(amount)} VNĐ';
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Xác nhận món', style: GoogleFonts.poppins()),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: _isLoadingRestaurant
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_currentRestaurant != null)
                  Text(
                    'Nhà hàng: ${_currentRestaurant!.name}',
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                if (widget.tableNumber != null)
                  Text(
                    'Bàn số: ${widget.tableNumber}',
                    style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[700]),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                SizedBox(height: 10),
                if (cart.items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        'Giỏ hàng của bạn đang trống.',
                        style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                  )
                else
                  _buildCartItemsSection(cart),
                SizedBox(height: 10),

                _buildPaymentInfoSection(cart),
                SizedBox(height: 10),

                _buildPromotionsSection(cart),
                SizedBox(height: 10),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TextField(
                    controller: _customerNotesController,
                    decoration: InputDecoration(
                      labelText: 'Ghi chú cho nhà hàng (tùy chọn)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.note_add, color: Colors.grey[600]),
                    ),
                    maxLines: 2,
                    onChanged: (value) {
                      Provider.of<CartProvider>(context, listen: false).setCustomerNotes(value);
                    },
                  ),
                ),
                SizedBox(height: 10),
              ],
            ),
          ),
          _buildTotalAndOrderButtonSection(cart),
        ],
      ),
    );
  }

  Widget _buildCartItemsSection(CartProvider cart) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
      ),
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Món trong giỏ',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('Thêm món', style: GoogleFonts.poppins(color: Colors.green)),
              ),
            ],
          ),
          ...cart.items.values.map((cartItem) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: Text('${cartItem.quantity}', style: GoogleFonts.poppins(fontSize: 14)),
                        ),
                      ),
                      SizedBox(width: 10),
                      if (cartItem.item.imageUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: Image.network(
                            cartItem.item.imageUrl,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image, size: 60, color: Colors.grey),
                          ),
                        ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cartItem.item.name,
                              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              _formatCurrency(cartItem.item.price),
                              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700]),
                            ),
                            if (cartItem.notes != null && cartItem.notes!.isNotEmpty)
                              Text(
                                'Ghi chú: ${cartItem.notes}',
                                style: GoogleFonts.poppins(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
                              ),
                            GestureDetector(
                              onTap: () => _showNotesDialog(cartItem),
                              child: Text(
                                'Chỉnh sửa',
                                style: GoogleFonts.poppins(fontSize: 12, color: Colors.blue, decoration: TextDecoration.underline),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _formatCurrency(cartItem.subtotal),
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () {
                          cart.removeItem(cartItem.item.id);
                        },
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, indent: 40, endIndent: 10),
              ],
            );
          }).toList(),
          SizedBox(height: 10),
          _buildSummaryRow('Tổng tạm tính', _formatCurrency(cart.subtotalAmount)),
          _buildCutleryOption(),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[700])),
          Text(value, style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[700])),
        ],
      ),
    );
  }

  Widget _buildCutleryOption() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dụng cụ ăn uống', style: GoogleFonts.poppins(fontSize: 15)),
                Text('Chỉ yêu cầu khi thật sự cần.',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Switch(
            value: false,
            onChanged: (bool value) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Tính năng yêu cầu dụng cụ ăn uống đang được phát triển.')),
              );
            },
            activeColor: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentInfoSection(CartProvider cart) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Thông tin thanh toán', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
              TextButton(onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Tính năng xem tất cả phương thức thanh toán đang được phát triển.')),
                );
              }, child: Text('Xem tất cả', style: GoogleFonts.poppins(color: Colors.green))),
            ],
          ),
          ListTile(
            leading: Icon(Icons.credit_card, color: Colors.blue),
            title: Text('Thẻ', style: GoogleFonts.poppins()),
            trailing: cart.paymentMethod == 'card'
                ? Icon(Icons.check_circle, color: Colors.green)
                : Text('Đề xuất', style: GoogleFonts.poppins(color: Colors.grey)),
            onTap: () {
              cart.setPaymentMethod('card');
            },
          ),
          ListTile(
            leading: Icon(Icons.money, color: Colors.green),
            title: Text('Tiền mặt', style: GoogleFonts.poppins()),
            trailing: cart.paymentMethod == 'cash'
                ? Icon(Icons.check_circle, color: Colors.green)
                : null,
            onTap: () {
              cart.setPaymentMethod('cash');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPromotionsSection(CartProvider cart) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ưu đãi', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
          SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Tính năng áp dụng ưu đãi đang được phát triển.')),
              );
            },
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.local_offer, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Áp dụng ưu đãi để được giảm giá',
                      style: GoogleFonts.poppins(color: Colors.orange, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
            ),
          ),
          SizedBox(height: 8),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Tính năng xem thêm ưu đãi đang được phát triển.')),
              );
            },
            child: Text('>>Xem thêm ưu đãi tại đây nhé!', style: GoogleFonts.poppins(color: Colors.blue)),
            style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalAndOrderButtonSection(CartProvider cart) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text.rich(
            TextSpan(
              text: 'Bằng việc đặt đơn này, bạn đã đồng ý ',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
              children: [
                TextSpan(
                  text: 'Điều khoản Sử dụng',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.blue, decoration: TextDecoration.underline),
                  recognizer: TapGestureRecognizer()..onTap = () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Điều khoản Sử dụng.')),
                    );
                  },
                ),
                TextSpan(
                  text: ' và ',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                ),
                TextSpan(
                  text: 'Quy chế Hoạt động',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.blue, decoration: TextDecoration.underline),
                  recognizer: TapGestureRecognizer()..onTap = () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Quy chế Hoạt động.')),
                    );
                  },
                ),
                TextSpan(
                  text: ' của chúng tôi',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tổng cộng',
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatCurrency(cart.totalAmount),
                    style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                  if (cart.discountAmount > 0)
                    Text(
                      _formatCurrency(cart.totalAmount + cart.discountAmount),
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey, decoration: TextDecoration.lineThrough),
                    ),
                ],
              ),
            ],
          ),
          SizedBox(height: 10),
          ElevatedButton(
            onPressed: _placeDineInOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
              minimumSize: Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Đặt món',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
