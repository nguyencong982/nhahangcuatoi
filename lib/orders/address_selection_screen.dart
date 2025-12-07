import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

class AddressSelectionScreen extends StatefulWidget {
  final String? initialAddress;
  final String? initialPhoneNumber;

  const AddressSelectionScreen({
    Key? key,
    this.initialAddress,
    this.initialPhoneNumber,
  }) : super(key: key);

  @override
  State<AddressSelectionScreen> createState() => _AddressSelectionScreenState();
}

class _AddressSelectionScreenState extends State<AddressSelectionScreen> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  bool _isLoadingLocation = false;
  String? _currentLocationAddress;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _addressController.text = widget.initialAddress ?? '';
    _phoneController.text = widget.initialPhoneNumber ?? '';
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _fetchCustomerPhoneNumber() async {
    if (_currentUserId == null) return;
    try {
      final doc = await _firestore.collection('users').doc(_currentUserId).get();
      if (doc.exists && doc.data() != null && doc.data()!['phoneNumber'] != null) {
        setState(() {
          _phoneController.text = doc.data()!['phoneNumber'] as String;
        });
      }
    } catch (e) {
      // Bỏ qua lỗi tải số điện thoại
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _currentLocationAddress = null;
    });

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('Dịch vụ vị trí bị tắt. Vui lòng bật GPS.');
      setState(() { _isLoadingLocation = false; });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('Quyền truy cập vị trí đã bị từ chối.');
        setState(() { _isLoadingLocation = false; });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar('Quyền truy cập vị trí đã bị từ chối vĩnh viễn. Vui lòng vào cài đặt để cấp quyền.');
      setState(() { _isLoadingLocation = false; });
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentPosition = position;

      List<geocoding.Placemark> placemarks = await geocoding.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
        localeIdentifier: 'vi_VN',
      );

      if (placemarks.isNotEmpty) {
        geocoding.Placemark place = placemarks.first;
        String fullAddress = [
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
        ].where((element) => element != null && element.isNotEmpty).join(', ');

        setState(() {
          _currentLocationAddress = fullAddress;
        });
      } else {
        _showSnackBar('Không thể tìm thấy địa chỉ từ vị trí hiện tại của bạn.');
      }
    } catch (e) {
      _showSnackBar('Lỗi khi lấy vị trí: ${e.toString()}');
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _handleLocationSelection(String address, {GeoPoint? location, String? phoneNumber}) async {
    final phone = phoneNumber ?? _phoneController.text.trim();

    if (phone.isEmpty) {
      _showSnackBar('Vui lòng nhập Số điện thoại liên lạc.');
      return;
    }

    if (location == null) {
      try {
        List<geocoding.Location> locations = await geocoding.locationFromAddress(address);
        if (locations.isNotEmpty) {
          location = GeoPoint(locations.first.latitude, locations.first.longitude);
        } else {
          _showSnackBar('Không tìm thấy tọa độ cho địa chỉ này.');
          return;
        }
      } catch (e) {
        _showSnackBar('Lỗi khi xử lý địa chỉ: $e');
        return;
      }
    }

    if (mounted) {
      Navigator.of(context).pop({
        'address': address,
        'location': location,
        'phoneNumber': phone,
      });
    }
  }

  Future<void> _saveNewAddress(String address) async {
    final phone = _phoneController.text.trim();

    if (phone.isEmpty) {
      _showSnackBar('Vui lòng nhập Số điện thoại liên lạc trước.');
      return;
    }

    try {
      List<geocoding.Location> locations = await geocoding.locationFromAddress(address);
      if (locations.isNotEmpty) {
        final geoPoint = GeoPoint(locations.first.latitude, locations.first.longitude);

        await _firestore
            .collection('users')
            .doc(_currentUserId)
            .collection('addresses')
            .doc(const Uuid().v4())
            .set({
          'address': address,
          'location': geoPoint,
          'createdAt': FieldValue.serverTimestamp(),
        });

        _showSnackBar('Đã lưu địa chỉ mới!');
        _handleLocationSelection(address, location: geoPoint, phoneNumber: phone);
      } else {
        _showSnackBar('Không tìm thấy tọa độ cho địa chỉ này.');
      }
    } catch (e) {
      _showSnackBar('Lỗi khi lưu địa chỉ: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Giao đến', style: GoogleFonts.poppins()),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    hintText: 'Số điện thoại liên lạc',
                    prefixIcon: const Icon(Icons.phone, color: Colors.blue),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                    contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 10.0),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    hintText: 'Nhập địa chỉ của bạn',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.check),
                      onPressed: () {
                        if (_addressController.text.isNotEmpty) {
                          _saveNewAddress(_addressController.text);
                        }
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                    contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 10.0),
                  ),
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      _saveNewAddress(value);
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                _buildSectionHeader('Vị trí hiện tại'),
                _buildCurrentLocationTile(),

                _buildSectionHeader('Địa điểm đã lưu của tôi'),
                _buildSavedLocationsList(),

                _buildSectionHeader('Cần trợ giúp?'),
                _buildHelpTile(
                  icon: Icons.location_searching,
                  title: 'Vẫn không tìm thấy địa điểm bạn muốn?',
                  subtitle: 'Hãy thử nhập mã cộng (Plus Code) của địa điểm trên Google Maps.',
                  onTap: () {},
                ),
                _buildHelpTile(
                  icon: Icons.public,
                  title: 'Nếu địa điểm nằm ở nơi khác, trước tiên hãy chọn thành phố, khu vực hoặc quốc gia của địa điểm đó.',
                  subtitle: 'Bạn có thể thay đổi khu vực tìm kiếm trong cài đặt.',
                  onTap: () {},
                ),
                _buildHelpTile(
                  icon: Icons.feedback,
                  title: 'Không tìm thấy địa điểm hoặc thông tin không đúng? Hãy cho chúng tôi biết.',
                  subtitle: '',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildCurrentLocationTile() {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.my_location, color: Colors.red),
          title: Text('Vị trí hiện tại', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
          subtitle: Text(
            _isLoadingLocation
                ? 'Đang định vị...'
                : _currentLocationAddress ?? 'Không thể lấy vị trí hiện tại',
            style: GoogleFonts.poppins(color: Colors.grey[600]),
          ),
          trailing: _isLoadingLocation ? const CircularProgressIndicator(strokeWidth: 2) : const Icon(Icons.more_vert, color: Colors.grey),
          onTap: _isLoadingLocation || _currentLocationAddress == null
              ? null
              : () {
            if (_currentPosition != null && _currentLocationAddress != null) {
              final geoPoint = GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude);
              _handleLocationSelection(_currentLocationAddress!, location: geoPoint, phoneNumber: _phoneController.text.trim());
            } else {
              _showSnackBar('Không thể xác nhận vị trí hiện tại.');
            }
          },
        ),
        const Divider(height: 1, indent: 16, endIndent: 16, color: Colors.grey),
      ],
    );
  }

  Widget _buildSavedLocationsList() {
    if (_currentUserId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Đăng nhập để xem địa chỉ đã lưu.', style: GoogleFonts.poppins(color: Colors.grey)),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('addresses')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Bạn chưa có địa điểm đã lưu nào.', style: GoogleFonts.poppins(color: Colors.grey)),
            ),
          );
        }

        final addresses = snapshot.data!.docs;
        return Column(
          children: addresses.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final addressString = data['address'] as String;
            final geoPoint = data['location'] as GeoPoint;

            return Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.favorite, color: Colors.blue),
                  title: Text(data['title'] ?? 'Địa chỉ đã lưu', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                  subtitle: Text(addressString, style: GoogleFonts.poppins(color: Colors.grey[600]), maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.more_vert, color: Colors.grey),
                  onTap: () {
                    _handleLocationSelection(addressString, location: geoPoint, phoneNumber: _phoneController.text.trim());
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16, color: Colors.grey),
              ],
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildHelpTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: Colors.grey),
          title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
          subtitle: Text(subtitle, style: GoogleFonts.poppins(color: Colors.grey[600])),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          onTap: onTap,
        ),
        const Divider(height: 1, indent: 16, endIndent: 16, color: Colors.grey),
      ],
    );
  }
}