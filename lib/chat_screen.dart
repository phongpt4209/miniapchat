import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:intl/intl.dart'; // Thư viện để định dạng ngày giờ

class ChatScreen extends StatefulWidget {
  final String chatRoomId;
  final String receiverName;

  const ChatScreen({super.key, required this.chatRoomId, required this.receiverName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;

  // Hàm xử lý gửi tin nhắn văn bản lên Firestore
  void _sendMessage() async {
    String msgText = _messageController.text.trim();
    if (msgText.isEmpty) return;

    _messageController.clear(); // Xóa nội dung chat sau khi gửi

    // 1. Lưu tin nhắn vào sub-collection 'messages'
    await FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(widget.chatRoomId)
        .collection('messages')
        .add({
      'senderId': _currentUserId,
      'message': msgText,
      'timestamp': FieldValue.serverTimestamp(), // Lưu thời gian gửi
    });

    // 2. Cập nhật tin nhắn cuối cùng ra phòng chat ngoài để sau này hiển thị danh sách lịch sử
    await FirebaseFirestore.instance.collection('chat_rooms').doc(widget.chatRoomId).update({
      'lastMessage': msgText,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        // Thay thế tiêu đề chữ thông thường thành một hàng Row chứa cả Avatar và Tên
        title: StreamBuilder<DocumentSnapshot>(
          // Lắng nghe dữ liệu thời gian thực của người nhận dựa vào ID phòng chat ngầm
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('username', isEqualTo: widget.receiverName)
              .snapshots()
              .map((snapshot) => snapshot.docs.first),
          builder: (context, snapshot) {
            String? friendAvatarBase64;
            
            if (snapshot.hasData && snapshot.data!.exists) {
              var userData = snapshot.data!.data() as Map<String, dynamic>;
              friendAvatarBase64 = userData['avatar']; // Lấy mã ảnh của bạn chat từ Firestore
            }

            return Row(
              children: [
                // 1. VÒNG TRÒN AVATAR CỦA BẠN CHAT ĐẶT TRƯỚC TÊN
                CircleAvatar(
                  radius: 18, // Kích thước vòng tròn nhỏ gọn trên thanh tiêu đề
                  backgroundColor: Colors.white24,
                  backgroundImage: friendAvatarBase64 != null
                      ? MemoryImage(base64Decode(friendAvatarBase64)) // Giải mã hiển thị ảnh Base64
                      : null,
                  child: friendAvatarBase64 == null
                      ? const Icon(Icons.person, color: Colors.white, size: 20) // Hiện icon mặc định nếu chưa cài ảnh
                      : null,
                ),
                const SizedBox(width: 12), // Khoảng cách giữa ảnh đại diện và tên
                
                // 2. TÊN CỦA BẠN CHAT
                Expanded(
                  child: Text(
                    widget.receiverName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis, // Tự động thu gọn bằng dấu ... nếu tên quá dài
                  ),
                ),
              ],
            );
          },
      ),
      ),
      body: Column(
        children: [
          // TỰ ĐỘNG LOAD LẠI TIN NHẮN CŨ VÀ CẬP NHẬT TIN NHẮN MỚI
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chat_rooms')
                  .doc(widget.chatRoomId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true) // Sắp xếp tin nhắn mới nhất lên đầu
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Hãy bắt đầu trò chuyện!', style: TextStyle(color: Colors.grey)));
                }

                var chatDocs = snapshot.data!.docs;

              return ListView.builder(
                reverse: true,
                itemCount: chatDocs.length,
                itemBuilder: (context, index) {
                  Map<String, dynamic> data = chatDocs[index].data() as Map<String, dynamic>;
                  bool isMe = data['senderId'] == _currentUserId;

                  // LẤY VÀ ĐỊNH DẠNG THỜI GIAN CHAT
                  String formattedTime = "";
                  if (data['timestamp'] != null) {
                    Timestamp timestamp = data['timestamp'];
                    DateTime dateTime = timestamp.toDate();
                    // Định dạng hiển thị giờ:phút
                    formattedTime = DateFormat('HH:mm').format(dateTime); 
                  }

                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Column(
                      // Căn lề thời gian theo hướng của bong bóng chat (Phải nếu là mình, Trái nếu là bạn)
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        // 1. BONG BÓNG NỘI DUNG CHAT
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.blue : Colors.grey[300],
                            borderRadius: BorderRadius.circular(12).copyWith(
                              bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(12),
                              bottomLeft: !isMe ? const Radius.circular(0) : const Radius.circular(12),
                            ),
                          ),
                          child: Text(
                            data['message'] ?? '',
                            style: TextStyle(color: isMe ? Colors.white : Colors.black, fontSize: 16),
                          ),
                        ),

                        // 2. DÒNG THỜI GIAN CHAT NHỎ BÊN DƯỚI NỘI DUNG CHAT
                        if (formattedTime.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                            child: Text(
                              formattedTime,
                              style: TextStyle(
                                color: Colors.grey[600], 
                                fontSize: 11, // Kích thước font chữ hiển thị thời gian
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
              },
            ),
          ),

          // Ô NHẬP TIN NHẮN VÀ NÚT GỬI
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Nhập tin nhắn...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}