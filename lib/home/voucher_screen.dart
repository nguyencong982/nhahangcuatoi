import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../shared/models.dart';
import '../shared/cart_provider.dart';

class VoucherScreen extends StatefulWidget {
  final String orderType;
  final bool showApplyButton;

  const VoucherScreen({
    super.key,
    required this.orderType,
    this.showApplyButton = true,
  });

  @override
  State<VoucherScreen> createState() => _VoucherScreenState();
}

class _VoucherScreenState extends State<VoucherScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Set<String> _savedVoucherIds = {};
  Set<String> _applyingVoucherIds = {};
  Set<String> _usedVoucherIds = {};

  @override
  void initState() {
    super.initState();
    _loadUsedVouchers();
  }

  Future<void> _loadUsedVouchers() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final snapshot = await _firestore
        .collection("users")
        .doc(user.uid)
        .collection("usedVouchers")
        .get();
    setState(() {
      _usedVoucherIds = snapshot.docs.map((e) => e.id).toSet();
    });
  }

  Future<void> _markVoucherAsUsed(Voucher voucher) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore
        .collection("users")
        .doc(user.uid)
        .collection("usedVouchers")
        .doc(voucher.id)
        .set({
      "voucherId": voucher.id,
      "usedAt": Timestamp.now(),
    });
    setState(() {
      _usedVoucherIds.add(voucher.id);
    });
  }

  Future<void> _handleSaveVoucher(Voucher voucher) async {
    setState(() {
      _savedVoucherIds.add(voucher.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Đã lưu voucher: ${voucher.code}")),
    );
  }

  Future<void> _handleUnsaveVoucher(Voucher voucher) async {
    setState(() {
      _savedVoucherIds.remove(voucher.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Đã hủy lưu voucher: ${voucher.code}")),
    );
  }

  Future<void> _handleApplyVoucher(Voucher voucher) async {
    if (_applyingVoucherIds.contains(voucher.id)) return;
    if (_usedVoucherIds.contains(voucher.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Voucher ${voucher.code} đã được sử dụng.")),
      );
      return;
    }

    setState(() {
      _applyingVoucherIds.add(voucher.id);
    });

    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final bool isApplied = await cartProvider.applyVoucher(voucher);

      if (!mounted) return;

      if (isApplied) {
        await _markVoucherAsUsed(voucher);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Đã áp dụng voucher: ${voucher.code}")),
        );
        Navigator.pop(context, voucher);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Không thể áp dụng voucher.")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _applyingVoucherIds.remove(voucher.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Chọn Voucher")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('vouchers')
            .where('isDeleted', isEqualTo: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Chưa có voucher nào"));
          }

          final vouchers = snapshot.data!.docs
              .map((doc) => Voucher.fromFirestore(doc))
              .where((voucher) => !_usedVoucherIds.contains(voucher.id))
              .where((voucher) {
            final now = DateTime.now();
            final voucherEndDate = voucher.endDate.toDate();

            if (voucherEndDate.isBefore(now)) {
              return false;
            }

            if (widget.orderType == "delivery") {
              return voucher.type == "all" || voucher.type == "delivery";
            } else if (widget.orderType == "dine-in") {
              return voucher.type == "all" || voucher.type == "dine_in";
            }

            return true;
          }).toList();


          if (vouchers.isEmpty) {
            return const Center(child: Text("Bạn đã dùng hết tất cả voucher"));
          }

          return ListView.builder(
            itemCount: vouchers.length,
            itemBuilder: (context, index) {
              final voucher = vouchers[index];
              return Card(
                margin: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.local_offer, color: Colors.deepOrange),
                          const SizedBox(width: 6),
                          Text(
                            voucher.code,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.orange),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              "MÃ GIẢM GIÁ",
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        voucher.description ?? "",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Áp dụng: ${voucher.type ?? "Tất cả hình thức"}",
                        style: const TextStyle(fontSize: 14),
                      ),
                      if (voucher.minOrderAmount != null && voucher.minOrderAmount! > 0)
                        Text(
                          "Đơn tối thiểu: ${voucher.minOrderAmount} đ",
                          style: const TextStyle(fontSize: 14),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        "Hạn sử dụng: ${voucher.endDate.toDate().day}/${voucher.endDate.toDate().month}/${voucher.endDate.toDate().year}",
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.redAccent,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (widget.showApplyButton)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                              ),
                              icon: const Icon(Icons.check_circle,
                                  color: Colors.white),
                              label: const Text("Áp dụng"),
                              onPressed: _applyingVoucherIds.contains(voucher.id)
                                  ? null
                                  : () => _handleApplyVoucher(voucher),
                            ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepOrange,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                            ),
                            icon: Icon(
                              _savedVoucherIds.contains(voucher.id)
                                  ? Icons.bookmark
                                  : Icons.bookmark_add_outlined,
                              color: Colors.white,
                            ),
                            label: Text(
                              _savedVoucherIds.contains(voucher.id)
                                  ? "Đã lưu"
                                  : "Lưu Voucher",
                              style: const TextStyle(color: Colors.white),
                            ),
                            onPressed: () {
                              if (_savedVoucherIds.contains(voucher.id)) {
                                _handleUnsaveVoucher(voucher);
                              } else {
                                _handleSaveVoucher(voucher);
                              }
                            },
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}