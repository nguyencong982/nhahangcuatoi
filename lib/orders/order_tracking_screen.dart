import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:menufood/shared/models.dart';
import 'package:vibration/vibration.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;

  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  AppOrder? _order;
  bool _isLoading = true;
  String? _errorMessage;
  bool _hasVibratedForReady = false;
  StreamSubscription? _orderStreamSubscription;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initializeLocalNotifications();
    _setupOrderStream();
  }

  void _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse notificationResponse) async {
        if (notificationResponse.payload != null) {
          debugPrint('notification payload: ${notificationResponse.payload}');
          if (context.mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => OrderTrackingScreen(orderId: notificationResponse.payload!),
              ),
            );
          }
        }
      },
    );
  }

  @override
  void dispose() {
    _orderStreamSubscription?.cancel();
    _stopNotificationSoundAndVibration();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _stopNotificationSoundAndVibration() {
    _audioPlayer.stop();
    Vibration.cancel();
    print("Customer notification sound and vibration stopped.");
  }

  void _setupOrderStream() {
    _orderStreamSubscription = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.exists && snapshot.data() != null) {
        final newOrder = AppOrder.fromFirestore(snapshot);
        setState(() {
          _order = newOrder;
          _isLoading = false;
        });

        if (_order!.status == 'ready') {
          if (!_hasVibratedForReady) {
            if (await Vibration.hasVibrator() ?? false) {
              Vibration.vibrate(duration: 1000000, pattern: [0, 1000, 1000], repeat: 0);
            }
            await _audioPlayer.setReleaseMode(ReleaseMode.loop);
            await _audioPlayer.play(AssetSource('sounds/zapsplat_household_door_bell_ding_dong_impatient_multiple_fast_presses.mp3'));

            _hasVibratedForReady = true;

            _showLocalNotification(newOrder.id);

            if (context.mounted) {
              _showCustomerConfirmationDialog();
            }
          }
        } else {
          if (_hasVibratedForReady) {
            _stopNotificationSoundAndVibration();
            _hasVibratedForReady = false;
          }
        }

      } else {
        setState(() {
          _errorMessage = 'Không tìm thấy đơn hàng này.';
          _isLoading = false;
        });
        if (_hasVibratedForReady) {
          _stopNotificationSoundAndVibration();
          _hasVibratedForReady = false;
        }
      }
    }, onError: (error) {
      setState(() {
        _errorMessage = 'Lỗi khi tải chi tiết đơn hàng: $error';
        _isLoading = false;
      });
      print('Lỗi khi tải chi tiết đơn hàng: $error');
      if (_hasVibratedForReady) {
        _stopNotificationSoundAndVibration();
        _hasVibratedForReady = false;
      }
    });
  }

  void _showLocalNotification(String orderId) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'order_ready_channel',
      'Thông báo đơn hàng sẵn sàng',
      channelDescription: 'Thông báo khi đơn hàng của bạn đã sẵn sàng để lấy.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
      playSound: true,
      enableVibration: true,
    );
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
    DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'zapsplat_household_door_bell_ding_dong_impatient_multiple_fast_presses.mp3',
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      'Đơn hàng của bạn đã sẵn sàng!',
      'Đơn hàng #${orderId.substring(0, 8)} đã sẵn sàng để lấy. Vui lòng lại quầy nhận.',
      platformChannelSpecifics,
      payload: orderId,
    );
  }

  void _showCustomerConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Đơn hàng đã sẵn sàng!',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.purple),
          ),
          content: Text(
            'Món ăn của bạn đã sẵn sàng để lấy. Vui lòng lại quâ nhận và nhấn "Xác nhận đã lấy món" sau khi bạn đã nhận được món.',
            style: GoogleFonts.poppins(fontSize: 16),
          ),
          actions: <Widget>[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Xác nhận đã lấy món',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              onPressed: () async {
                _stopNotificationSoundAndVibration();
                Navigator.of(context).pop();

                try {
                  await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({
                    'status': 'completed',
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Cảm ơn bạn đã xác nhận!')),
                    );
                  }
                } catch (e) {
                  print('Lỗi khi cập nhật trạng thái đơn hàng: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Lỗi khi xác nhận đơn hàng: $e')),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Chờ xử lý';
      case 'preparing':
        return 'Đang chuẩn bị';
      case 'ready':
        return 'Sẵn sàng (Vui lòng lại quầy nhận)';
      case 'delivering':
        return 'Đang giao hàng';
      case 'completed':
        return 'Hoàn thành';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return 'Không xác định';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'preparing':
        return Colors.blue;
      case 'ready':
        return Colors.purple;
      case 'delivering':
        return Colors.indigo;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color commonBackgroundColor = Color(0xFFFCF6E0);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: commonBackgroundColor,
        appBar: AppBar(
          backgroundColor: commonBackgroundColor,
          title: Text('Theo dõi đơn hàng', style: GoogleFonts.poppins(color: Colors.black87)),
          iconTheme: const IconThemeData(color: Colors.black),
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: commonBackgroundColor,
        appBar: AppBar(
          backgroundColor: commonBackgroundColor,
          title: Text('Lỗi', style: GoogleFonts.poppins(color: Colors.black87)),
          iconTheme: const IconThemeData(color: Colors.black),
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.red, fontSize: 18),
            ),
          ),
        ),
      );
    }

    if (_order == null) {
      return Scaffold(
        backgroundColor: commonBackgroundColor,
        appBar: AppBar(
          backgroundColor: commonBackgroundColor,
          title: Text('Theo dõi đơn hàng', style: GoogleFonts.poppins(color: Colors.black87)),
          iconTheme: const IconThemeData(color: Colors.black),
          elevation: 0,
        ),
        body: Center(
          child: Text(
            'Không tìm thấy thông tin đơn hàng.',
            style: GoogleFonts.poppins(color: Colors.grey[700]),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: commonBackgroundColor,
      appBar: AppBar(
        backgroundColor: commonBackgroundColor,
        title: Text('Đơn hàng #${widget.orderId.substring(0, 8)}', style: GoogleFonts.poppins(color: Colors.black87)),
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _order!.orderType == 'dine_in' ? Icons.restaurant_menu : Icons.delivery_dining,
                      color: Colors.deepOrange,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _order!.orderType == 'dine_in' ? 'Đơn hàng Ăn tại quán' : 'Đơn hàng Giao hàng',
                      style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                Text(
                  'Trạng thái đơn hàng:',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(_order!.status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getStatusText(_order!.status),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(_order!.status),
                    ),
                  ),
                ),
                const Divider(height: 30, thickness: 1),
                _buildInfoRow('Nhà hàng:', _order!.restaurantId),
                _buildInfoRow('Tổng tiền:', '${_order!.totalAmount.toStringAsFixed(0)} VNĐ'),
                _buildInfoRow('Thời gian đặt:', DateFormat('dd/MM/yyyy HH:mm').format(_order!.timestamp.toDate())),
                _buildInfoRow('Phương thức thanh toán:', _order!.paymentMethod),
                if (_order!.customerNotes != null && _order!.customerNotes!.isNotEmpty)
                  _buildInfoRow('Ghi chú của bạn:', _order!.customerNotes!),

                if (_order!.orderType == 'dine_in') ...[
                  if (_order!.tableNumber != null && _order!.tableNumber!.isNotEmpty)
                    _buildInfoRow('Bàn số:', _order!.tableNumber!),
                ] else if (_order!.orderType == 'delivery') ...[
                  if (_order!.deliveryOption != null && _order!.deliveryOption!.isNotEmpty)
                    _buildInfoRow('Tùy chọn giao hàng:', _order!.deliveryOption!),
                  if (_order!.deliveryAddress != null && _order!.deliveryAddress!.isNotEmpty)
                    _buildInfoRow('Địa chỉ giao hàng:', _order!.deliveryAddress!),
                  if (_order!.deliveryFee != null && _order!.deliveryFee! > 0)
                    _buildInfoRow('Phí giao hàng:', '${_order!.deliveryFee!.toStringAsFixed(0)} VNĐ'),
                ],

                if (_order!.discountAmount != null && _order!.discountAmount! > 0)
                  _buildInfoRow('Giảm giá:', '-${_order!.discountAmount!.toStringAsFixed(0)} VNĐ'),

                const Divider(height: 30, thickness: 1),
                Text(
                  'Chi tiết món ăn:',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _order!.items.length,
                  itemBuilder: (context, index) {
                    final item = _order!.items[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(
                        '${item['name']} x ${item['quantity']} (${(item['price'] as num).toStringAsFixed(0)} VNĐ/món)',
                        style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[800]),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey[700]),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
