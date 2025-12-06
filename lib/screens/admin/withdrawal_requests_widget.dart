import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class WithdrawalRequestsWidget extends StatelessWidget {
  const WithdrawalRequestsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .where('type', isEqualTo: 'withdrawal')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('Không có yêu cầu rút tiền nào.'));
        }

        return ListView(
          padding: EdgeInsets.all(8),
          children: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Card(
              child: ListTile(
                title: Text('Người rút: ${data['userName']}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Số tiền rút: ${NumberFormat('#,##0').format(data['amount'])} VNĐ'),
                    Text('Thực nhận: ${NumberFormat('#,##0').format(data['finalAmount'])} VNĐ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Số MoMo: ${data['userMomoPhone'] ?? 'Chưa có'}', style: TextStyle(color: Colors.blue)),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: Icon(Icons.close, color: Colors.red), onPressed: () { /* TODO: Logic từ chối */ }),
                    IconButton(icon: Icon(Icons.check, color: Colors.green), onPressed: () { /* TODO: Logic xác nhận */ }),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}