import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String currentUsername;

  const GroupChatScreen({
    super.key, 
    required this.groupId, 
    required this.groupName,
    required this.currentUsername,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;

  void _sendGroupMessage() async {
    String msgText = _messageController.text.trim();
    if (msgText.isEmpty) return;

    _messageController.clear();

    await FirebaseFirestore.instance
        .collection('group_chats')
        .doc(widget.groupId)
        .collection('messages')
        .add({
      'senderId': _currentUserId,
      'senderName': widget.currentUsername, // Lưu tên để hiển thị trong nhóm
      'message': msgText,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance.collection('group_chats').doc(widget.groupId).update({
      'lastMessage': '${widget.currentUsername}: $msgText',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
    // Hiển thị danh sách bạn bè để mời vào nhóm
  void _showAddMemberDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Thêm thành viên vào nhóm',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 69, 125, 247)),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('friend_requests')
                      .where('status', isEqualTo: 'accepted')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                    List<String> friendIds = [];
                    for (var doc in snapshot.data!.docs) {
                      if (doc['senderId'] == _currentUserId) friendIds.add(doc['receiverId']);
                      if (doc['receiverId'] == _currentUserId) friendIds.add(doc['senderId']);
                    }

                    if (friendIds.isEmpty) {
                      return const Center(child: Text('Kết bạn để thêm thành viên vào nhóm!'));
                    }

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .where('uid', whereIn: friendIds)
                          .snapshots(),
                      builder: (context, userSnapshot) {
                        if (!userSnapshot.hasData) return const SizedBox();
                        var friends = userSnapshot.data!.docs;

                        return ListView.builder(
                          itemCount: friends.length,
                          itemBuilder: (context, index) {
                            var friendData = friends[index].data() as Map<String, dynamic>;
                            String friendUid = friendData['uid'];

                            return ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color.fromARGB(255, 69, 125, 247),
                                child: Icon(Icons.person, color: Colors.white),
                              ),
                              title: Text(friendData['username'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              trailing: IconButton(
                                icon: const Icon(Icons.add_circle, color: Colors.green, size: 28),
                                onPressed: () async {
                                  await FirebaseFirestore.instance
                                      .collection('group_chats')
                                      .doc(widget.groupId)
                                      .update({
                                    'members': FieldValue.arrayUnion([friendUid]),
                                  });

                                  await FirebaseFirestore.instance
                                      .collection('group_chats')
                                      .doc(widget.groupId)
                                      .collection('messages')
                                      .add({
                                    'senderId': 'system',
                                    'senderName': 'Happy Chat',
                                    'message': '${widget.currentUsername} đã thêm ${friendData['username']} vào nhóm.',
                                    'timestamp': FieldValue.serverTimestamp(),
                                  });

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Đã thêm ${friendData['username']} vào nhóm!')),
                                    );
                                  }
                                },
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
    // Hàm cập nhật đổi ảnh đại diện nhóm (Lưu dạng Base64 vào Firestore)
  void _changeGroupAvatar() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 40); // Nén ảnh nhẹ để lưu tối ưu

    if (image != null) {
      File imageFile = File(image.path);
      List<int> imageBytes = await imageFile.readAsBytes();
      String base64String = base64Encode(imageBytes);

      // Cập nhật chuỗi ảnh Base64 vào tài liệu nhóm trên Firestore
      await FirebaseFirestore.instance.collection('group_chats').doc(widget.groupId).update({
        'groupAvatar': base64String,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật ảnh đại diện của nhóm!')),
      );
    }
  }

  // Hàm hiển thị hộp thoại chỉnh sửa đổi tên nhóm
  void _showEditGroupNameDialog(String currentName) {
    final TextEditingController nameController = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đổi tên nhóm', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Nhập tên nhóm mới...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              String newName = nameController.text.trim();
              if (newName.isEmpty || newName == currentName) return;

              // Cập nhật tên nhóm mới lên Firestore
              await FirebaseFirestore.instance.collection('group_chats').doc(widget.groupId).update({
                'groupName': newName,
              });

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Đã đổi tên nhóm thành "$newName"')),
                );
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color.fromARGB(255, 69, 125, 247),
        foregroundColor: Colors.white,
        // Sử dụng StreamBuilder để lắng nghe sự thay đổi về Tên và Ảnh của nhóm thời gian thực
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('group_chats').doc(widget.groupId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Text(widget.groupName);
            }
            
            var groupData = snapshot.data!.data() as Map<String, dynamic>;
            String groupName = groupData['groupName'] ?? widget.groupName;
            String? groupAvatarBase64 = groupData['groupAvatar'];

            return Row(
              children: [
                // 1. VÒNG TRÒN AVATAR NHÓM (Bấm vào để chọn ảnh đại diện nhóm mới)
                GestureDetector(
                  onTap: _changeGroupAvatar,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white24,
                    backgroundImage: groupAvatarBase64 != null
                        ? MemoryImage(base64Decode(groupAvatarBase64))
                        : null,
                    child: groupAvatarBase64 == null
                        ? const Icon(Icons.group, color: Colors.white, size: 20)
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                
                // 2. TÊN NHÓM (Bấm vào nút chỉnh sửa kế bên để đổi tên)
                Expanded(
                  child: Text(
                    groupName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 16, color: Colors.white70),
                  tooltip: 'Đổi tên nhóm',
                  onPressed: () => _showEditGroupNameDialog(groupName),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add, size: 26),
            tooltip: 'Thêm thành viên',
            onPressed: _showAddMemberDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('group_chats')
                  .doc(widget.groupId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                var docs = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    bool isMe = data['senderId'] == _currentUserId;
                    bool isSystem = data['senderId'] == 'system';
                    //Canh giữa nếu là tin thông báo từ app
                    if (isSystem) {
                      return Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black12, // Màu nền xám nhẹ mờ cho thông báo từ app
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            data['message'] ?? '',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.black54, 
                              fontSize: 13, 
                              fontStyle: FontStyle.italic, // In nghiêng chữ thông báo từ app
                            ),
                          ),
                        ),
                      );
                    }
                    String formattedTime = "";
                    if (data['timestamp'] != null) {
                      formattedTime = DateFormat('HH:mm').format((data['timestamp'] as Timestamp).toDate());
                    }
                //Hiển thị nội dung chat theo định dạng người khác gửi: avatar và tên, nội dung gửi bên trái, tôi gửi bên phải
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        
                        // ===================================================================
                        if (!isMe)
                          StreamBuilder<QuerySnapshot>(
                            // Truy vấn vào bảng users để lấy ảnh đại diện mới nhất của người gửi dựa theo senderName hoặc senderId
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .where('username', isEqualTo: data['senderName'])
                                .snapshots(),
                            builder: (context, userSnapshot) {
                              String? senderAvatarBase64;
                              if (userSnapshot.hasData && userSnapshot.data!.docs.isNotEmpty) {
                                var userData = userSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                                senderAvatarBase64 = userData['avatar']; // Lấy mã ảnh Base64 của người gửi
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4.0, left: 4.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // 1. VÒNG TRÒN AVATAR NHỎ CỦA NGƯỜI GỬI TIN
                                    CircleAvatar(
                                      radius: 12, // Kích thước vòng avatar
                                      backgroundColor: Colors.blue.shade100,
                                      backgroundImage: senderAvatarBase64 != null
                                          ? MemoryImage(base64Decode(senderAvatarBase64))
                                          : null,
                                      child: senderAvatarBase64 == null
                                          ? const Icon(Icons.person, color: Colors.blue, size: 10)
                                          : null,
                                    ),
                                    const SizedBox(width: 6), // Khoảng cách giữa ảnh và tên
                                    
                                    // 2. TÊN USERNAME NGƯỜI GỬI
                                    Text(
                                      data['senderName'] ?? 'Ẩn danh',
                                      style: const TextStyle(
                                        fontSize: 12, 
                                        color: Colors.blue, 
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        // ===================================================================

                        // Khối vẽ bong bóng nội dung tin nhắn và thời gian bên dưới giữ nguyên cũ của bạn:
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isMe ? Color.fromARGB(255, 69, 125, 247) : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(data['message'] ?? '', style: TextStyle(color: isMe ? Colors.white : Colors.black, fontSize: 16)),
                        ),
                        if (formattedTime.isNotEmpty)
                          Text(formattedTime, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                      ],
                    ),
                  ),
                );

                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(hintText: 'Nhập tin nhắn nhóm...', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(20)))),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send, color: Color.fromARGB(255, 69, 125, 247)), onPressed: _sendGroupMessage),
              ],
            ),
          ),
        ],
      ),
    );
  }
}