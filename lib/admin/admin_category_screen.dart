import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:menufood/shared/models.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:menufood/admin/AdminRestaurantSelectorScreen.dart';

class AdminCategoryScreen extends StatefulWidget {
  const AdminCategoryScreen({super.key});

  @override
  State<AdminCategoryScreen> createState() => _AdminCategoryScreenState();
}

class _AdminCategoryScreenState extends State<AdminCategoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Restaurant? _selectedRestaurant;

  Future<void> _selectRestaurant() async {
    final selected = await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => const AdminRestaurantSelectorScreen(
              purposeText: 'tạo Danh mục',
            ),
      ),
    );

    if (selected != null && selected is Restaurant) {
      setState(() {
        _selectedRestaurant = selected;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _selectRestaurant();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedRestaurant == null
              ? 'Quản lý Danh mục (Chưa chọn quán)'
              : 'Danh mục: ${_selectedRestaurant!.name}',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.restaurant_menu),
            onPressed: _selectRestaurant,
            tooltip: 'Chọn Nhà hàng khác',
          ),
        ],
      ),
      body:
          _selectedRestaurant == null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Vui lòng chọn một nhà hàng để quản lý danh mục.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _selectRestaurant,
                        icon: const Icon(Icons.map),
                        label: Text(
                          'Chọn Nhà Hàng',
                          style: GoogleFonts.poppins(),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              : StreamBuilder<QuerySnapshot>(
                stream:
                    _firestore
                        .collection('restaurants')
                        .doc(_selectedRestaurant!.id)
                        .collection('categories')
                        .orderBy('order')
                        .snapshots(),
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
                        'Chưa có danh mục nào cho quán này.',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  }

                  final categories =
                      snapshot.data!.docs
                          .map((doc) => Category.fromFirestore(doc))
                          .toList();

                  return ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          leading:
                              category.imageUrl.isNotEmpty
                                  ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8.0),
                                    child: Image.network(
                                      category.imageUrl,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(
                                                Icons.broken_image,
                                                size: 40,
                                                color: Colors.grey,
                                              ),
                                    ),
                                  )
                                  : const Icon(
                                    Icons.category,
                                    size: 40,
                                    color: Colors.grey,
                                  ),
                          title: Text(
                            category.name,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Thứ tự: ${category.order}',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey[700],
                                ),
                              ),
                              Text(
                                'Cho ứng dụng (Giao hàng): ${category.isAvailableForDelivery ? 'Có' : 'Không'}',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey[700],
                                ),
                              ),
                              Text(
                                'Cho ăn tại quán: ${category.isAvailableForDineIn ? 'Có' : 'Không'}',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                ),
                                onPressed:
                                    () => _showCategoryDialog(
                                      context,
                                      category: category,
                                    ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed:
                                    () => _confirmDeleteCategory(
                                      context,
                                      category.id,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
      floatingActionButton:
          _selectedRestaurant != null
              ? FloatingActionButton(
                onPressed: () => _showCategoryDialog(context),
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                child: const Icon(Icons.add),
                tooltip: 'Thêm danh mục mới',
              )
              : null,
    );
  }

  void _showCategoryDialog(BuildContext context, {Category? category}) {
    if (_selectedRestaurant == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn nhà hàng trước khi thêm danh mục.'),
        ),
      );
      return;
    }

    final TextEditingController nameController = TextEditingController(
      text: category?.name,
    );
    final TextEditingController orderController = TextEditingController(
      text: category?.order.toString() ?? '0',
    );
    bool isAvailableForDelivery = category?.isAvailableForDelivery ?? true;
    bool isAvailableForDineIn = category?.isAvailableForDineIn ?? true;
    File? pickedImageFile;
    String? currentImageUrl = category?.imageUrl;
    bool isUploadingImage = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            Future<void> pickImage() async {
              final picker = ImagePicker();
              final pickedFile = await picker.pickImage(
                source: ImageSource.gallery,
              );

              if (pickedFile != null) {
                setState(() {
                  pickedImageFile = File(pickedFile.path);
                });
              }
            }

            return AlertDialog(
              title: Text(
                category == null ? 'Thêm danh mục mới' : 'Chỉnh sửa danh mục',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Tên danh mục',
                      ),
                    ),
                    TextField(
                      controller: orderController,
                      decoration: const InputDecoration(
                        labelText: 'Thứ tự hiển thị',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 10),
                    pickedImageFile != null
                        ? Image.file(
                          pickedImageFile!,
                          height: 100,
                          width: 100,
                          fit: BoxFit.cover,
                        )
                        : (currentImageUrl != null && currentImageUrl.isNotEmpty
                            ? Image.network(
                              currentImageUrl,
                              height: 100,
                              width: 100,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (context, error, stackTrace) => const Icon(
                                    Icons.broken_image,
                                    size: 60,
                                    color: Colors.grey,
                                  ),
                            )
                            : const Icon(
                              Icons.image,
                              size: 60,
                              color: Colors.grey,
                            )),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: isUploadingImage ? null : pickImage,
                      icon: const Icon(Icons.photo_library),
                      label: Text(
                        isUploadingImage ? 'Đang tải...' : 'Chọn ảnh danh mục',
                      ),
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
                  onPressed:
                      isUploadingImage
                          ? null
                          : () async {
                            if (nameController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Vui lòng nhập tên danh mục.'),
                                ),
                              );
                              return;
                            }

                            final int? order = int.tryParse(
                              orderController.text,
                            );
                            if (order == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Thứ tự hiển thị không hợp lệ.',
                                  ),
                                ),
                              );
                              return;
                            }

                            String finalImageUrl = currentImageUrl ?? '';

                            if (pickedImageFile != null) {
                              setState(() {
                                isUploadingImage = true;
                              });
                              try {
                                final String originalPath =
                                    pickedImageFile!.path;
                                final String fileExtension =
                                    originalPath.split('.').last;

                                final String fileName =
                                    'category_images/${DateTime.now().millisecondsSinceEpoch}.$fileExtension';


                                final uploadTask = _storage
                                    .ref()
                                    .child(fileName)
                                    .putFile(pickedImageFile!);
                                final snapshot = await uploadTask.whenComplete(
                                  () {},
                                );
                                finalImageUrl =
                                    await snapshot.ref.getDownloadURL();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Đã tải ảnh danh mục lên thành công.',
                                    ),
                                  ),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Lỗi khi tải ảnh danh mục lên: $e',
                                    ),
                                  ),
                                );
                                setState(() {
                                  isUploadingImage = false;
                                });
                                return;
                              } finally {
                                setState(() {
                                  isUploadingImage = false;
                                });
                              }
                            }

                            final newCategory = Category(
                              id:
                                  category?.id ??
                                  _firestore
                                      .collection('restaurants')
                                      .doc(_selectedRestaurant!.id)
                                      .collection('categories')
                                      .doc()
                                      .id,
                              name: nameController.text,
                              order: order,
                              isAvailableForDelivery: isAvailableForDelivery,
                              isAvailableForDineIn: isAvailableForDineIn,
                              imageUrl: finalImageUrl,
                            );

                            try {
                              final categoryRef = _firestore
                                  .collection('restaurants')
                                  .doc(_selectedRestaurant!.id)
                                  .collection('categories')
                                  .doc(newCategory.id);

                              if (category == null) {
                                await categoryRef.set(
                                  newCategory.toFirestore(),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Đã thêm danh mục mới.'),
                                  ),
                                );
                              } else {
                                await categoryRef.update(
                                  newCategory.toFirestore(),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Đã cập nhật danh mục.'),
                                  ),
                                );
                              }
                              Navigator.of(ctx).pop();
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Lỗi khi lưu danh mục: $e'),
                                ),
                              );
                            }
                          },
                  child:
                      isUploadingImage
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
    if (_selectedRestaurant == null) return;

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Xác nhận xóa'),
            content: const Text(
              'Bạn có chắc chắn muốn xóa danh mục này không?',
            ),
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
                    await _firestore
                        .collection('restaurants')
                        .doc(_selectedRestaurant!.id)
                        .collection('categories')
                        .doc(categoryId)
                        .delete();

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
