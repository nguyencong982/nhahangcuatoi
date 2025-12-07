import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const String CLOUD_RUN_BASE_URL = 'https://revenue-service-1096129874429.us-central1.run.app';

class ChatScreen extends StatefulWidget {
  final String orderId;
  final String customerId;
  final String customerName;
  final String shipperId;

  const ChatScreen({
    Key? key,
    required this.orderId,
    required this.customerId,
    required this.customerName,
    required this.shipperId,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();

    print('DEBUG: Current User UID (Đang đăng nhập): ${_auth.currentUser?.uid}');
    print('DEBUG: Chat ID đang truy vấn: ${widget.orderId}');
    print('DEBUG: customerId được truyền vào: ${widget.customerId}');
    print('DEBUG: shipperId được truyền vào: ${widget.shipperId}');
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final currentUser = _auth.currentUser;

    if (text.isEmpty || currentUser == null) {
      return;
    }

    final messageText = _messageController.text.trim();
    _messageController.clear();

    try {
      final idToken = await currentUser.getIdToken();
      final url = Uri.parse('$CLOUD_RUN_BASE_URL/api/v1/chat/send');

      final body = jsonEncode({
        'chatId': widget.orderId,
        'message': messageText,
        'customerId': widget.customerId,
        'shipperId': widget.shipperId,
        'customerUID': widget.customerId,
        'shipperUID': widget.shipperId,
      });

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        print('Tin nhắn đã được gửi qua Cloud Run API.');
      } else {
        final responseBody = jsonDecode(response.body);
        final errorMessage = responseBody['error'] ?? 'Lỗi không xác định từ Server.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi gửi tin: ${response.statusCode} - $errorMessage')),
        );
      }

    } catch (e) {
      print('ERROR CHAT: Lỗi khi gọi Cloud Run API: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể kết nối Server: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('chats').doc(widget.orderId).snapshots(),
      builder: (context, chatSnapshot) {
        String partnerName = widget.customerName;
        String appBarTitle = 'Chat...';
        bool chatDocExists = false;

        if (chatSnapshot.hasData && chatSnapshot.data!.exists) {
          chatDocExists = true;
          final data = chatSnapshot.data!.data() as Map<String, dynamic>;
          final currentUserUid = _auth.currentUser?.uid;
          final isCustomer = currentUserUid == widget.customerId;

          if (isCustomer) {
            partnerName = data['shipperName'] ?? 'Shipper';
          } else {
            partnerName = data['customerName'] ?? 'Khách hàng';
          }
          appBarTitle = 'Chat với $partnerName';
        } else if (chatSnapshot.connectionState == ConnectionState.waiting) {
          appBarTitle = 'Đang tải thông tin chat...';
        } else if (chatSnapshot.hasError) {
          appBarTitle = 'Chat (Lỗi đọc: Rules/ID)';
        } else {
          appBarTitle = 'Chat (Đang chờ tạo chat...)';
        }


        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.deepOrange,
            title: Text(
              appBarTitle,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: !chatDocExists && chatSnapshot.connectionState != ConnectionState.waiting
                    ? Center(child: Text(
                  'vui lòng chờ....',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(),
                ))
                    : StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('chats')
                      .doc(widget.orderId)
                      .collection('messages')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      print('ERROR CHAT STREAM: Lỗi đọc tin nhắn: ${snapshot.error}');
                      return Center(child: Text('LỖI ĐỌC TIN: ${snapshot.error.toString()} - Đã sửa lỗi độ trễ, kiểm tra Rules / App Check!'));
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('Chưa có tin nhắn nào'));
                    }

                    final messages = snapshot.data!.docs;

                    return ListView.builder(
                      reverse: true,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final data = message.data() as Map<String, dynamic>;
                        final isMe = data['senderId'] == currentUser?.uid;

                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.orange[200] : Colors.grey[300],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              data['message'] ?? data['text'] ?? '',
                              style: GoogleFonts.poppins(fontSize: 15),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                color: Colors.white,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Nhập tin nhắn...',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.deepOrange),
                      onPressed: _sendMessage,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}