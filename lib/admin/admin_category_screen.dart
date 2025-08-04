import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:menufood/shared/models.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class AdminCategoryScreen extends StatefulWidget {
  const AdminCategoryScreen({super.key});

  @override
  State<AdminCategoryScreen> createState() => _AdminCategoryScreenState();
}

class _AdminCategoryScreenState extends State<AdminCategoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quản lý Danh mục', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('categories').orderBy('order').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'Chưa có danh mục nào.',
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final categories = snapshot.data!.docs.map((doc) => Category.fromFirestore(doc)).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: category.imageUrl.isNotEmpty
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.network(
                      category.imageUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                    ),
                  )
                      : const Icon(Icons.category, size: 40, color: Colors.grey),
                  title: Text(category.name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Thứ tự: ${category.order}', style: GoogleFonts.poppins(color: Colors.grey[700])),
                      Text(
                        'Cho ứng dụng (Giao hàng): ${category.isAvailableForDelivery ? 'Có' : 'Không'}',
                        style: GoogleFonts.poppins(color: Colors.grey[700]),
                      ),
                      Text(
                        'Cho ăn tại quán: ${category.isAvailableForDineIn ? 'Có' : 'Không'}',
                        style: GoogleFonts.poppins(color: Colors.grey[700]),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showCategoryDialog(context, category: category),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDeleteCategory(context, category.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(context),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        tooltip: 'Thêm danh mục mới',
      ),
    );
  }

  void _showCategoryDialog(BuildContext context, {Category? category}) {
    final TextEditingController nameController = TextEditingController(text: category?.name);
    final TextEditingController orderController = TextEditingController(text: category?.order.toString() ?? '0');
    bool isAvailableForDelivery = category?.isAvailableForDelivery ?? true;
    bool isAvailableForDineIn = category?.isAvailableForDineIn ?? true;
    File? _pickedImageFile;
    String? _currentImageUrl = category?.imageUrl;

    bool _isUploadingImage = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            Future<void> _pickImage() async {
              final picker = ImagePicker();
              final pickedFile = await picker.pickImage(source: ImageSource.gallery);

              if (pickedFile != null) {
                setState(() {
                  _pickedImageFile = File(pickedFile.path);
                });
              }
            }

            return AlertDialog(
              title: Text(category == null ? 'Thêm danh mục mới' : 'Chỉnh sửa danh mục'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Tên danh mục'),
                    ),
                    TextField(
                      controller: orderController,
                      decoration: const InputDecoration(labelText: 'Thứ tự hiển thị'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 10),
                    _pickedImageFile != null
                        ? Image.file(_pickedImageFile!, height: 100, width: 100, fit: BoxFit.cover)
                        : (_currentImageUrl != null && _currentImageUrl!.isNotEmpty
                        ? Image.network(_currentImageUrl!, height: 100, width: 100, fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 60, color: Colors.grey))
                        : const Icon(Icons.image, size: 60, color: Colors.grey)),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _isUploadingImage ? null : _pickImage,
                      icon: const Icon(Icons.photo_library),
                      label: Text(_isUploadingImage ? 'Đang tải...' : 'Chọn ảnh danh mục'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text('Cho ứng dụng (Giao hàng):'),
                        Switch(
                          value: isAvailableForDelivery,
                          onChanged: (bool value) {
                            setState(() {
                              isAvailableForDelivery = value;
                            });
                          },
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Text('Cho ăn tại quán:'),
                        Switch(
                          value: isAvailableForDineIn,
                          onChanged: (bool value) {
                            setState(() {
                              isAvailableForDineIn = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: _isUploadingImage ? null : () async {
                    if (nameController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vui lòng nhập tên danh mục.')),
                      );
                      return;
                    }

                    final int? order = int.tryParse(orderController.text);
                    if (order == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Thứ tự hiển thị không hợp lệ.')),
                      );
                      return;
                    }

                    String finalImageUrl = _currentImageUrl ?? '';

                    if (_pickedImageFile != null) {
                      setState(() {
                        _isUploadingImage = true;
                      });
                      try {
                        final String fileName = 'category_images/${DateTime.now().millisecondsSinceEpoch}_${_pickedImageFile!.path.split('/').last}';
                        final uploadTask = _storage.ref().child(fileName).putFile(_pickedImageFile!);
                        final snapshot = await uploadTask.whenComplete(() {});
                        finalImageUrl = await snapshot.ref.getDownloadURL();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã tải ảnh danh mục lên thành công.')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Lỗi khi tải ảnh danh mục lên: $e')),
                        );
                        setState(() {
                          _isUploadingImage = false;
                        });
                        return;
                      } finally {
                        setState(() {
                          _isUploadingImage = false;
                        });
                      }
                    }

                    final newCategory = Category(
                      id: category?.id ?? _firestore.collection('categories').doc().id,
                      name: nameController.text,
                      order: order,
                      isAvailableForDelivery: isAvailableForDelivery,
                      isAvailableForDineIn: isAvailableForDineIn,
                      imageUrl: finalImageUrl, // Save image URL for category
                    );

                    try {
                      if (category == null) {
                        await _firestore.collection('categories').doc(newCategory.id).set(newCategory.toFirestore());
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã thêm danh mục mới.')),
                        );
                      } else {
                        await _firestore.collection('categories').doc(newCategory.id).update(newCategory.toFirestore());
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã cập nhật danh mục.')),
                        );
                      }
                      Navigator.of(ctx).pop();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Lỗi khi lưu danh mục: $e')),
                      );
                    }
                  },
                  child: _isUploadingImage
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(category == null ? 'Thêm' : 'Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteCategory(BuildContext context, String categoryId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa danh mục này không?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _firestore.collection('categories').doc(categoryId).delete();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã xóa danh mục.')),
                );
                Navigator.of(ctx).pop();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Lỗi khi xóa danh mục: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
}
