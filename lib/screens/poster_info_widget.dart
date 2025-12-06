import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PosterInfoWidget extends StatelessWidget {
  final String uid;
  final TextStyle? style;

  const PosterInfoWidget({Key? key, required this.uid, this.style}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasData && snapshot.data!.exists) {
            final userData = snapshot.data!.data() as Map<String, dynamic>;
            return Text(
              'Người đăng: ${userData['name'] ?? 'N/A'}',
              style: style ?? TextStyle(fontSize: 12, color: Colors.grey),
            );
          }
          // Nếu không tìm thấy user, hiển thị UID
          return Text('Người đăng: $uid', style: style ?? TextStyle(fontSize: 12, color: Colors.red));
        }
        // Trong khi tải, hiển thị một placeholder
        return Text('Đang tải...', style: style ?? TextStyle(fontSize: 12, color: Colors.grey));
      },
    );
  }
}
