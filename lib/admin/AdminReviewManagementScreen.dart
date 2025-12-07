import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:menufood/shared/models.dart';

class AdminReviewManagementScreen extends StatefulWidget {
  const AdminReviewManagementScreen({super.key});

  @override
  State<AdminReviewManagementScreen> createState() => _AdminReviewManagementScreenState();
}

class _AdminReviewManagementScreenState extends State<AdminReviewManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedEntityType = 'all';
  TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Query _buildQuery() {
    Query query = _firestore.collection('reviews').orderBy('timestamp', descending: true);

    if (_selectedEntityType != 'all') {
      query = query.where('entityType', isEqualTo: _selectedEntityType);
    }

    return query;
  }

  void _deleteReview(String reviewId) async {
    try {
      await _firestore.collection('reviews').doc(reviewId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã xóa đánh giá $reviewId thành công.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi xóa đánh giá: $e')),
      );
    }
  }

  void _editComment(Review review) {
    TextEditingController commentController = TextEditingController(text: review.comment);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Chỉnh sửa Bình luận', style: GoogleFonts.poppins()),
          content: TextField(
            controller: commentController,
            maxLines: 3,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                _updateReviewComment(review.id, commentController.text.trim());
                Navigator.of(context).pop();
              },
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );
  }

  void _updateReviewComment(String reviewId, String newComment) async {
    try {
      await _firestore.collection('reviews').doc(reviewId).update({
        'comment': newComment,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã cập nhật bình luận thành công.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi cập nhật bình luận: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quản Lý Đánh Giá', style: GoogleFonts.poppins()),
        backgroundColor: Colors.deepOrange,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm theo nội dung, tên...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedEntityType,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Tất cả')),
                    DropdownMenuItem(value: 'restaurant', child: Text('Nhà hàng')),
                    DropdownMenuItem(value: 'shipper', child: Text('Shipper')),
                    DropdownMenuItem(value: 'menuItem', child: Text('Món ăn')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedEntityType = value!;
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildQuery().snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text('Không có đánh giá nào.', style: GoogleFonts.poppins(color: Colors.grey)),
                  );
                }

                final filteredReviews = snapshot.data!.docs.map((doc) => Review.fromFirestore(doc)).where((review) {
                  final reviewText = '${review.userName} ${review.comment ?? ''} món_ăn'.toLowerCase();
                  return reviewText.contains(_searchText);
                }).toList();

                if (filteredReviews.isEmpty) {
                  return Center(
                    child: Text('Không tìm thấy đánh giá nào phù hợp.', style: GoogleFonts.poppins(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  itemCount: filteredReviews.length,
                  itemBuilder: (context, index) {
                    final review = filteredReviews[index];
                    return _buildReviewCard(review);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Review review) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  review.userName,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 18),
                    Text(
                      review.rating.toStringAsFixed(1),
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),

            Text(
              'Đối tượng: Món ăn (ID: ${review.menuItemId})',
              style: GoogleFonts.poppins(color: Colors.blueGrey, fontSize: 12),
            ),
            const SizedBox(height: 8),

            Text(
              review.comment ?? 'Không có bình luận',
              style: GoogleFonts.poppins(fontSize: 14, fontStyle: review.comment == null ? FontStyle.italic : null),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            Text(
              'Thời gian: ${DateFormat('dd/MM/yyyy HH:mm').format(review.timestamp.toDate())}',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
            ),

            const Divider(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Sửa BL'),
                  onPressed: () => _editComment(review),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Xóa'),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Xác nhận xóa'),
                        content: Text('Bạn có chắc chắn muốn xóa đánh giá của ${review.userName} không?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Hủy')),
                          ElevatedButton(
                            onPressed: () {
                              _deleteReview(review.id);
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}