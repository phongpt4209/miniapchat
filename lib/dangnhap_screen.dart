import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dangky_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Bộ điều khiển để lấy dữ liệu từ các ô nhập
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  // Biến quản lý ẩn/hiện mật khẩu
  bool _obscureText = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

void _login() async {
  String inputField = _emailController.text.trim(); // Người dùng nhập email hoặc username
  String password = _passwordController.text.trim();

  if (inputField.isEmpty || password.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vui lòng nhập đầy đủ thông tin!')),
    );
    return;
  }

  try {
    String emailToLogin = inputField;

    // NẾU NGƯỜI DÙNG KHÔNG NHẬP DẤU '@' (=> đang đăng nhập bằng Username)
    if (!inputField.contains('@')) {
      // Check Firestore tìm kiếm xem có user nào có tên username trùng khớp không
      var userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: inputField)
          .get();

      if (userQuery.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tên đăng nhập (Username) không tồn tại!')),
          );
        }
        return;
      }
      
      // Nếu tìm thấy username, lấy ra email thật tương ứng của họ
      emailToLogin = userQuery.docs.first.data()['email'];
    }

    // Thực hiện đăng nhập bằng Email thật (Lấy từ username hoặc do người dùng tự gõ)
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: emailToLogin,
      password: password,
    );
    // Lấy thông tin user vừa đăng nhập ngầm xem họ đã click link kích hoạt chưa
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null && !user.emailVerified) {
      // Nếu chưa bấm link trong Email, bắt buộc phải đăng xuất ra ngay và báo lỗi
      await FirebaseAuth.instance.signOut();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tài khoản của bạn chưa được xác thực! Vui lòng kiểm tra Email và xác thực tài khoản!')),
      );
      return; // Dừng hàm, không cho chuyển vào HomeScreen
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng nhập thành công!')),
      );
      
      // Điều hướng vào màn hình HomeScreen
      print('Đăng nhập thành công với tài khoản: $emailToLogin');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false, // Xóa sạch lịch sử các màn hình trước (không cho bấm back lại màn login)
      );
    }

  } on FirebaseAuthException catch (e) {
    String errorMsg = 'Sai tài khoản hoặc mật khẩu!';
    if (e.code == 'user-not-found') {
      errorMsg = 'Tài khoản không tồn tại trên hệ thống.';
    } else if (e.code == 'wrong-password') {
      errorMsg = 'Mật khẩu không chính xác.';
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg)));
    }
  } catch (e) {
    print(e);
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo hoặc Tiêu đề ứng dụng
              const Icon(Icons.chat_bubble_sharp, size: 80, color: Colors.blue),
              const SizedBox(height: 16),
              const Text(
                'HAPPY CHAT',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),

              // Ô nhập Email / Username
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email hoặc Tên đăng nhập',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Ô nhập Mật khẩu
              TextField(
                controller: _passwordController,
                obscureText: _obscureText, // Ẩn mật khẩu
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

              // Nút Đăng nhập
              ElevatedButton(
                onPressed: _login,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('ĐĂNG NHẬP', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 16),

              // Dòng chữ chuyển sang Đăng ký
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Chưa có tài khoản? '),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RegisterScreen()),
                      );//Chuyển sang màn hình đăng ký tài khoản
                    },
                    child: const Text(
                      'Đăng ký ngay',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
