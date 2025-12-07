import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:menufood/shared/models.dart';

class AdminRestaurantSelectorScreen extends StatefulWidget {
  final String purposeText;

  const AdminRestaurantSelectorScreen({
    super.key,
    this.purposeText = 'chọn',
  });

  @override
  State<AdminRestaurantSelectorScreen> createState() => _AdminRestaurantSelectorScreenState();
}

class _AdminRestaurantSelectorScreenState extends State<AdminRestaurantSelectorScreen> {
  GoogleMapController? mapController;

  LatLng _center = const LatLng(10.929831, 106.845946);
  Position? _currentPosition;
  Set<Marker> _markers = {};
  Restaurant? _selectedRestaurant;

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _fetchRestaurants();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    _currentPosition = await Geolocator.getCurrentPosition();
    if (_currentPosition != null) {
      if (mounted) {
        setState(() {
          _center = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
          if (mapController != null) {
            mapController!.animateCamera(CameraUpdate.newLatLng(_center));
          }
        });
      }
    }
  }

  Future<void> _fetchRestaurants() async {
    final querySnapshot = await FirebaseFirestore.instance.collection('restaurants').get();
    final newMarkers = <Marker>{};

    for (var doc in querySnapshot.docs) {
      final restaurant = Restaurant.fromFirestore(doc);
      final LatLng? position = restaurant.location != null ? LatLng(restaurant.location!.latitude, restaurant.location!.longitude) : null;

      if (position != null) {
        newMarkers.add(
          Marker(
            markerId: MarkerId(restaurant.id),
            position: position,
            infoWindow: InfoWindow(
              title: restaurant.name ?? 'Không có tên',
              snippet: restaurant.address ?? 'Không có địa chỉ',
              onTap: () {
                setState(() {
                  _selectedRestaurant = restaurant;
                });
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
    setState(() {
      _markers = newMarkers;
    });
  }

  void _selectRestaurantAndReturn() {
    if (_selectedRestaurant == null) return;
    Navigator.pop(context, _selectedRestaurant);
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    mapController!.animateCamera(CameraUpdate.newLatLng(_center));
  }

  @override
  Widget build(BuildContext context) {
    final String appBarTitle = 'Chọn nhà hàng để ${widget.purposeText}';

    String buttonText;
    if (widget.purposeText.contains('món') || widget.purposeText.contains('danh mục')) {
      buttonText = 'Chọn Quán';
    } else if (widget.purposeText.contains('QR')) {
      buttonText = 'Tạo QR';
    } else {
      buttonText = 'Chọn';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
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
                              _selectedRestaurant!.name ?? 'Không có tên',
                              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedRestaurant!.address ?? 'Không có địa chỉ',
                              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _selectRestaurantAndReturn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(buttonText, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
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