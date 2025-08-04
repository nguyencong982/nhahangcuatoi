import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class AddressSelectionScreen extends StatefulWidget {
  final String? initialAddress;

  const AddressSelectionScreen({Key? key, this.initialAddress}) : super(key: key);

  @override
  State<AddressSelectionScreen> createState() => _AddressSelectionScreenState();
}

class _AddressSelectionScreenState extends State<AddressSelectionScreen> {
  final TextEditingController _addressController = TextEditingController();
  bool _isLoadingLocation = false;
  String? _currentLocationAddress;

  @override
  void initState() {
    super.initState();
    _addressController.text = widget.initialAddress ?? '';
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
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
        desiredAccuracy: LocationAccuracy.high, // Độ chính xác cao
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
        localeIdentifier: 'vi_VN',
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
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
      print('Lỗi khi lấy vị trí hoặc địa chỉ: $e');
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
            child: TextField(
              controller: _addressController,
              decoration: InputDecoration(
                hintText: 'Nhập địa chỉ của bạn',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  Navigator.pop(context, value);
                }
              },
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                _buildSectionHeader('Dùng gần đây'),
                _buildLocationTile(
                  icon: Icons.my_location,
                  title: 'Vị trí hiện tại',
                  subtitle: _isLoadingLocation
                      ? 'Đang định vị...'
                      : _currentLocationAddress ?? 'Không thể lấy vị trí hiện tại',
                  onTap: _isLoadingLocation || _currentLocationAddress == null
                      ? null
                      : () {
                    Navigator.pop(context, _currentLocationAddress);
                  },
                  showThreeDot: true,
                ),
                _buildLocationTile(
                  icon: Icons.location_on,
                  title: 'Gần 20/50, Bình Đường 1',
                  subtitle: 'Bình Dương 1 St, P.An Bình, Tp.Dĩ An, Bình Dương, 75000, ...',
                  onTap: () {
                    Navigator.pop(context, 'Gần 20/50, Bình Dương 1, Bình Dương 1 St, P.An Bình, Tp.Dĩ An, Bình Dương, 75000, ...');
                  },
                  showThreeDot: true,
                ),

                _buildSectionHeader('Địa điểm đã lưu của tôi'),
                _buildLocationTile(
                  icon: Icons.favorite,
                  title: 'Địa điểm đã lưu của tôi',
                  subtitle: 'Cổng A, 33/2 Gò Cát, P.Phú Hữu, Tp.Thủ Đức, Hồ Chí Minh, 70000, Vietnam',
                  onTap: () {
                    Navigator.pop(context, 'Cổng A, 33/2 Gò Cát, P.Phú Hữu, Tp.Thủ Đức, Hồ Chí Minh, 70000, Vietnam');
                  },
                  showThreeDot: true,
                ),
                _buildLocationTile(
                  icon: Icons.person,
                  title: 'Nguyễn Hà Kim Anh',
                  subtitle: '107 Đường Số 6, 107, Street No.6, P.Linh Xuân, TP.Thủ Đức, Hồ Chí Minh City, 700...',
                  onTap: () {
                    Navigator.pop(context, '107 Đường Số 6, 107, Street No.6, P.Linh Xuân, TP.Thủ Đức, Hồ Chí Minh City, 700...');
                  },
                  showThreeDot: true,
                ),

                _buildSectionHeader('Cần trợ giúp?'),
                _buildHelpTile(
                  icon: Icons.location_searching,
                  title: 'Vẫn không tìm thấy địa điểm bạn muốn?',
                  subtitle: 'Hãy thử nhập mã cộng (Plus Code) của địa điểm trên Google Maps.',
                  onTap: () { /* Xử lý khi chạm */ },
                ),
                _buildHelpTile(
                  icon: Icons.public,
                  title: 'Nếu địa điểm nằm ở nơi khác, trước tiên hãy chọn thành phố, khu vực hoặc quốc gia của địa điểm đó.',
                  subtitle: 'Bạn có thể thay đổi khu vực tìm kiếm trong cài đặt.',
                  onTap: () { /* Xử lý khi chạm */ },
                ),
                _buildHelpTile(
                  icon: Icons.feedback,
                  title: 'Không tìm thấy địa điểm hoặc thông tin không đúng? Hãy cho chúng tôi biết.',
                  subtitle: '',
                  onTap: () { /* Xử lý khi chạm */ },
                ),
                SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showSnackBar('Tính năng chọn trên bản đồ đang được phát triển.');
                    },
                    icon: Icon(Icons.map, color: Colors.red),
                    label: Text(
                      'Chọn trên Google Maps',
                      style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red, width: 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                    ),
                  ),
                ),
                SizedBox(height: 20),
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

  Widget _buildLocationTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    bool showThreeDot = false,
  }) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: Colors.red),
          title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
          subtitle: Text(subtitle, style: GoogleFonts.poppins(color: Colors.grey[600])),
          trailing: showThreeDot ? Icon(Icons.more_vert, color: Colors.grey) : null,
          onTap: onTap,
        ),
        Divider(height: 1, indent: 16, endIndent: 16, color: Colors.grey[200]),
      ],
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
          trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          onTap: onTap,
        ),
        Divider(height: 1, indent: 16, endIndent: 16, color: Colors.grey[200]),
      ],
    );
  }
}