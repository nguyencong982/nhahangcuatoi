import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:menufood/shared/models.dart';
import 'dart:math';
import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:menufood/chat/chat_screen.dart';

class ShipperOrderDetailScreen extends StatefulWidget {
  final String orderId;

  const ShipperOrderDetailScreen({Key? key, required this.orderId}) : super(key: key);

  @override
  State<ShipperOrderDetailScreen> createState() => _ShipperOrderDetailScreenState();
}

class _ShipperOrderDetailScreenState extends State<ShipperOrderDetailScreen> {
  GoogleMapController? mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  List<LatLng> polylineCoordinates = [];

  StreamSubscription<Position>? _positionStreamSubscription;

  String? _shipperId;
  String? _restaurantId;
  LatLng? _restaurantLocation;
  LatLng? _customerLocation;
  LatLng? _shipperCurrentLocation;
  double _distanceKm = 0.0;
  bool _isLoading = true;
  String? _errorLoadingData;
  String _currentOrderStatus = 'ready';

  AppUser? _customerDetails;
  String? _customerAddress;

  bool _isNavigationMode = false;

  @override
  void initState() {
    super.initState();
    _shipperId = FirebaseAuth.instance.currentUser?.uid;
    _fetchOrderAndLocations();
  }

  @override
  void dispose() {
    _isNavigationMode = false;
    _positionStreamSubscription?.cancel();
    mapController?.dispose();
    super.dispose();
  }

  double _distanceBetween(LatLng p1, LatLng p2) {
    const double earthRadius = 6371000;
    double lat1Rad = p1.latitude * (pi / 180);
    double lon1Rad = p1.longitude * (pi / 180);
    double lat2Rad = p2.latitude * (pi / 180);
    double lon2Rad = p2.longitude * (pi / 180);

    double deltaLat = lat2Rad - lat1Rad;
    double deltaLon = lon2Rad - lon1Rad;

    double a = pow(sin(deltaLat / 2), 2) +
        cos(lat1Rad) * cos(lat2Rad) * pow(sin(deltaLon / 2), 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  void _navigateToChat() {
    if (_customerDetails == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đang tải thông tin khách hàng, vui lòng đợi...')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          orderId: widget.orderId,
          customerId: _customerDetails!.id ?? '',
          customerName: _customerDetails!.fullName ?? 'Khách hàng',
          shipperId: _shipperId ?? '',
        ),
      ),
    );
  }


  void _updatePolylinesForNavigation(LatLng currentLocation) {
    if (polylineCoordinates.isEmpty) return;

    int nearestIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < polylineCoordinates.length; i++) {
      double dist = _distanceBetween(currentLocation, polylineCoordinates[i]);
      if (dist < minDistance) {
        minDistance = dist;
        nearestIndex = i;
      }
    }

    if (minDistance > 50) return;

    List<LatLng> passedCoordinates = polylineCoordinates.sublist(0, nearestIndex + 1);
    List<LatLng> futureCoordinates = polylineCoordinates.sublist(nearestIndex);

