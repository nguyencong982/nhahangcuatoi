import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:menufood/shared/cart_provider.dart';
import 'package:menufood/shared/models.dart';
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart';
import 'package:menufood/orders/order_tracking_screen.dart';
import 'package:menufood/home/voucher_screen.dart';

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
  String? _currentUserName;
  TextEditingController _customerNotesController = TextEditingController();

  static const String _staticQrPath = 'assets/images/img.png';

  @override
  void initState() {
    super.initState();
    _fetchRestaurantDetails();
    _fetchCustomerName();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      cartProvider.setRestaurantAndTableForDineIn(widget.restaurantId, widget.tableNumber);
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
      }
    } catch (e) {
      setState(() {
        _isLoadingRestaurant = false;
      });
    }
  }

  Future<void> _fetchCustomerName() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (doc.exists) {
        setState(() {
          _currentUserName = doc.data()?['fullName'] as String?;
        });
      }
    } catch (e) {}
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

  void _showStaticQrPaymentDialog(String orderId, double amount) {
    final currencyFormatter = NumberFormat('#,##0', 'vi_VN');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('Thanh toán Chuyển khoản', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                _staticQrPath,
                width: 200,
                height: 200,
                errorBuilder: (context, error, stackTrace) => Icon(Icons.qr_code_2_outlined, size: 200, color: Colors.grey),
              ),
              const SizedBox(height: 15),
              Text(
                'Tổng tiền cần chuyển:',
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[700]),
              ),
              Text(
                '${currencyFormatter.format(amount)} VNĐ',
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepOrange),
              ),
              const SizedBox(height: 10),
              Text(
                'NỘI DUNG CHUYỂN KHOẢN BẮT BUỘC:',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(5)
                ),
                child: SelectableText(
                  'MENUFOOD $orderId',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red[800]),
                ),
              ),
              const SizedBox(height: 15),
              Text(
                'Lưu ý: Nhân viên sẽ kiểm tra sao kê để xác nhận giao dịch. Vui lòng thanh toán chính xác số tiền và nội dung trên.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => OrderTrackingScreen(orderId: orderId),
                ),
              );
            },
            child: Text('Đã Thanh Toán/Đóng', style: GoogleFonts.poppins(color: Colors.green, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _placeDineInOrder() async {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Giỏ hàng của bạn đang trống!')),
      );
      return;
    }

    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lỗi xác thực người dùng. Vui lòng đăng nhập lại.')),
      );
      return;
    }

    final selectedPaymentMethod = cart.paymentMethod;

    if (selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn phương thức thanh toán để tiếp tục đặt món.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String initialPaymentStatus;
    if (selectedPaymentMethod == 'qr_static') {
      initialPaymentStatus = 'awaiting_payment';
    } else {
      initialPaymentStatus = 'unpaid';
    }

    try {
      final String? orderId = await cart.placeOrder(
        customerNotes: _customerNotesController.text.isEmpty ? null : _customerNotesController.text,
        orderType: 'dine_in',
        customerId: currentUserId,
        customerName: _currentUserName ?? 'Khách hàng',
        paymentStatus: initialPaymentStatus,
      );

      if (orderId != null) {
        if (context.mounted) {
          if (selectedPaymentMethod == 'qr_static') {
            _showStaticQrPaymentDialog(orderId, cart.totalAmount);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Món của bạn đã được đặt thành công! Vui lòng thanh toán khi kết thúc.')),
            );
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => OrderTrackingScreen(orderId: orderId),
              ),
            );
          }
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
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: const BoxDecoration(
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
                const SizedBox(height: 10),
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
                const SizedBox(height: 10),

                _buildPaymentInfoSection(cart),
                const SizedBox(height: 10),

                _buildPromotionsSection(cart),
                const SizedBox(height: 10),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TextField(
                    controller: _customerNotesController,
                    decoration: InputDecoration(
                      labelText: 'Ghi chú cho nhà hàng (tùy chọn)',
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(Icons.note_add, color: Colors.grey[600]),
                    ),
                    maxLines: 2,
                    onChanged: (value) {
                      Provider.of<CartProvider>(context, listen: false).setCustomerNotes(value);
                    },
                  ),
                ),
                const SizedBox(height: 10),
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
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      padding: const EdgeInsets.all(16.0),
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
                  // Logic hiện tại
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
                      const SizedBox(width: 10),
                      if (cartItem.item.imageUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: Image.network(
                            cartItem.item.imageUrl,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 60, color: Colors.grey),
                          ),
                        ),
                      const SizedBox(width: 10),
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
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () {
                          cart.removeItem(cartItem.item.id);
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, indent: 40, endIndent: 10),
              ],
            );
          }).toList(),
          const SizedBox(height: 10),
          _buildSummaryRow('Tổng tạm tính', _formatCurrency(cart.subtotalAmount)),
          if (cart.discountAmount > 0)
            _buildSummaryRow('Giảm giá', '-${_formatCurrency(cart.discountAmount)}'),
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
                const SnackBar(content: Text('Tính năng yêu cầu dụng cụ ăn uống đang được phát triển.')),
              );
            },
            activeColor: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentInfoSection(CartProvider cart) {
    final selectedIcon = const Icon(Icons.check_circle, color: Colors.green);
    final unselectedIcon = const Icon(Icons.circle_outlined, color: Colors.grey);

    return Container(
      decoration: const BoxDecoration(
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
                  const SnackBar(content: Text('Tính năng xem tất cả phương thức thanh toán đang được phát triển.')),
                );
              }, child: Text('Xem tất cả', style: GoogleFonts.poppins(color: Colors.green))),
            ],
          ),
          ListTile(
            leading: const Icon(Icons.money, color: Colors.green),
            title: Text('Tiền mặt (vui lòng thanh toán tại quầy!)', style: GoogleFonts.poppins()),
            trailing: cart.paymentMethod == 'cash'
                ? selectedIcon
                : unselectedIcon,
            onTap: () {
              cart.setPaymentMethod('cash');
            },
          ),
          ListTile(
            leading: const Icon(Icons.credit_card, color: Colors.blue),
            title: Text('Thẻ/Ví (vui lòng thanh toán tại quầy!)', style: GoogleFonts.poppins()),
            trailing: cart.paymentMethod == 'pos'
                ? selectedIcon
                : unselectedIcon,
            onTap: () {
              cart.setPaymentMethod('pos');
            },
          ),
          ListTile(
            leading: const Icon(Icons.qr_code_2, color: Colors.deepOrange),
            title: Text('Chuyển khoản (Quét QR)', style: GoogleFonts.poppins()),
            trailing: cart.paymentMethod == 'qr_static'
                ? selectedIcon
                : unselectedIcon,
            onTap: () {
              cart.setPaymentMethod('qr_static');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPromotionsSection(CartProvider cart) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ưu đãi', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          if (cart.appliedVoucher != null)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.lightGreen[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Đã áp dụng: ${cart.appliedVoucher!.code}',
                      style: GoogleFonts.poppins(color: Colors.green, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: cart.removeVoucher,
                    child: Text('Hủy', style: GoogleFonts.poppins(color: Colors.red)),
                  )
                ],
              ),
            )
          else
            GestureDetector(
              onTap: () async {
                final selectedVoucher = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const VoucherScreen(
                      orderType: "dine-in",
                    ),
                  ),
                );
                if (selectedVoucher != null && selectedVoucher is Voucher) {
                  final cartProvider = Provider.of<CartProvider>(context, listen: false);
                  await cartProvider.applyVoucher(selectedVoucher);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Đã áp dụng voucher ${selectedVoucher.code} thành công!')),
                    );
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_offer, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Áp dụng ưu đãi để được giảm giá',
                        style: GoogleFonts.poppins(color: Colors.orange, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  ],
                ),
              ),
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
            offset: const Offset(0, -5),
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
                      const SnackBar(content: Text('Điều khoản Sử dụng.')),
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
                      const SnackBar(content: Text('Quy chế Hoạt động.')),
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
          const SizedBox(height: 10),

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
                      _formatCurrency(cart.subtotalAmount),
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey, decoration: TextDecoration.lineThrough),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: cart.items.isEmpty ? null : _placeDineInOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
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