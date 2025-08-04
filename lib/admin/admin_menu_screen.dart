import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:menufood/shared/models.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class AdminMenuScreen extends StatefulWidget {
  const AdminMenuScreen({super.key});

  @override
  State<AdminMenuScreen> createState() => _AdminMenuScreenState();
}

class _AdminMenuScreenState extends State<AdminMenuScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quản lý Menu', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('menuItems').orderBy('name').snapshots(),
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
                'Chưa có món ăn nào trong menu.',
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final menuItems = snapshot.data!.docs.map((doc) => MenuItem.fromFirestore(doc)).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: menuItems.length,
            itemBuilder: (context, index) {
              final item = menuItems[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: item.imageUrl.isNotEmpty
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.network(
                      item.imageUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                    ),
                  )
                      : const Icon(Icons.fastfood, size: 40, color: Colors.grey),
                  title: Text(item.name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  subtitle: FutureBuilder<DocumentSnapshot>(
                    future: _firestore.collection('categories').doc(item.categoryId).get(),
                    builder: (context, categorySnapshot) {
                      String categoryName = 'Đang tải...';
                      if (categorySnapshot.connectionState == ConnectionState.done && categorySnapshot.hasData && categorySnapshot.data!.exists) {
                        categoryName = Category.fromFirestore(categorySnapshot.data!).name;
                      } else if (categorySnapshot.hasError) {
                        categoryName = 'Lỗi danh mục';
                      }
                      return Text(
                        '${item.description ?? 'Không mô tả'}\n${item.price.toStringAsFixed(0)} VNĐ - Danh mục: $categoryName',
                        style: GoogleFonts.poppins(color: Colors.grey[700]),
                      );
                    },
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showMenuItemDialog(context, item: item),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDeleteMenuItem(context, item.id),
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
        onPressed: () => _showMenuItemDialog(context),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        tooltip: 'Thêm món ăn mới',
      ),
    );
  }

  void _showMenuItemDialog(BuildContext context, {MenuItem? item}) {
    final TextEditingController nameController = TextEditingController(text: item?.name);
    final TextEditingController descriptionController = TextEditingController(text: item?.description);
    final TextEditingController priceController = TextEditingController(text: item?.price.toString());
    String? selectedCategoryId = item?.categoryId;
    File? _pickedImageFile;
    String? _currentImageUrl = item?.imageUrl;

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
              title: Text(item == null ? 'Thêm món ăn mới' : 'Chỉnh sửa món ăn'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Tên món ăn'),
                    ),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: 'Mô tả'),
                      maxLines: 3,
                    ),
                    TextField(
                      controller: priceController,
                      decoration: const InputDecoration(labelText: 'Giá (VNĐ)'),
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
                      label: Text(_isUploadingImage ? 'Đang tải...' : 'Chọn ảnh từ thư viện'),
                    ),
                    const SizedBox(height: 10),
                    StreamBuilder<QuerySnapshot>(
                      stream: _firestore.collection('categories').orderBy('order').snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        }
                        if (snapshot.hasError) {
                          return Text('Lỗi tải danh mục: ${snapshot.error}');
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Text('Không có danh mục nào.');
                        }

                        final categories = snapshot.data!.docs.map((doc) => Category.fromFirestore(doc)).toList();

                        return DropdownButtonFormField<String>(
                          value: selectedCategoryId,
                          hint: const Text('Chọn danh mục'),
                          items: categories.map<DropdownMenuItem<String>>((Category category) {
                            return DropdownMenuItem<String>(
                              value: category.id,
                              child: Text(category.name),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedCategoryId = newValue;
                            });
                          },
                        );
                      },
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
                    if (nameController.text.isEmpty ||
                        priceController.text.isEmpty ||
                        selectedCategoryId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin bắt buộc.')),
                      );
                      return;
                    }

                    final double? price = double.tryParse(priceController.text);
                    if (price == null || price <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Giá không hợp lệ.')),
                      );
                      return;
                    }

                    String finalImageUrl = _currentImageUrl ?? '';

                    if (_pickedImageFile != null) {
                      setState(() {
                        _isUploadingImage = true;
                      });
                      try {
                        final String fileName = 'menu_images/${DateTime.now().millisecondsSinceEpoch}_${_pickedImageFile!.path.split('/').last}';
                        final uploadTask = _storage.ref().child(fileName).putFile(_pickedImageFile!);
                        final snapshot = await uploadTask.whenComplete(() {});
                        finalImageUrl = await snapshot.ref.getDownloadURL();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã tải ảnh lên thành công.')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Lỗi khi tải ảnh lên: $e')),
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

                    final newMenuItem = MenuItem(
                      id: item?.id ?? _firestore.collection('menuItems').doc().id,
                      name: nameController.text,
                      description: descriptionController.text.isEmpty ? null : descriptionController.text,
                      price: price,
                      imageUrl: finalImageUrl,
                      categoryId: selectedCategoryId!,
                      isAvailable: item?.isAvailable ?? true,
                      order: item?.order ?? 0,
                    );

                    try {
                      if (item == null) {
                        await _firestore.collection('menuItems').doc(newMenuItem.id).set(newMenuItem.toFirestore());
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã thêm món ăn mới.')),
                        );
                      } else {
                        await _firestore.collection('menuItems').doc(newMenuItem.id).update(newMenuItem.toFirestore());
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã cập nhật món ăn.')),
                        );
                      }
                      Navigator.of(ctx).pop();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Lỗi khi lưu món ăn: $e')),
                      );
                    }
                  },
                  child: _isUploadingImage
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(item == null ? 'Thêm' : 'Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Xác nhận xóa món ăn
  void _confirmDeleteMenuItem(BuildContext context, String itemId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa món ăn này không?'),
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
                await _firestore.collection('menuItems').doc(itemId).delete();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã xóa món ăn.')),
                );
                Navigator.of(ctx).pop();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Lỗi khi xóa món ăn: $e')),
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

extension StringExtension on String {
  String toCapitalized() {
    return split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }
}
