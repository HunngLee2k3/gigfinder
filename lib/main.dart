import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/detail_screen.dart'; // Đảm bảo file này tồn tại
import 'screens/applied_gigs_screen.dart'; // Import màn hình mới
import 'screens/post_gig_screen.dart'; // Import màn hình đăng gig
import 'screens/edit_profile_screen.dart'; // Import màn hình chỉnh sửa
import 'screens/applicant_list_screen.dart'; // Import màn hình danh sách ứng viên
import 'screens/wallet/deposit_screen.dart'; // Import màn hình nạp tiền
import 'screens/withdrawal_screen.dart'; // Import màn hình rút tiền
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // Bắt đầu ứng dụng với AuthWrapper, nó sẽ quyết định hiển thị màn hình nào
      initialRoute: '/',
      routes: {
        '/': (context) => AuthWrapper(),
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
        '/home': (context) => HomeScreen(),
        '/applied_gigs': (context) => AppliedGigsScreen(), // Đăng ký route mới
        '/edit_profile': (context) => EditProfileScreen(), // Đăng ký route chỉnh sửa
        '/deposit': (context) => DepositScreen(), // Route nạp tiền
        '/withdraw': (context) => WithdrawalScreen(), // Route rút tiền
        '/post_gig': (context) {
          // Cho phép nhận gig để chỉnh sửa (có thể là null)
          final gigToEdit = ModalRoute.of(context)?.settings.arguments as DocumentSnapshot?;
          return PostGigScreen(gigToEdit: gigToEdit);
        },
        '/applicants': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, String>;
          return ApplicantListScreen(gigId: args['gigId']!, gigTitle: args['gigTitle']!);
        },
        '/detail': (context) {
          // Ép kiểu arguments sang DocumentSnapshot để đảm bảo an toàn
          final gigData = ModalRoute.of(context)?.settings.arguments as DocumentSnapshot;
          return DetailScreen(gig: gigData);
        },
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return HomeScreen();
        }
        return LoginScreen();
      },
    );
  }
}