    setState(() {
      _polylines.clear();

      if (passedCoordinates.length > 1) {
        _polylines.add(Polyline(
          polylineId: const PolylineId('route_passed'),
          points: passedCoordinates,
          color: Colors.grey.shade600,
          width: 5,
        ));
      }

      if (futureCoordinates.length > 1) {
        _polylines.add(Polyline(
          polylineId: const PolylineId('route_future'),
          points: futureCoordinates,
          color: Colors.blue,
          width: 5,
        ));
      }
    });
  }

  Future<void> _startLocationStream() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dịch vụ định vị chưa được bật.')));
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Quyền truy cập vị trí bị từ chối.')));
        }
        return;
      }
    }

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    try {
      Position initialPosition =
      await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _shipperCurrentLocation =
          LatLng(initialPosition.latitude, initialPosition.longitude);
      await _setMarkersAndCalculateRoute();
    } catch (_) {}

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
          final newLocation = LatLng(position.latitude, position.longitude);
          if (mounted) {
            setState(() {
              _shipperCurrentLocation = newLocation;

              _markers.removeWhere((m) => m.markerId.value == 'shipper');
              _markers.add(Marker(
                markerId: const MarkerId('shipper'),
                position: _shipperCurrentLocation!,
                infoWindow: InfoWindow(title: _isNavigationMode ? '' : 'Vị trí của bạn'),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              ));

              if (_isNavigationMode) {
                _updatePolylinesForNavigation(newLocation);

                mapController?.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: newLocation,
                      zoom: 17.0,
                      tilt: 60.0,
                    ),
                  ),
                );
              }
            });
          }
        });
  }

  Future<void> _fetchCustomerDetails(String customerId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(customerId)
          .get();

      if (doc.exists) {
        setState(() {
          _customerDetails = AppUser.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
        });
      }
    } catch (e) {
      print("Lỗi khi fetch chi tiết khách hàng: $e");
    }
  }

  Future<void> _fetchOrderAndLocations() async {
    try {
      if (_shipperId == null) throw 'Không tìm thấy ID của shipper.';

      FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .snapshots()
          .listen((orderDoc) async {
        if (!orderDoc.exists) {
          setState(() => _errorLoadingData = 'Không tìm thấy đơn hàng.');
          return;
        }

        final order = AppOrder.fromFirestore(orderDoc);
        final isUnassignedReadyOrder = order.status == 'ready' && order.shipperId == null;
        final isAssignedToMe = order.shipperId == _shipperId;

        if (!isAssignedToMe && !isUnassignedReadyOrder) {
          setState(() => _errorLoadingData = 'Bạn không có quyền xem đơn hàng này hoặc đơn hàng không còn khả dụng.');
          return;
        }

        setState(() {
          _currentOrderStatus = order.status;
          _customerAddress = order.deliveryAddress;
        });

        final customerId = order.userId;
        if (customerId != null && _customerDetails == null) {
          await _fetchCustomerDetails(customerId);
        }

        if (isUnassignedReadyOrder) {
          if (mounted) setState(() => _isLoading = false);
          return;
        }

        final customerLocationData = order.deliveryLocation;
        final orderType = order.orderType;
        _customerLocation = customerLocationData != null
            ? LatLng(customerLocationData.latitude, customerLocationData.longitude)
            : null;

        _restaurantId = order.restaurantId;
        if (_restaurantId == null) throw 'Thiếu ID nhà hàng.';

        final restaurantDoc = await FirebaseFirestore.instance
            .collection('restaurants')
            .doc(_restaurantId)
            .get();

        if (!restaurantDoc.exists) throw 'Không tìm thấy nhà hàng.';
        final restaurant = Restaurant.fromFirestore(restaurantDoc);

        final restaurantLocationData = restaurant.location;
        if (restaurantLocationData == null) {
          throw 'Dữ liệu vị trí nhà hàng bị thiếu.';
        }

        _restaurantLocation =
            LatLng(restaurantLocationData.latitude, restaurantLocationData.longitude);

        if (_positionStreamSubscription == null) await _startLocationStream();
        await _setMarkersAndCalculateRoute();
        if (mounted) setState(() => _isLoading = false);
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorLoadingData = e.toString();
      });
    }
  }

  Future<void> _setMarkersAndCalculateRoute() async {
    if (!mounted || _shipperCurrentLocation == null) return;

    _markers.clear();
    _polylines.clear();
    polylineCoordinates.clear();
    setState(() {
      _distanceKm = 0.0;
      _errorLoadingData = null;
    });

    LatLng startPoint = _shipperCurrentLocation!;
    LatLng? endPoint;

    if (_currentOrderStatus == 'picking up') {
      endPoint = _restaurantLocation;
    } else if (_currentOrderStatus == 'in transit') {
      if (_customerLocation != null) {
        endPoint = _customerLocation;
      } else {
        if (_customerAddress != null && _customerAddress!.isNotEmpty) {
          setState(() => _errorLoadingData = 'Địa chỉ khách hàng nhập thủ công. Không thể tính lộ trình trên bản đồ. Địa chỉ: $_customerAddress');
        } else {
          setState(() => _errorLoadingData = 'Địa chỉ khách hàng nhập thủ công và thiếu chuỗi địa chỉ chi tiết.');
        }

        mapController?.animateCamera(CameraUpdate.newLatLngZoom(startPoint, 15));
        return;
      }
    }

    if (_restaurantLocation != null) {
      _markers.add(Marker(
        markerId: const MarkerId('restaurant'),
        position: _restaurantLocation!,
        infoWindow: const InfoWindow(title: 'Nhà hàng'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ));
    }

    if (_customerLocation != null) {
      _markers.add(Marker(
        markerId: const MarkerId('customer'),
        position: _customerLocation!,
        infoWindow: const InfoWindow(title: 'Khách hàng'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    }

    _markers.add(Marker(
      markerId: const MarkerId('shipper'),
      position: _shipperCurrentLocation!,
      infoWindow: InfoWindow(title: _isNavigationMode ? '' : 'Bạn'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
    ));

    if (endPoint != null) {
      await _getPolylineAndDistance(startPoint, endPoint);
      if (mapController != null && polylineCoordinates.isNotEmpty) {
        if (!_isNavigationMode) {
          _zoomToRoute(startPoint, endPoint);
        }
      } else {
        mapController?.animateCamera(CameraUpdate.newLatLngZoom(startPoint, 15));
      }
    } else {
      mapController?.animateCamera(CameraUpdate.newLatLngZoom(startPoint, 15));
    }

    setState(() {});
  }

  Future<void> _getPolylineAndDistance(LatLng startPoint, LatLng endPoint) async {
    polylineCoordinates.clear();

    try {
      final functions = FirebaseFunctions.instance;

      final result = await functions.httpsCallable('getMapboxRoute').call({
        'startLat': startPoint.latitude,
        'startLon': startPoint.longitude,
        'endLat': endPoint.latitude,
        'endLon': endPoint.longitude,
      });

      final data = result.data;
      final encodedPolyline = data['encodedPolyline'] as String? ?? '';
      final distanceMeters = (data['distanceMeters'] as num?)?.toDouble() ?? 0.0;

      if (encodedPolyline.isEmpty) {
        setState(() => _errorLoadingData = 'Polyline trống từ Cloud Function.');
        return;
      }

      List<PointLatLng> decodedPoints = PolylinePoints.decodePolyline(encodedPolyline);

      if (decodedPoints.isEmpty) {
        setState(() => _errorLoadingData = 'Giải mã Polyline thất bại.');
        return;
      }

      polylineCoordinates = decodedPoints.map((point) => LatLng(point.latitude, point.longitude)).toList();

      _polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: polylineCoordinates,
        color: Colors.blue,
        width: 5,
      ));

      setState(() {
        _distanceKm = distanceMeters / 1000;
        _errorLoadingData = null;
      });
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _errorLoadingData = 'Lỗi Cloud Function: [${e.code}] ${e.message}';
      });
    } catch (e) {
      setState(() {
        _errorLoadingData = 'Lỗi không xác định khi tính lộ trình: $e';
      });
    }
  }

  void _zoomToRoute(LatLng start, LatLng end) {
    if (mapController == null) return;
    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(
        min(start.latitude, end.latitude),
        min(start.longitude, end.longitude),
      ),
      northeast: LatLng(
        max(start.latitude, end.latitude),
        max(start.longitude, end.longitude),
      ),
    );
    mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 70));
  }

  void _startNavigationMode() {
    if (!mounted || _shipperCurrentLocation == null) return;

    if (polylineCoordinates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể bắt đầu chỉ đường vì thiếu lộ trình hoặc địa chỉ khách hàng là thủ công.')),
      );
      return;
    }

    setState(() {
      _isNavigationMode = true;
    });

    _updatePolylinesForNavigation(_shipperCurrentLocation!);

    mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _shipperCurrentLocation!,
          zoom: 17.0,
          tilt: 60.0,
        ),
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bắt đầu chế độ chỉ đường...')),
    );
  }

  Future<void> _openInGoogleMaps() async {
    LatLng? destination;
    String? addressString;

    if (_currentOrderStatus == 'picking up') {
      destination = _restaurantLocation;
    } else if (_currentOrderStatus == 'in transit') {
      destination = _customerLocation;
      addressString = _customerAddress;
    }

    if (destination == null && addressString == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tìm thấy điểm đến để chỉ đường.')));
      return;
    }

    final String query = destination != null
        ? '${destination.latitude},${destination.longitude}'
        : Uri.encodeComponent(addressString!);

    final uri = Uri.parse(
        'google.navigation:q=$query&mode=d');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể mở Google Maps. Kiểm tra cài đặt ứng dụng.')));
    }
  }

  Future<void> _markOrderAsAccepted() async {
    if (_shipperId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi: Không tìm thấy ID Shipper')));
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({
        'status': 'picking up',
        'shipperId': _shipperId,
        'shipperStatus': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _currentOrderStatus = 'picking up';
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã nhận đơn hàng. Bắt đầu đi lấy món!')));

    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi khi nhận đơn: $e')));
    }
  }

  Future<void> _markOrderAsPickedUp() async {
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({
        'status': 'in transit',
        'shipperStatus': 'delivering',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _isNavigationMode = false;
        });
      }

      await _setMarkersAndCalculateRoute();

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lấy hàng. Lộ trình mới đã được tính!')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _markOrderAsDelivered() async {
    try {
      final docRef = FirebaseFirestore.instance.collection('orders').doc(widget.orderId);
      await docRef.update({
        'status': 'delivered',
        'shipperStatus': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _isNavigationMode = false;
        });
      }
      _positionStreamSubscription?.cancel();
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Giao hàng thành công!')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Widget _buildNavigationHeader(String destinationName, int timeMinutes, String totalDistanceKm) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '$timeMinutes phút',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade800,
                  ),
                ),
                Text(
                  ' ($totalDistanceKm km)',
                  style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey.shade700),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Tuyển đường nhanh nhất đến $destinationName',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.lightBlue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.two_wheeler, color: Colors.blue),
        ),
      ],
    );
  }

  Widget _buildInfoSummary(String destinationName, String customerName, String? customerPhone) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_currentOrderStatus == 'ready')
          Text(
            'Đơn hàng sẵn sàng được nhận',
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple.shade700),
          )
        else
          Text(
            'Đang đi đến: $destinationName',
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
          ),

        if (_currentOrderStatus != 'ready' && _customerLocation != null)
          Text(
            'Khoảng cách: ${_distanceKm.toStringAsFixed(1)} km',
            style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey),
          ),

        if (_currentOrderStatus == 'in transit' && _customerLocation == null && _customerAddress != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Địa chỉ (Thủ công): $_customerAddress',
              style: GoogleFonts.poppins(fontSize: 15, color: Colors.red.shade700, fontStyle: FontStyle.italic),
            ),
          ),

        if (customerName != 'Khách hàng') ...[
          const SizedBox(height: 8),
          Text(
            'Khách hàng: $customerName',
            style: GoogleFonts.poppins(fontSize: 15),
          ),
        ],

        if (_currentOrderStatus == 'in transit' && customerPhone != null)
          Text(
            'SĐT: $customerPhone',
            style: GoogleFonts.poppins(fontSize: 15),
          ),
      ],
    );
  }

  Widget _buildStatusActionButton() {
    if (_currentOrderStatus == 'ready') {
      return ElevatedButton(
        onPressed: _markOrderAsAccepted,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.indigo.shade600,
          padding: const EdgeInsets.symmetric(vertical: 15),
        ),
        child: Text(
          'NHẬN ĐƠN HÀNG NÀY',
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      );
    } else if (_currentOrderStatus == 'picking up') {
      return ElevatedButton(
        onPressed: _markOrderAsPickedUp,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(
          'ĐÃ NHẬN MÓN - Sẵn sàng giao',
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      );
    } else if (_currentOrderStatus == 'in transit') {
      return ElevatedButton(
        onPressed: _markOrderAsDelivered,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(
          'HOÀN THÀNH GIAO HÀNG',
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildNavigationBottomSheet(
      String destinationName,
      String customerName,
      String? customerPhone,
      ) {
    final isNavigating = _isNavigationMode;
    final totalDistanceKm = _distanceKm.toStringAsFixed(1);
    final timeMinutes = (_distanceKm * 3).ceil();
    final isReady = _currentOrderStatus == 'ready';

    final canNavigate = (_currentOrderStatus == 'picking up' && _restaurantLocation != null) ||
        (_currentOrderStatus == 'in transit' && _customerLocation != null);

    return Container(
      padding: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0, bottom: 24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isNavigating
            ? const BorderRadius.vertical(top: Radius.circular(0))
            : const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isNavigating)
            _buildNavigationHeader(destinationName, timeMinutes, totalDistanceKm)
          else
            _buildInfoSummary(destinationName, customerName, customerPhone),

          const Divider(height: 20),

          if (!isReady)
            ...[
              ElevatedButton.icon(
                onPressed: _setMarkersAndCalculateRoute,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: Text(
                  'TÍNH LẠI LỘ TRÌNH',
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 10),

              if (canNavigate)
                if (isNavigating)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() => _isNavigationMode = false);
                            _setMarkersAndCalculateRoute();
                          },
                          icon: const Icon(Icons.stop, color: Colors.white),
                          label: Text('DỪNG CHỈ ĐƯỜNG', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      if (_currentOrderStatus == 'in transit' && customerPhone != null) ...[
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 50,
                          child: ElevatedButton(
                            onPressed: () {
                              launchUrl(Uri.parse('tel:$customerPhone'));
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Icon(Icons.phone, color: Colors.white),
                          ),
                        )
                      ]
                    ],
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _startNavigationMode,
                    icon: const Icon(Icons.navigation, color: Colors.white),
                    label: Text(
                      'BẮT ĐẦU CHỈ ĐƯỜNG ĐẾN ${destinationName.toUpperCase()}',
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  )
              else
                if (_currentOrderStatus == 'in transit' && customerPhone != null)
                  ElevatedButton.icon(
                    onPressed: () {
                      launchUrl(Uri.parse('tel:$customerPhone'));
                    },
                    icon: const Icon(Icons.phone, color: Colors.white),
                    label: Text(
                      'GỌI CHO KHÁCH HÀNG (Địa chỉ thủ công)',
                      style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Địa chỉ khách hàng nhập thủ công. Vui lòng sử dụng Google Maps (nút góc trên) để tìm đường bằng địa chỉ chi tiết.',
                      style: GoogleFonts.poppins(color: Colors.orange.shade700, fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
                    ),
                  ),

              const SizedBox(height: 10),
            ],

          _buildStatusActionButton(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    LatLng initialTarget =
        _shipperCurrentLocation ?? _restaurantLocation ?? const LatLng(10.762622, 106.660172);

    final isNavigating = _isNavigationMode;
    final isReady = _currentOrderStatus == 'ready';

    final destinationName = _currentOrderStatus == 'picking up' || isReady
        ? 'Nhà hàng'
        : 'Khách hàng';

    final String? customerPhone = _customerDetails?.phoneNumber;
    final String customerName = _customerDetails?.fullName ?? 'Khách hàng';


    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initialTarget,
              zoom: isNavigating ? 17 : 14,
              tilt: isNavigating ? 60.0 : 0.0,
            ),
            onMapCreated: (controller) => mapController = controller,
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: !isReady,
            myLocationButtonEnabled: !isNavigating,
            zoomControlsEnabled: false,
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'backButton',
                  onPressed: () => Navigator.pop(context),
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 4,
                  child: const Icon(Icons.arrow_back),
                ),
                const SizedBox(height: 10),

                if (!isReady) ...[
                  FloatingActionButton.small(
                    heroTag: 'googleMapButton',
                    onPressed: _openInGoogleMaps,
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue.shade800,
                    elevation: 4,
                    child: const Icon(Icons.open_in_new),
                  ),
                  const SizedBox(height: 10),

                  Stack(
                    alignment: Alignment.topRight,
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'chatButton',
                        onPressed: _navigateToChat,
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        child: const Icon(Icons.chat_bubble_outline),
                      ),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('chats')
                            .doc(widget.orderId)
                            .collection('messages')
                            .where('isRead', isEqualTo: false)
                            .where('receiverId', isEqualTo: _shipperId)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '${snapshot.data!.docs.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  FloatingActionButton.small(
                    heroTag: 'centerButton',
                    onPressed: () {
                      if (_shipperCurrentLocation != null) {
                        mapController?.animateCamera(
                          CameraUpdate.newCameraPosition(
                            CameraPosition(
                              target: _shipperCurrentLocation!,
                              zoom: isNavigating ? 17.0 : 15.0,
                              tilt: isNavigating ? 60.0 : 0.0,
                            ),
                          ),
                        );
                      }
                    },
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    elevation: 4,
                    child: const Icon(Icons.my_location),
                  ),
                ],
              ],
            ),
          ),

          if (_errorLoadingData != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Card(
                  color: _errorLoadingData!.contains('Địa chỉ khách hàng nhập thủ công')
                      ? Colors.orange.shade600
                      : Colors.red.shade600,
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      'Lỗi: $_errorLoadingData',
                      style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ),
            ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildNavigationBottomSheet(
                destinationName, customerName, customerPhone),
          ),
        ],
      ),
    );
  }
}