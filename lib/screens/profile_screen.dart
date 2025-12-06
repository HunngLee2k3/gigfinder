import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    // Sau khi đăng xuất, xóa tất cả các route cũ và quay về màn hình ban đầu (AuthWrapper).
    // Đảm bảo context vẫn còn hợp lệ trước khi điều hướng
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(currentUser?.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('Không tìm thấy thông tin người dùng.'));
          }
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // Hiển thị avatar người dùng
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: (userData.containsKey('avatar_url') && userData['avatar_url'] != null)
                          ? NetworkImage(userData['avatar_url'])
                          : null,
                      child: (userData.containsKey('avatar_url') && userData['avatar_url'] != null)
                          ? null
                          : Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.grey.shade400,
                            ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          userData['name'] ?? 'Chưa có tên',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: Icon(Icons.edit, size: 20, color: Colors.grey),
                          onPressed: () => Navigator.pushNamed(context, '/edit_profile'),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      currentUser?.email ?? "Not logged in",
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        RatingBarIndicator(
                          rating: (userData['rating'] as num?)?.toDouble() ?? 0.0,
                          itemBuilder: (context, index) => Icon(
                            Icons.star,
                            color: Colors.amber,
                          ),
                          itemCount: 5,
                          itemSize: 20.0,
                          direction: Axis.horizontal,
                        ),
                        SizedBox(width: 8),
                        Text('(${(userData['review_count'] as num?)?.toInt() ?? 0} đánh giá)',
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(thickness: 1),
              ListTile(
                leading: Icon(Icons.account_balance_wallet_outlined),
                title: Text('Số dư Gig: ${userData['wallet_balance'] ?? 0}'),
                onTap: () {},
              ),
              ListTile(
                leading: Icon(Icons.add_card_outlined),
                title: Text('Nạp Gig'),
                trailing: Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, '/deposit'),
              ),
              ListTile(
                leading: Icon(Icons.price_check_outlined),
                title: Text('Rút Gig'),
                trailing: Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, '/withdraw'),
              ),
              Divider(thickness: 1),
              ListTile(
                leading: Icon(Icons.logout, color: Colors.red),
                title: Text('Đăng xuất', style: TextStyle(color: Colors.red)),
                onTap: () => _signOut(context),
              ),
            ],
          );
        },
      );
  }
}
