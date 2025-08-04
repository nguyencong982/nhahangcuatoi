import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:menufood/shared/models.dart';

class ManagerVoucherScreen extends StatefulWidget {
  const ManagerVoucherScreen({super.key});

  @override
  State<ManagerVoucherScreen> createState() => _ManagerVoucherScreenState();
}

class _ManagerVoucherScreenState extends State<ManagerVoucherScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    const Color commonBackgroundColor = Color(0xFFFCF6E0);
    const Color primaryOrangeColor = Color(0xFFF96E21);

    return Scaffold(
      backgroundColor: commonBackgroundColor,
      appBar: AppBar(
        backgroundColor: commonBackgroundColor,
        elevation: 0,
        title: Text(
          'Quản Lý Voucher',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('vouchers').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: primaryOrangeColor));
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Đã xảy ra lỗi khi tải voucher: ${snapshot.error}',
                style: GoogleFonts.poppins(color: Colors.red),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
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
                    'Hiện chưa có voucher nào.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Hãy thêm voucher đầu tiên của quán!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            );
          }

          final vouchers = snapshot.data!.docs.map((doc) => Voucher.fromFirestore(doc)).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: vouchers.length,
            itemBuilder: (context, index) {
              final voucher = vouchers[index];
              return _VoucherCard(
                voucher: voucher,
                onEdit: () => _showVoucherForm(context, voucher),
                onDelete: () => _confirmDelete(context, voucher),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showVoucherForm(context),
        backgroundColor: primaryOrangeColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showVoucherForm(BuildContext context, [Voucher? voucher]) {
    showDialog(
      context: context,
      builder: (context) {
        return _VoucherFormDialog(voucher: voucher);
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, Voucher voucher) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Xác nhận xóa', style: GoogleFonts.poppins()),
          content: Text(
            'Bạn có chắc chắn muốn xóa voucher "${voucher.code}"?',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Hủy', style: GoogleFonts.poppins(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Xóa', style: GoogleFonts.poppins(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      try {
        await _firestore.collection('vouchers').doc(voucher.id).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã xóa voucher "${voucher.code}"', style: GoogleFonts.poppins()),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi khi xóa voucher: $e', style: GoogleFonts.poppins()),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

class _VoucherCard extends StatelessWidget {
  final Voucher voucher;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _VoucherCard({
    required this.voucher,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    String discountText = '';
    if (voucher.discountType == 'percentage') {
      discountText = 'Giảm ${voucher.discountAmount.toInt()}%';
    } else {
      final formatCurrency = NumberFormat.simpleCurrency(locale: 'vi_VN');
      discountText = 'Giảm ${formatCurrency.format(voucher.discountAmount)}';
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
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
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: onEdit,
                  tooltip: 'Chỉnh sửa',
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: onDelete,
                  tooltip: 'Xóa',
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
              'Hạn sử dụng: ${DateFormat('dd/MM/yyyy').format(voucher.endDate.toDate())}',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.red[400],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoucherFormDialog extends StatefulWidget {
  final Voucher? voucher;

  const _VoucherFormDialog({this.voucher});

  @override
  State<_VoucherFormDialog> createState() => _VoucherFormDialogState();
}

class _VoucherFormDialogState extends State<_VoucherFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _discountAmountController = TextEditingController();
  final _minOrderAmountController = TextEditingController();

  String _discountType = 'percentage';
  bool _isForShipping = false;
  String _type = 'all';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));

  @override
  void initState() {
    super.initState();
    if (widget.voucher != null) {
      _codeController.text = widget.voucher!.code;
      _descriptionController.text = widget.voucher!.description;
      _discountAmountController.text = widget.voucher!.discountAmount.toString();
      _minOrderAmountController.text = widget.voucher!.minOrderAmount?.toString() ?? '';
      _discountType = widget.voucher!.discountType;
      _isForShipping = widget.voucher!.isForShipping;
      _type = widget.voucher!.type;
      _startDate = widget.voucher!.startDate.toDate();
      _endDate = widget.voucher!.endDate.toDate();
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _descriptionController.dispose();
    _discountAmountController.dispose();
    _minOrderAmountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != (isStartDate ? _startDate : _endDate)) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _saveVoucher() async {
    if (_formKey.currentState!.validate()) {
      try {
        final Map<String, dynamic> voucherData = {
          'code': _codeController.text,
          'description': _descriptionController.text,
          'discountType': _discountType,
          'discountAmount': double.tryParse(_discountAmountController.text) ?? 0.0,
          'minOrderAmount': double.tryParse(_minOrderAmountController.text) ?? 0.0,
          'isForShipping': _isForShipping,
          'type': _type,
          'startDate': Timestamp.fromDate(_startDate),
          'endDate': Timestamp.fromDate(_endDate),
        };

        if (widget.voucher == null) {
          await FirebaseFirestore.instance.collection('vouchers').add(voucherData);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Đã thêm voucher mới!', style: GoogleFonts.poppins()), backgroundColor: Colors.green),
            );
          }
        } else {
          await FirebaseFirestore.instance.collection('vouchers').doc(widget.voucher!.id).update(voucherData);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Đã cập nhật voucher!', style: GoogleFonts.poppins()), backgroundColor: Colors.green),
            );
          }
        }
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi khi lưu voucher: $e', style: GoogleFonts.poppins()), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.voucher == null ? 'Thêm Voucher Mới' : 'Chỉnh Sửa Voucher',
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _codeController,
                decoration: InputDecoration(
                  labelText: 'Mã Voucher',
                  labelStyle: GoogleFonts.poppins(),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập mã voucher';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Mô tả',
                  labelStyle: GoogleFonts.poppins(),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập mô tả';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _discountType,
                decoration: InputDecoration(
                  labelText: 'Loại giảm giá',
                  labelStyle: GoogleFonts.poppins(),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'percentage',
                    child: Text('Phần trăm (%)', style: GoogleFonts.poppins()),
                  ),
                  DropdownMenuItem(
                    value: 'fixed',
                    child: Text('Số tiền cố định', style: GoogleFonts.poppins()),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _discountType = value!;
                  });
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _discountAmountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _discountType == 'percentage' ? 'Giá trị giảm giá (%)' : 'Giá trị giảm giá (VNĐ)',
                  labelStyle: GoogleFonts.poppins(),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập giá trị giảm giá';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Vui lòng nhập số hợp lệ';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _minOrderAmountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Đơn hàng tối thiểu (tùy chọn)',
                  labelStyle: GoogleFonts.poppins(),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                title: Text('Áp dụng cho phí ship', style: GoogleFonts.poppins()),
                value: _isForShipping,
                onChanged: (bool value) {
                  setState(() {
                    _isForShipping = value;
                  });
                },
                activeColor: Colors.orange[800],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: InputDecoration(
                  labelText: 'Hình thức áp dụng',
                  labelStyle: GoogleFonts.poppins(),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'all',
                    child: Text('Mọi hình thức', style: GoogleFonts.poppins()),
                  ),
                  DropdownMenuItem(
                    value: 'delivery',
                    child: Text('Đặt món về nhà', style: GoogleFonts.poppins()),
                  ),
                  DropdownMenuItem(
                    value: 'dine_in',
                    child: Text('Ăn tại quán', style: GoogleFonts.poppins()),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _type = value!;
                  });
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => _selectDate(context, true),
                      child: Text(
                        'Ngày bắt đầu: ${DateFormat('dd/MM/yyyy').format(_startDate)}',
                        style: GoogleFonts.poppins(color: Colors.black87),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () => _selectDate(context, false),
                      child: Text(
                        'Ngày kết thúc: ${DateFormat('dd/MM/yyyy').format(_endDate)}',
                        style: GoogleFonts.poppins(color: Colors.black87),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Hủy', style: GoogleFonts.poppins(color: Colors.grey)),
        ),
        TextButton(
          onPressed: _saveVoucher,
          child: Text('Lưu', style: GoogleFonts.poppins(color: Colors.orange[800])),
        ),
      ],
    );
  }
}
