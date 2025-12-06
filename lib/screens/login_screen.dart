import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatelessWidget {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  Future<void> signIn(BuildContext context) async {
    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // Sau khi đăng nhập, kiểm tra xem document người dùng có tồn tại không
      if (userCredential.user != null) {
        final userDocRef = FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid);
        final doc = await userDocRef.get();

        // Nếu document không tồn tại, tạo mới với thông tin cơ bản
        if (!doc.exists) {
          await userDocRef.set({
            'name': 'Người dùng mới', // Tên mặc định
            'email': userCredential.user!.email, // Lấy email từ auth
            'momo_phone': '',
            'wallet_balance': 0.0,
            'role': 'worker',
            'rating': 0.0,
            'review_count': 0,
          });
        }
      }

      // Sau khi đăng nhập thành công, điều hướng về root ('/')
      // AuthWrapper sẽ tự động chuyển đến HomeScreen
      Navigator.of(context).pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi đăng nhập: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Đăng Nhập')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(
                labelText: 'Mật Khẩu',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => signIn(context),
              child: Text('Đăng Nhập'),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/register'),
              child: Text('Chưa có tài khoản? Đăng ký'),
            ),
          ],
        ),
      ),
    );
  }
}