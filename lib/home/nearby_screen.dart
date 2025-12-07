import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:menufood/shared/models.dart';

const double _MAX_DELIVERY_DISTANCE_METERS = 70000.0;

class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  GoogleMapController? mapController;
  LatLng _center = const LatLng(10.929831, 106.845946);
  Position? _currentPosition;
  Set<Marker> _markers = {};
  Restaurant? _selectedRestaurant;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _determinePosition();
    await _fetchRestaurantsAndAutoSelect();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;
    Position? tempPosition;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Dịch vụ định vị bị tắt. Vui lòng bật GPS.';
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Quyền truy cập vị trí bị từ chối.';
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw 'Quyền truy cập vị trí đã bị từ chối vĩnh viễn.';
      }

      try {
        tempPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 5),
        );
      } catch (e) {
        debugPrint('Lỗi getCurrentPosition, chuyển sang LastKnownPosition: $e');
        try {
          tempPosition = await Geolocator.getLastKnownPosition();
        } catch (e2) {
          debugPrint('Lỗi khi lấy LastKnownPosition: $e2');
          tempPosition = null;
        }
      }

      if (tempPosition != null && mounted) {
        setState(() {
          _currentPosition = tempPosition;
          _center = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
        });
        if (mapController != null) {
          mapController!.animateCamera(CameraUpdate.newLatLng(_center));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể xác định vị trí. Đang dùng vị trí mặc định.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Location setup error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi vị trí: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _fetchRestaurantsAndAutoSelect() async {
    final querySnapshot = await FirebaseFirestore.instance.collection('restaurants').get();
    Restaurant? nearestRestaurant;
    double minDistanceInMeters = double.infinity;
    final newMarkers = <Marker>{};

    if (_currentPosition == null) {
      await _fetchRestaurantsForMap();
      return;
    }

    for (var doc in querySnapshot.docs) {
      final restaurant = Restaurant.fromFirestore(doc);
      final data = doc.data();
      final GeoPoint? location = data.containsKey('location') ? data['location'] : null;
      final LatLng? position = location != null ? LatLng(location.latitude, location.longitude) : null;

      if (position != null) {
        final double distanceInMeters = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          position.latitude,
          position.longitude,
        );

        if (distanceInMeters < minDistanceInMeters && distanceInMeters <= _MAX_DELIVERY_DISTANCE_METERS) {
          minDistanceInMeters = distanceInMeters;
          nearestRestaurant = restaurant;
        }

        newMarkers.add(
          Marker(
            markerId: MarkerId(restaurant.id),
            position: position,
            infoWindow: InfoWindow(
              title: restaurant.name ?? 'Không có tên',
              snippet: '${(distanceInMeters / 1000).toStringAsFixed(2)} km - Nhấn để chọn quán',
              onTap: () {
                setState(() {
                  _selectedRestaurant = restaurant;
                });
                _showRestaurantDetails();
              },
            ),
            onTap: () {
              setState(() {
                _selectedRestaurant = restaurant;
              });
            },
          ),
        );
      }
    }

    if (nearestRestaurant != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã tự động chọn quán: ${nearestRestaurant.name} (${(minDistanceInMeters / 1000).toStringAsFixed(2)} km)',
            style: GoogleFonts.poppins(),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      Navigator.pop(context, nearestRestaurant);
      return;
    }

    if (mounted) {
      setState(() {
        _markers = newMarkers;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không tìm thấy quán nào gần bạn. Vui lòng chọn thủ công.',
            style: GoogleFonts.poppins(),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _fetchRestaurantsForMap() async {
    final querySnapshot = await FirebaseFirestore.instance.collection('restaurants').get();
    final newMarkers = <Marker>{};

    for (var doc in querySnapshot.docs) {
      final restaurant = Restaurant.fromFirestore(doc);
      final data = doc.data();
      final GeoPoint? location = data.containsKey('location') ? data['location'] : null;
      final LatLng? position = location != null ? LatLng(location.latitude, location.longitude) : null;

      if (position != null) {
        newMarkers.add(
          Marker(
            markerId: MarkerId(restaurant.id),
            position: position,
            infoWindow: InfoWindow(
              title: restaurant.name ?? 'Không có tên',
              snippet: restaurant.address ?? 'Nhấn để chọn quán',
              onTap: () {
                setState(() {
                  _selectedRestaurant = restaurant;
                });
                _showRestaurantDetails();
              },
            ),
            onTap: () {
              setState(() {
                _selectedRestaurant = restaurant;
              });
            },
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _markers = newMarkers;
      });
    }
  }


  void _showRestaurantDetails() {
    if (_selectedRestaurant == null) return;
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedRestaurant!.name ?? 'Tên quán không rõ',
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _selectedRestaurant!.address ?? 'Địa chỉ không rõ',
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context, _selectedRestaurant);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text('Chọn quán này', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    if (_currentPosition != null) {
      mapController!.animateCamera(CameraUpdate.newLatLng(_center));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Đang tải bản đồ quán...', style: GoogleFonts.poppins())),
        body: const Center(child: CircularProgressIndicator(color: Colors.orange)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Chọn nhà hàng thủ công', style: GoogleFonts.poppins()),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _center,
              zoom: 15.0,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          if (_selectedRestaurant != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _selectedRestaurant!.name ?? 'Tên quán không rõ',
                              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedRestaurant!.address ?? 'Địa chỉ không rõ',
                              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () {
                          // Trả về quán đã chọn
                          Navigator.pop(context, _selectedRestaurant);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text('Chọn quán', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}