import 'dart:convert';
import 'dart:io'; // Chuyển đổi Base64
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'chat_screen.dart';
import 'dangnhap_screen.dart';
import 'chat_nhom_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  String _currentUsername = "Đang tải...";// Biên lưu user đăng nhập hiện tại

  Map<String, dynamic>? _searchResult;
  String _relationStatus = ""; // Trạng thái mối quan hệ giữa mình và người tìm thấy
  bool _isSearching = false;
  String? _avatarBase64;// Biến lưu chuỗi ảnh đại diện
  // HÀM HIỂN THỊ TÊN ĐĂNG NHẬP VÀ NÚT ĐĂNG XUẤT
  @override
    void initState() {
      super.initState();
      _getCurrentUsername();

    }
    //Hàm load ảnh đại diện từ Firestore
    void _loadUserAvatar() async {
      var doc = await FirebaseFirestore.instance.collection('users').doc(_currentUserId).get();
      if (doc.exists && doc.data() != null) {
        setState(() {
          _avatarBase64 = doc.data()!['avatar']; // Lấy chuỗi mã ảnh cũ nếu có
        });
      }
    }
    //Đổi ảnh đại diện
    void _changeAvatar() async {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);

      if (image != null) {
        File imageFile = File(image.path);
        List<int> imageBytes = await imageFile.readAsBytes();
        String base64String = base64Encode(imageBytes);

        await FirebaseFirestore.instance.collection('users').doc(_currentUserId).update({
          'avatar': base64String,
        });

        setState(() {
          _avatarBase64 = base64String;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật ảnh đại diện!')),
        );
      }
    }

    void _getCurrentUsername() async {
      var userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUserId).get();
      if (userDoc.exists && userDoc.data() != null) {
        setState(() {
          _currentUsername = userDoc.data()!['username'] ?? "User";
          _avatarBase64 = userDoc.data()!['avatar'];//Hiển thị ảnh đại diện
        });
            // LẤY VÀ LƯU FCM TOKEN THIẾT BỊ LÊN FIRESTORE
        try {
          String? token = await FirebaseMessaging.instance.getToken();
          if (token != null) {
            await FirebaseFirestore.instance.collection('users').doc(_currentUserId).update({
              'fcmToken': token, // Lưu mã token thiết bị của máy
            });
          }
        } catch (e) {
          print("Lỗi lấy Token thông báo: $e");
        }
      }
    }
  // 1. HÀM TÌM KIẾM USERNAME VÀ KIỂM TRA TRẠNG THÁI KẾT BẠN
    void _searchUser() async {
    String searchName = _searchController.text.trim().toLowerCase();
    if (searchName.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResult = null;
      _relationStatus = "";
    });

    var querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: searchName)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      var userDoc = querySnapshot.docs.first;
      String targetUserId = userDoc.data()['uid'];

      if (targetUserId == _currentUserId) {
        _showSnackBar('Bạn đang nhập tài khoản của chính mình!');
        setState(() => _isSearching = false);
        return;
      }

      // Kiểm tra xem 2 người đã có lời mời kết bạn nào chưa
      var requestQuery = await FirebaseFirestore.instance
          .collection('friend_requests')
          .where('senderId', whereIn: [_currentUserId, targetUserId])
          .get();

      String status = "none";
      for (var doc in requestQuery.docs) {
        var data = doc.data();
        if ((data['senderId'] == _currentUserId && data['receiverId'] == targetUserId) ||
            (data['senderId'] == targetUserId && data['receiverId'] == _currentUserId)) {
          if (data['status'] == 'accepted') {
            status = "friends";
          } else if (data['status'] == 'pending') {
            status = data['senderId'] == _currentUserId ? "sent" : "received";
          }
        }
      }

      setState(() {
        _searchResult = userDoc.data();
        _relationStatus = status;
        _isSearching = false;
      });
    } else {
      setState(() => _isSearching = false);
      _showSnackBar('Không tìm thấy!');
    }
  }

  // 2. HÀM GỬI LỜI MỜI KẾT BẠN
  void _sendFriendRequest() async {
    if (_searchResult == null) return;
    String targetUserId = _searchResult!['uid'];
    String requestId = "${_currentUserId}_$targetUserId";

    await FirebaseFirestore.instance.collection('friend_requests').doc(requestId).set({
      'senderId': _currentUserId,
      'receiverId': targetUserId,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });

    setState(() => _relationStatus = "sent");
    _showSnackBar('Đã gửi lời mời kết bạn!');
  }

  // 3. HÀM ĐỒNG Ý KẾT BẠN VÀ TẠO PHÒNG CHAT NGẦM
  void _acceptFriendRequest(String senderId, String requestId) async {
    // Cập nhật trạng thái thành bạn bè
    await FirebaseFirestore.instance.collection('friend_requests').doc(requestId).update({
      'status': 'accepted',
    });

    // Tạo sẵn phòng chat duy nhất cho 2 người
    List<String> ids = [_currentUserId, senderId];
    ids.sort();
    String chatRoomId = ids.join("_");

    await FirebaseFirestore.instance.collection('chat_rooms').doc(chatRoomId).set({
      'users': [_currentUserId, senderId],
      'lastMessage': 'Các bạn đã trở thành bạn bè. Hãy bắt đầu chat!',
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _showSnackBar('Đã đồng ý kết bạn!');
    if (_searchResult != null && _searchResult!['uid'] == senderId) {
      setState(() => _relationStatus = "friends");
    }
  }

  // HÀM ĐIỀU HƯỚNG VÀO PHÒNG CHAT KHI BẤM VÀO TÊN BẠN
  void _openChat(String targetUserId, String targetUsername) {
    List<String> ids = [_currentUserId, targetUserId];
    ids.sort();
    String chatRoomId = ids.join("_");

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(chatRoomId: chatRoomId, receiverName: targetUsername),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // Vòng tròn ảnh đại diện cho phép bấm vào để chọn ảnh đổi
            GestureDetector(
              onTap: _changeAvatar,
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white,
                backgroundImage: _avatarBase64 != null 
                    ? MemoryImage(base64Decode(_avatarBase64!)) // Nếu có ảnh thì hiển thị ảnh Base64
                    : null,
                child: _avatarBase64 == null 
                    ? const Icon(Icons.camera_alt, color: Colors.blue, size: 20) // Nếu chưa có ảnh thì hiện icon máy ảnh
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Text('$_currentUsername'),
          ],
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
          actions: [
    // Nút nguồn đăng xuất tài khoản
            IconButton(
              icon: const Icon(Icons.power_settings_new, color: Colors.white, size: 28), // Icon nút nguồn
              tooltip: 'Đăng xuất',
              onPressed: () async {
                // 1. Thực hiện đăng xuất trên hệ thống Firebase Server
                await FirebaseAuth.instance.signOut();
                
                // 2. Chuyển người dùng quay trở lại màn hình Đăng nhập
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen()), 
                    (route) => false,
                  );
                }
              },
            ),
            const SizedBox(width: 8), // Khoảng cách nhỏ ngoài cùng thanh tiêu đề
          ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ô TÌM KIẾM USERNAME
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Tìm Username kết bạn...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _searchUser,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  child: _isSearching 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.search),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // KẾT QUẢ TÌM KIẾM & NÚT MỜI KẾT BẠN
            if (_searchResult != null) ...[
              const Text('Kết quả tìm kiếm:', style: TextStyle(fontWeight: FontWeight.bold)),
              Card(
                child: ListTile(
                    leading: CircleAvatar(
                    backgroundColor: Colors.blue,
                    backgroundImage: _searchResult!['avatar'] != null
                        ? MemoryImage(base64Decode(_searchResult!['avatar'])) // Hiện ảnh của người dùng nếu có
                        : null,
                    child: _searchResult!['avatar'] == null
                        ? const Icon(Icons.person, color: Colors.white) // Hiện icon nếu chưa đổi ảnh
                        : null,
                  ),
                  title: Text(_searchResult!['username']),
                  //subtitle: Text(_searchResult!['email']),
                  trailing: _buildActionButton(),
                ),
              ),
              const Divider(),
            ],

            // DANH SÁCH LỜI MỜI KẾT BẠN ĐANG CHỜ ĐỒNG Ý
            const Text('Lời mời kết bạn đang chờ:', style: TextStyle(fontWeight: FontWeight.bold)),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('friend_requests')
                  .where('receiverId', isEqualTo: _currentUserId)
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('Không có lời mời nào.', style: TextStyle(color: Colors.grey)),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    String senderId = doc['senderId'];
                    
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(senderId).get(),
                      builder: (context, userSnapshot) {
                        if (!userSnapshot.hasData) return const SizedBox();
                        String senderName = userSnapshot.data!['username'];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Color.fromARGB(255, 69, 125, 247),
                            backgroundImage: userSnapshot.data!['avatar'] != null
                                ? MemoryImage(base64Decode(userSnapshot.data!['avatar'])) // Hiện ảnh Base64 người gửi
                                : null,
                            child: userSnapshot.data!['avatar'] == null
                                ? const Icon(Icons.person, color: Colors.white)
                                : null,
                          ),
                          title: Text(senderName),
                          subtitle: const Text('Muốn kết bạn với bạn'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check, color: Colors.green),
                                onPressed: () => _acceptFriendRequest(senderId, doc.id),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
            const Divider(),

            const Text('Danh sách bạn bè:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('friend_requests')
                  .where('status', isEqualTo: 'accepted')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                
                // Lọc ra danh sách UID bạn bè liên quan đến mình
                List<String> friendIds = [];
                for (var doc in snapshot.data!.docs) {
                  if (doc['senderId'] == _currentUserId) friendIds.add(doc['receiverId']);
                  if (doc['receiverId'] == _currentUserId) friendIds.add(doc['senderId']);
                }

                if (friendIds.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Text('Chưa có bạn bè nào. Hãy tìm kiếm để kết bạn!', style: TextStyle(color: Colors.grey)),
                  );
                }
                // Tải thông tin hiển thị của bạn bè từ bảng 'users'
                return StreamBuilder(
                  stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('uid', whereIn: friendIds)
                  .snapshots(),
                  builder: (context, userSnapshot) {    
                    if (!userSnapshot.hasData) return const SizedBox();
                    var friends = userSnapshot.data!.docs;
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: friends.length,
                      itemBuilder: (context, index) {
                        var friendData = friends[index].data() as Map<String, dynamic>;
                        return Card(
                          child: ListTile(
                              leading: CircleAvatar(
                              backgroundColor: Colors.blue,
                              backgroundImage: friendData['avatar'] != null
                                  ? MemoryImage(base64Decode(friendData['avatar'])) // Hiển thị ảnh của bạn nếu có
                                  : null,
                              child: friendData['avatar'] == null
                                  ? const Icon(Icons.person, color: Colors.white) // Hiện icon người nếu chưa cài ảnh
                                  : null,
                            ),
                            title: Text(friendData['username'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: const Text('Nhấn để bắt đầu chat'),
                            onTap: () => _openChat(friendData['uid'], friendData['username']), // Bấm vào để chat
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 24),
            const Divider(),
            // Nút tạo nhóm chat mới
            ElevatedButton.icon(
              onPressed: _showCreateGroupDialog,
              icon: const Icon(Icons.group_add),
              label: const Text('Tạo nhóm chat mới'),
              style: ElevatedButton.styleFrom(backgroundColor: Color.fromARGB(255, 69, 125, 247), foregroundColor: Colors.white),
            ),
            const SizedBox(height: 16),

            const Text('Nhóm đang tham gia:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('group_chats')
                  .where('members', arrayContains: _currentUserId) 
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                var groups = snapshot.data!.docs;

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    var groupData = groups[index].data() as Map<String, dynamic>;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:Color.fromARGB(255, 69, 125, 247),
                          backgroundImage: groupData['groupAvatar'] != null
                              ? MemoryImage(base64Decode(groupData['groupAvatar']))
                              : null,
                          child: groupData['groupAvatar'] == null
                              ? const Icon(Icons.group, color: Colors.white)
                              : null,
                        ),
                        title: Text(groupData['groupName'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(groupData['lastMessage'] ?? ''),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GroupChatScreen(
                                groupId: groupData['groupId'],
                                groupName: groupData['groupName'],
                                currentUsername: _currentUsername,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
      ],
    ),
  ),
);
}

// Hàm sinh giao diện Nút bấm động dựa theo mối quan hệ bạn bè
  Widget _buildActionButton() {
  if (_relationStatus == "none") {
  return ElevatedButton(
  onPressed: _sendFriendRequest,
  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
  child: const Text('Mời kết bạn'),
  );
  } else if (_relationStatus == "sent") {
  return const ElevatedButton(
  onPressed: null, // Vô hiệu hóa nút
  child: Text('Đang chờ đồng ý...'),
  );
  } else if (_relationStatus == "received") {
  return const Text('Họ đã gửi lời mời cho bạn (Xem ở dưới)');
  } else if (_relationStatus == "friends") {
  return ElevatedButton(
  onPressed: () => _openChat(_searchResult!['uid'], _searchResult!['username']),
  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
  child: const Text('Bạn bè (Chat)'),
  );
  }
  return const SizedBox();
  }
  void _showCreateGroupDialog() {
  final TextEditingController groupNameController = TextEditingController();
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Tạo nhóm chat mới', style: TextStyle(fontWeight: FontWeight.bold)),
      content: TextField(
        controller: groupNameController,
        decoration: const InputDecoration(
          hintText: 'Nhập tên nhóm...',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        ElevatedButton(
          onPressed: () async {
            String groupName = groupNameController.text.trim();
            if (groupName.isEmpty) return;

            // Tạo một tài liệu mới ngẫu nhiên trên Firestore
            var groupDoc = FirebaseFirestore.instance.collection('group_chats').doc();
            
            await groupDoc.set({
              'groupId': groupDoc.id,
              'groupName': groupName,
              // Sau khi tạo nhóm, người tạo sẽ là thành viên đầu tiên
              'members': [_currentUserId], 
              'lastMessage': 'Nhóm chat đã được tạo!',
              'timestamp': FieldValue.serverTimestamp(),
            });

            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Đã tạo nhóm "$groupName" thành công!')),
              );
            }
          },
          child: const Text('Tạo'),
        ),
      ],
    ),
  );
}
}  