import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Bộ điều khiển cho các ô nhập
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureText = true;
  bool _obscureConfirmText = true; 

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _register() async {
    String username = _usernameController.text.trim().toLowerCase();
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String confirmPassword = _confirmPasswordController.text.trim(); // Lấy mật khẩu nhập lại

    // 1. Kiểm tra rỗng
    if (username.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showSnackBar('Vui lòng điền đầy đủ tất cả các ô!');
      return;
    }

    // 2. Kiểm tra độ trùng khớp của 2 ô mật khẩu
    if (password != confirmPassword) {
      _showSnackBar('Mật khẩu nhập lại không trùng khớp!');
      return;
    }

    try {
      // 3. Tạo tài khoản trên Firebase Authentication
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      User? user = userCredential.user;

      if (user != null) {
        // 4. GỬI LỆNH XÁC THỰC EMAIL TỚI HỘP THƯ NGƯỜI DÙNG
        await user.sendEmailVerification();

        // 5. Lưu thông tin tên người dùng (username) vào bảng 'users' trên Firestore
        String uid = user.uid;
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'uid': uid,
          'username': username,
          'email': email,
          'createdAt': DateTime.now(),
        });

        _showDialogNotice('Đăng ký thành công!', 'Liên kết xác thực đã được gửi tới địa chỉ email: $email, của bạn. Vui lòng kiểm tra hộp thư (hoặc thư rác) và bấm vào link xác thực trước khi tiến hành đăng nhập!');
      }

    } on FirebaseAuthException catch (e) {
      String errorMsg = 'Đã có lỗi xảy ra.';
      if (e.code == 'weak-password') {
        errorMsg = 'Mật khẩu phải dài từ 6 ký tự trở lên!';
      } else if (e.code == 'email-already-in-use') {
        errorMsg = 'Email này đã được sử dụng bởi tài khoản khác!';
      } else if (e.code == 'invalid-email') {
        errorMsg = 'Định dạng email không hợp lệ!';
      }
      _showSnackBar(errorMsg);
    } catch (e) {
      print(e);
    }
  }

  // Hàm bổ trợ hiển thị hộp thoại thông báo bắt buộc nhấn OK
  void _showDialogNotice(String title, String content) {
    showDialog(
      context: context,
      barrierDismissible: false, // Bắt buộc phải bấm nút, không cho bấm ra ngoài tắt đi
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Tắt hộp thoại
              Navigator.pop(context); // Quay về màn hình Đăng nhập
            },
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
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
        title: const Text('Đăng Ký Tài Khoản'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Tạo Tài Khoản Mới',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),

              // Ô nhập Username
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Tên người dùng (Username)',
                  prefixIcon: Icon(Icons.account_circle),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              
              // Ô nhập Email
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Địa chỉ Email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Ô nhập Mật khẩu
              TextField(
                controller: _passwordController,
                obscureText: _obscureText,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  prefixIcon: const Icon(Icons.lock),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Ô nhập lại mật khẩu
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmText,
                decoration: InputDecoration(
                  labelText: 'Nhập lại mật khẩu',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmText ? Icons.visibility_off : Icons.visibility),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmText = !_obscureConfirmText; // Đảo trạng thái ẩn hiện mật khẩu 2
                      });
                    },
                  ),
                ),
              ),

              // Nút Đăng ký
              ElevatedButton(
                onPressed: _register,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('ĐĂNG KÝ', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}