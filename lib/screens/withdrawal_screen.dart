import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WithdrawalScreen extends StatefulWidget {
  const WithdrawalScreen({super.key});

  @override
  _WithdrawalScreenState createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _bankInfoController = TextEditingController(); // Thêm controller cho thông tin ngân hàng
  bool _isLoading = false;

  Future<void> _submitWithdrawalRequest() async {
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

      // Tạo yêu cầu rút tiền
      final transactionRef = FirebaseFirestore.instance.collection('transactions').doc();
      await transactionRef.set({
        'transactionId': transactionRef.id,
        'userId': user.uid,
        'userName': userData['name'] ?? 'N/A',
        'type': 'withdrawal',
        'amount': amount,
        'bankInfo': _bankInfoController.text, // Lưu thông tin ngân hàng
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yêu cầu rút tiền đã được gửi thành công!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Rút Gig')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(labelText: 'Số tiền cần rút (VNĐ)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Vui lòng nhập số tiền.';
                  final amount = num.tryParse(value.replaceAll(',', ''));
                  if (amount == null || amount <= 0) return 'Số tiền không hợp lệ.';
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _bankInfoController,
                decoration: InputDecoration(labelText: 'Thông tin nhận tiền (STK, Ngân hàng, Tên)', border: OutlineInputBorder()),
                validator: (value) => (value == null || value.isEmpty) ? 'Vui lòng nhập thông tin nhận tiền.' : null,
              ),
              SizedBox(height: 24),
              _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _submitWithdrawalRequest,
                      style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 16)),
                      child: Text('Gửi yêu cầu'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}