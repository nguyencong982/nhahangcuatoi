import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:menufood/shared/cart_provider.dart';
import 'package:menufood/shared/models.dart';
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart';
import 'package:menufood/orders/address_selection_screen.dart';
import 'package:menufood/home/voucher_screen.dart';

class CartScreen extends StatefulWidget {
  final String restaurantId;
  final String? tableNumber;

  const CartScreen({super.key, required this.restaurantId, this.tableNumber});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  Restaurant? _currentRestaurant;
  bool _isLoadingRestaurant = true;
  final TextEditingController _customerNotesController = TextEditingController();
  final TextEditingController _deliveryAddressController = TextEditingController();
  final TextEditingController _floorUnitController = TextEditingController();

  final Map<String, double> _deliveryFees = {
    'priority': 22000,
    'fast': 14000,
    'economical': 11000,
  };

  final String _orderType = 'delivery';

  @override
  void initState() {
    super.initState();
    _fetchRestaurantDetails();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      cartProvider.setRestaurantAndTable(widget.restaurantId, widget.tableNumber);
      _customerNotesController.text = cartProvider.customerNotes ?? '';
      _deliveryAddressController.text = cartProvider.deliveryAddress ?? '';
    });
  }

  @override
  void dispose() {
    _customerNotesController.dispose();
    _deliveryAddressController.dispose();
    _floorUnitController.dispose();
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
    TextEditingController notesController = TextEditingController(text: cartItem.notes);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Thêm ghi chú cho ${cartItem.item.name}'),
        content: TextField(
          controller: notesController,
          decoration: const InputDecoration(hintText: 'Ví dụ: Ít đường, không đá...'),
          maxLines: 3,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Provider.of<CartProvider>(context, listen: false)
                  .updateItemNotes(cartItem.item.id, notesController.text);
              Navigator.of(ctx).pop();
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _showAddressSelectionScreen(CartProvider cart) async {
    final selectedAddress = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddressSelectionScreen(
          initialAddress: cart.deliveryAddress,
        ),
      ),
    );
    if (selectedAddress != null && selectedAddress is String) {
      setState(() {
        _deliveryAddressController.text = selectedAddress;
        cart.setDeliveryAddress(selectedAddress);
      });
    }
  }

  Future<void> _showVoucherSelectionDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để xem voucher.')),
      );
      return;
    }

    final savedVouchersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('userVouchers')
        .get();

    final List<Voucher> savedVouchers = savedVouchersSnapshot.docs
        .map((doc) => Voucher.fromFirestore(doc))
        .toList();

    final List<Voucher> applicableVouchers = savedVouchers.where((voucher) {
      if (voucher.isForShipping && _orderType != 'delivery') {
        return false;
      }
      if (voucher.type != 'all' && voucher.type != _orderType) {
        return false;
      }
      return true;
    }).toList();

    if (applicableVouchers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn chưa có voucher nào phù hợp với đơn hàng này.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        final cartProvider = Provider.of<CartProvider>(ctx);
        return AlertDialog(
          title: Text('Chọn Voucher', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: applicableVouchers.length,
              itemBuilder: (context, index) {
                final voucher = applicableVouchers[index];
                final bool canApply = cartProvider.checkVoucherValidity(voucher);
                return ListTile(
                  title: Text(voucher.code, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  subtitle: Text(voucher.description, style: GoogleFonts.poppins(color: Colors.grey[600])),
                  trailing: ElevatedButton(
                    onPressed: canApply
                        ? () {
                      cartProvider.applyVoucher(voucher);
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã áp dụng voucher thành công!')),
                      );
                    }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canApply ? Colors.orange : Colors.grey,
                    ),
                    child: Text(
                      'Áp dụng',
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Đóng', style: GoogleFonts.poppins()),
            ),
          ],
        );
      },
    );
  }

  Future<void> _placeOrder() async {
    final cart = Provider.of<CartProvider>(context, listen: false);
    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Giỏ hàng của bạn đang trống!')),
      );
      return;
    }

    if (cart.selectedDeliveryOption == null || cart.deliveryAddress == null || cart.deliveryAddress!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn tùy chọn giao hàng và nhập địa chỉ.')),
      );
      return;
    }

    try {
      await cart.placeOrder(
        customerNotes: _customerNotesController.text.isEmpty ? null : _customerNotesController.text,
        orderType: _orderType,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đơn hàng của bạn đã được đặt thành công!')),
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi đặt hàng: ${e.toString()}')),
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
    const String orderTypeDisplay = 'Giao hàng';

    return Scaffold(
      appBar: AppBar(
        title: Text('Xác nhận đơn món', style: GoogleFonts.poppins()),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: _isLoadingRestaurant
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Container(
                  color: Colors.orange[50],
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.delivery_dining, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(orderTypeDisplay, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.orange)),
                    ],
                  ),
                ),
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
                _buildDeliveryInfoSection(cart),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tính năng "Thêm món" đang được phát triển.')),
                  );
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
                        onPressed: () => cart.removeItem(cartItem.item.id),
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
          _buildSummaryRow('Phí áp dụng', _formatCurrency(cart.deliveryFee)),
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

  Widget _buildDeliveryInfoSection(CartProvider cart) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vui lòng đảm bảo địa chỉ giao hàng chính xác',
            style: GoogleFonts.poppins(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.location_on, color: Colors.red),
            title: Flexible(
              child: Text(
                cart.deliveryAddress == null || (cart.deliveryAddress?.isEmpty ?? true)
                    ? 'Chạm để nhập địa chỉ hoặc định vị'
                    : cart.deliveryAddress!,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: cart.deliveryAddress == null || (cart.deliveryAddress?.isEmpty ?? true)
                      ? Colors.grey
                      : Colors.black,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            onTap: () => _showAddressSelectionScreen(cart),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _floorUnitController,
                  decoration: const InputDecoration(
                    labelText: 'Số tầng / căn hộ',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    print('Số tầng/căn hộ: $value');
                  },
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tính năng hỗ trợ tài xế đang được phát triển.')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Hỗ trợ tài xế giao hàng', style: GoogleFonts.poppins()),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tính năng thêm hướng dẫn đang được phát triển.')),
                  );
                },
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Thêm', style: GoogleFonts.poppins(color: Colors.blue)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Tùy chọn giao hàng', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
          _buildDeliveryOptionTile(
            'Ưu tiên',
            '< 25 phút',
            _deliveryFees['priority']!,
            'priority',
            cart,
            Icons.star,
          ),
          _buildDeliveryOptionTile(
            'Nhanh',
            '25 phút',
            _deliveryFees['fast']!,
            'fast',
            cart,
            Icons.directions_bike,
          ),
          _buildDeliveryOptionTile(
            'Tiết kiệm',
            '40 phút',
            _deliveryFees['economical']!,
            'economical',
            cart,
            Icons.wallet_travel,
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryOptionTile(
      String title,
      String subtitle,
      double fee,
      String value,
      CartProvider cart,
      IconData icon, {
        bool showPrice = true,
      }) {
    return RadioListTile<String>(
      controlAffinity: ListTileControlAffinity.trailing,
      activeColor: Colors.green,
      title: Row(
        children: [
          Icon(icon, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Flexible(
            child: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis,),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(width: 5),
            Flexible(
              child: Text('• $subtitle', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis,),
            ),
            const SizedBox(width: 5),
            const Icon(Icons.info_outline, size: 16, color: Colors.grey),
          ],
        ],
      ),
      secondary: showPrice
          ? FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          _formatCurrency(fee),
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          maxLines: 1,
        ),
      )
          : null,
      value: value,
      groupValue: cart.selectedDeliveryOption,
      onChanged: (selectedOption) {
        if (selectedOption != null) {
          cart.setDeliveryOption(selectedOption, fee);
        }
      },
    );
  }

  Widget _buildPaymentInfoSection(CartProvider cart) {
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
              Flexible(
                child: Text('Thông tin thanh toán', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis,),
              ),
              TextButton(onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tính năng xem tất cả phương thức thanh toán đang được phát triển.')),
                );
              }, child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Xem tất cả', style: GoogleFonts.poppins(color: Colors.green)),
              )),
            ],
          ),
          ListTile(
            leading: const Icon(Icons.credit_card, color: Colors.blue),
            title: Text('Thẻ', style: GoogleFonts.poppins()),
            trailing: cart.paymentMethod == 'card'
                ? const Icon(Icons.check_circle, color: Colors.green)
                : FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('Đề xuất', style: GoogleFonts.poppins(color: Colors.grey)),
            ),
            onTap: () => cart.setPaymentMethod('card'),
          ),
          ListTile(
            leading: const Icon(Icons.money, color: Colors.green),
            title: Text('Tiền mặt', style: GoogleFonts.poppins()),
            trailing: cart.paymentMethod == 'cash'
                ? const Icon(Icons.check_circle, color: Colors.green)
                : null,
            onTap: () => cart.setPaymentMethod('cash'),
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
              onTap: _showVoucherSelectionDialog,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const VoucherScreen()),
              );
            },
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('>>Xem thêm ưu đãi tại đây nhé!', style: GoogleFonts.poppins(color: Colors.blue)),
            ),
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
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tổng cộng',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _formatCurrency(cart.totalAmount),
                        style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange),
                        maxLines: 1,
                      ),
                    ),
                    if (cart.discountAmount > 0)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _formatCurrency(cart.subtotalAmount + cart.deliveryFee),
                          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey, decoration: TextDecoration.lineThrough),
                          maxLines: 1,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _placeOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Đặt đơn',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
