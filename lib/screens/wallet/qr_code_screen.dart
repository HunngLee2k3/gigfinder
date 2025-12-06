import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class QRCodeScreen extends StatelessWidget {
  final double amount;
  final String captcha;

  const QRCodeScreen({
    super.key,
    required this.amount,
    required this.captcha,
  });

  // Hàm để lấy cấu hình thanh toán từ Firestore
  Future<DocumentSnapshot> _getPaymentConfig() {
    return FirebaseFirestore.instance.collection('app_settings').doc('payment_config').get();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Quét mã để nạp tiền')),
      body: FutureBuilder<DocumentSnapshot>(
        future: _getPaymentConfig(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('Lỗi: Không tìm thấy cấu hình thanh toán. Vui lòng liên hệ admin.'));
          }

          final config = snapshot.data!.data() as Map<String, dynamic>;
          final momoPhoneNumber = config['momo_phone_number'] as String?;

          if (momoPhoneNumber == null || momoPhoneNumber.isEmpty) {
            return Center(child: Text('Lỗi: Admin chưa cấu hình số điện thoại MoMo.'));
          }

          final message = 'Nap Gig $captcha';
          final qrData = 'momo://pay?phone=$momoPhoneNumber&amount=${amount.toInt()}&message=${Uri.encodeComponent(message)}';

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 250.0,
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'Vui lòng quét mã QR bằng ứng dụng MoMo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 16),
                Card(
                  color: Colors.yellow.shade100,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        Text('NỘI DUNG CHUYỂN KHOẢN:', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        SelectableText(
                          message,
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 4),
                        Text('(Giữ nguyên nội dung này để giao dịch được xác nhận)', textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  child: Text('Tôi đã chuyển khoản'),
                ),
              ],
            ),
          );
        },
      )
    );
  }
}