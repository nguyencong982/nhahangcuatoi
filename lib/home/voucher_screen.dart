import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:menufood/shared/models.dart';

class VoucherCard extends StatelessWidget {
  final Voucher voucher;
  final bool isSaved;
  final VoidCallback onSave;
  final VoidCallback onUnsave;

  const VoucherCard({
    super.key,
    required this.voucher,
    required this.isSaved,
    required this.onSave,
    required this.onUnsave,
  });

  @override
  Widget build(BuildContext context) {
    String discountText = '';
    if (voucher.discountType == 'percentage') {
      discountText = '${voucher.discountAmount.toInt()}% giảm';
    } else {
      final formatCurrency = NumberFormat.simpleCurrency(locale: 'vi_VN', decimalDigits: 0);
      discountText = 'Giảm ${formatCurrency.format(voucher.discountAmount)}';
    }

    String voucherType = '';
    if (voucher.isForShipping) {
      voucherType = 'Voucher phí ship';
    } else if (voucher.type == 'delivery') {
      voucherType = 'Chỉ áp dụng cho đặt món về nhà';
    } else if (voucher.type == 'dine_in') {
      voucherType = 'Chỉ áp dụng cho ăn tại quán';
    } else {
      voucherType = 'Áp dụng cho mọi hình thức';
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            colors: [
              Colors.orange[100]!,
              Colors.orange[50]!,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.local_offer, color: Colors.orange[800], size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      voucher.code,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[800],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange[300]!),
                    ),
                    child: Text(
                      'MÃ GIẢM GIÁ',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange[700],
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.black26, height: 20),
              Text(
                voucher.description,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Ưu đãi: $discountText',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[800],
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Áp dụng: $voucherType',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              if (voucher.minOrderAmount != null && voucher.minOrderAmount! > 0)
                Text(
                  'Đơn tối thiểu: ${NumberFormat.simpleCurrency(locale: 'vi_VN', decimalDigits: 0).format(voucher.minOrderAmount)}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              const SizedBox(height: 10),
              Text(
                'Hạn sử dụng: ${DateFormat('dd/MM/yyyy').format(voucher.endDate.toDate())}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.red[400],
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: isSaved
                    ? ElevatedButton.icon(
                  onPressed: onUnsave,
                  icon: const Icon(Icons.bookmark_added, color: Colors.white),
                  label: Text('Đã Lưu', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                )
                    : ElevatedButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.bookmark_add, color: Colors.white),
                  label: Text('Lưu Voucher', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class VoucherScreen extends StatefulWidget {
  const VoucherScreen({super.key});

  @override
  State<VoucherScreen> createState() => _VoucherScreenState();
}

class _VoucherScreenState extends State<VoucherScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Voucher> _vouchers = [];
  Set<String> _savedVoucherIds = {};
  bool _isLoading = true;
  String? _userId;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _auth.authStateChanges().listen((User? user) {
      setState(() {
        _userId = user?.uid;
      });
      if (_userId != null) {
        _setupVoucherListeners();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Bạn cần đăng nhập để xem và lưu voucher.';
        });
      }
    });
  }

  void _setupVoucherListeners() {
    final now = Timestamp.now();
    final voucherCollection = _firestore.collection('vouchers');

    voucherCollection
        .where('endDate', isGreaterThanOrEqualTo: now)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _vouchers = snapshot.docs
            .map((doc) => Voucher.fromFirestore(doc))
            .where((voucher) => voucher.startDate.toDate().isBefore(now.toDate()))
            .toList();
        _isLoading = false;
        _errorMessage = '';
      });
    }, onError: (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Đã xảy ra lỗi khi tải voucher: $e';
      });
      print('Error fetching vouchers: $e');
    });

    if (_userId != null) {
      final userVoucherCollection = _firestore.collection('users').doc(_userId).collection('userVouchers');
      userVoucherCollection.snapshots().listen((snapshot) {
        setState(() {
          _savedVoucherIds = snapshot.docs.map((doc) => doc.id).toSet();
        });
      }, onError: (e) {
        print('Error fetching saved vouchers: $e');
      });
    }
  }

  Future<void> _saveVoucher(Voucher voucher) async {
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn cần đăng nhập để lưu voucher.')),
      );
      return;
    }
    try {
      final userVoucherRef = _firestore.collection('users').doc(_userId).collection('userVouchers').doc(voucher.id);
      await userVoucherRef.set(voucher.toFirestore());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu voucher thành công!')),
      );
    } catch (e) {
      print('Lỗi khi lưu voucher: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể lưu voucher: $e')),
      );
    }
  }

  Future<void> _deleteVoucher(Voucher voucher) async {
    if (_userId == null) return;
    try {
      final userVoucherRef = _firestore.collection('users').doc(_userId).collection('userVouchers').doc(voucher.id);
      await userVoucherRef.delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa voucher khỏi danh sách đã lưu.')),
      );
    } catch (e) {
      print('Lỗi khi xóa voucher: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể xóa voucher: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color commonBackgroundColor = Color(0xFFFCF6E0);

    return Scaffold(
      backgroundColor: commonBackgroundColor,
      appBar: AppBar(
        backgroundColor: commonBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          'Voucher Của Quán',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.red,
            ),
          ),
        ),
      )
          : _vouchers.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.discount,
              size: 100,
              color: Colors.orange[400],
            ),
            const SizedBox(height: 20),
            Text(
              'Hiện không có voucher nào khả dụng.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Hãy quay lại sau để xem các ưu đãi mới nhé!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _vouchers.length,
        itemBuilder: (context, index) {
          final voucher = _vouchers[index];
          final bool isSaved = _savedVoucherIds.contains(voucher.id);
          return VoucherCard(
            voucher: voucher,
            isSaved: isSaved,
            onSave: () => _saveVoucher(voucher),
            onUnsave: () => _deleteVoucher(voucher),
          );
        },
      ),
    );
  }
}
