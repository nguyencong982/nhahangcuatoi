import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class ReviewInputScreen extends StatefulWidget {
  final String restaurantId;
  final String menuItemId;
  final String menuItemName;
  final String orderId;

  const ReviewInputScreen({
    super.key,
    required this.restaurantId,
    required this.menuItemId,
    required this.menuItemName,
    required this.orderId,
  });

  @override
  State<ReviewInputScreen> createState() => _ReviewInputScreenState();
}

class _ReviewInputScreenState extends State<ReviewInputScreen> {
  double _rating = 0.0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Widget _buildStar(int index) {
    return IconButton(
      icon: Icon(
        index < _rating.round() ? Icons.star : Icons.star_border,
        color: Colors.amber,
        size: 40,
      ),
      onPressed: () {
        setState(() {
          // Gán rating bằng chỉ số + 1 (vì index bắt đầu từ 0)
          _rating = (index + 1).toDouble();
        });
      },
    );
  }

  Future<void> _submitReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Vui lòng đăng nhập để gửi đánh giá.');
      return;
    }
    if (_rating == 0.0) {
      _showSnackBar('Vui lòng chọn số sao đánh giá.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final reviewData = {
        'menuItemId': widget.menuItemId,
        'userId': user.uid,
        'restaurantId': widget.restaurantId,
        'rating': _rating,
        'comment': _commentController.text.trim(),
        'timestamp': Timestamp.now(),
        'orderId': widget.orderId,
      };

      // 1. Lưu đánh giá vào collection 'reviews'
      await FirebaseFirestore.instance.collection('reviews').add(reviewData);

      // 2. Cập nhật trạng thái đánh giá trên món ăn (nếu cần) hoặc order item (tùy chọn)

      _showSnackBar('Cảm ơn bạn đã gửi đánh giá!', color: Colors.green);
      if (mounted) {
        Navigator.of(context).pop();
      }

    } on FirebaseException catch (e) {
      _showSnackBar('Lỗi khi gửi đánh giá: ${e.message}');
    } catch (e) {
      _showSnackBar('Đã xảy ra lỗi: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showSnackBar(String message, {Color color = Colors.red}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: GoogleFonts.poppins()),
          backgroundColor: color,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Đánh giá món ăn', style: GoogleFonts.poppins()),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Đánh giá cho: ${widget.menuItemName}',
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Từ đơn hàng: #${widget.orderId.substring(0, 8)}',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
            ),
            const Divider(height: 30),

            // --- Star Rating Input ---
            Text(
              'Mức độ hài lòng của bạn:',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) => _buildStar(index)),
            ),
            Center(
              child: Text(
                _rating == 0.0 ? 'Chưa chọn' : '$_rating sao',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber),
              ),
            ),
            const SizedBox(height: 30),

            // --- Comment Input ---
            Text(
              'Bình luận (Tùy chọn):',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'Hãy chia sẻ trải nghiệm của bạn về món ăn...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.deepOrange, width: 2),
                ),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 40),

            // --- Submit Button ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _submitReview,
                icon: _isSaving
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.send),
                label: Text(_isSaving ? 'Đang gửi...' : 'Gửi Đánh Giá', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}