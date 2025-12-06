import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:random_string/random_string.dart';
import 'package:intl/intl.dart';
import 'qr_code_screen.dart';

class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key});

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  bool _isLoading = false;

  Future<void> _proceedToPayment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Người dùng chưa đăng nhập.');

      final amount = num.tryParse(_amountController.text.replaceAll(',', ''));
      if (amount == null || amount <= 0) {
        throw Exception('Số tiền không hợp lệ.');
      }

      // Lấy thông tin người dùng
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      if (userData == null) throw Exception('Không tìm thấy thông tin người dùng.');

      // Tạo mã captcha
      final captcha = randomAlphaNumeric(4).toUpperCase();

      // Tạo yêu cầu giao dịch
      final transactionRef = FirebaseFirestore.instance.collection('transactions').doc();
      await transactionRef.set({
        'transactionId': transactionRef.id,
        'userId': user.uid,
        'userName': userData['name'] ?? 'N/A',
        'type': 'deposit',
        'amount': amount,
        'captcha': captcha,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Điều hướng đến màn hình QR
      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => QRCodeScreen(
            amount: amount.toDouble(),
            captcha: captcha,
          ),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Nạp Gig')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Số tiền cần nạp (VNĐ)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Vui lòng nhập số tiền.';
                  final amount = num.tryParse(value.replaceAll(',', ''));
                  if (amount == null || amount <= 0) return 'Số tiền không hợp lệ.';
                  return null;
                },
              ),
              SizedBox(height: 24),
              _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _proceedToPayment,
                      child: Text('Tiếp tục'),
                      style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 16)),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}