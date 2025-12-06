import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserManagementScreen extends StatefulWidget {
  @override
  _UserManagementScreenState createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Lỗi: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('Không có người dùng nào.'));
        }

        return ListView.builder(
          padding: EdgeInsets.all(8.0),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var userDoc = snapshot.data!.docs[index];
            final userData = userDoc.data() as Map<String, dynamic>;

            return Card(
              margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: ListTile(
                leading: CircleAvatar(
                  child: Icon(Icons.person),
                ),
                title: Text(userData['name'] ?? 'Người dùng ẩn danh'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(userData['email'] ?? 'Không có email'),
                    Text('Vai trò: ${userData['role'] ?? 'N/A'}', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text('Số dư ví: ${userData['wallet_balance'] ?? 0}', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete_user') {
                      // TODO: Triển khai chức năng xóa người dùng (cần cẩn thận với Firebase Auth)
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chức năng xóa người dùng chưa được triển khai.')));
                    } else if (value == 'change_role') {
                      // TODO: Triển khai chức năng thay đổi vai trò
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chức năng thay đổi vai trò chưa được triển khai.')));
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(value: 'change_role', child: Text('Thay đổi vai trò')),
                    const PopupMenuItem<String>(value: 'delete_user', child: Text('Xóa người dùng', style: TextStyle(color: Colors.red))),
                  ],
                ),
                onTap: () {
                  // TODO: Có thể điều hướng đến màn hình chi tiết người dùng
                },
              ),
            );
          },
        );
      },
    );
  }
}