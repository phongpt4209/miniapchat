import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';//file sinh ra từ firebase configure
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dangnhap_screen.dart'; 
import 'home_screen.dart';

// Khởi tạo cấu hình kênh thông báo độ ưu tiên cao cho Android
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel', 
  'High Importance Notifications', 
  description: 'This channel is used for important notifications.', 
  importance: Importance.high,
);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

// Hàm xử lý thông báo chạy ngầm khi ứng dụng bị tắt hoàn toàn
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Nhận thông báo chạy ngầm: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Đăng ký hàm chạy ngầm
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Xin quyền thông báo hiển thị trên điện thoại
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(alert: true, badge: true, sound: true);

  // Cấu hình hiển thị banner thông báo nổi trên Android
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
  
  // Khởi tạo thông báo cục bộ
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  // 2. Cấu hình iOS / Darwin
  const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );
  
await flutterLocalNotificationsPlugin.initialize(
  settings:initializationSettings,
  onDidReceiveNotificationResponse: (NotificationResponse notificationResponse) async {
    print("Người dùng đã nhấn vào thông báo: ${notificationResponse.payload}");
  },
);

  // Lắng nghe khi đang mở app mà có tin nhắn tới (Hiện banner nổi)
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {      
      flutterLocalNotificationsPlugin.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            icon: android.smallIcon,
          ),
        ),
      );
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chat App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(), 
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) {
            return const HomeScreen();
          }
          return const LoginScreen(); 
        },
      ),
    );
  }
}