import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminGigListScreen extends StatefulWidget {
  @override
  _AdminGigListScreenState createState() => _AdminGigListScreenState();
}

class _AdminGigListScreenState extends State<AdminGigListScreen> {
  Future<void> _deleteGig(String gigId, String gigTitle) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xác nhận xóa Gig'),
        content: Text('Bạn có chắc chắn muốn xóa gig "$gigTitle" vĩnh viễn không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('gigs').doc(gigId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã xóa gig "$gigTitle" thành công.')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi xóa gig: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('gigs').orderBy('created_at', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Lỗi: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('Không có gig nào để quản lý.'));
        }

        return ListView.builder(
          padding: EdgeInsets.all(8.0),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var gig = snapshot.data!.docs[index];
            final data = gig.data() as Map<String, dynamic>;
            final posterUid = data['poster_uid'];

            return Card(
              margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: ListTile(
                leading: data.containsKey('image_url') && data['image_url'] != null
                    ? CircleAvatar(
                        backgroundImage: NetworkImage(data['image_url']),
                        onBackgroundImageError: (exception, stackTrace) => Icon(Icons.work),
                      )
                    : CircleAvatar(child: Icon(Icons.work)),
                title: Text(data['title'] ?? 'N/A'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Giá: ${data['price'] ?? '0'} - Tại: ${data['location'] ?? 'N/A'}'),
                    Text('Người đăng: $posterUid', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') {
                      _deleteGig(gig.id, data['title'] ?? 'N/A');
                    }
                    // TODO: Có thể thêm tùy chọn chỉnh sửa cho admin ở đây
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(value: 'delete', child: Text('Xóa Gig', style: TextStyle(color: Colors.red))),
                  ],
                ),
                onTap: () => Navigator.pushNamed(context, '/detail', arguments: gig),
              ),
            );
          },
        );
      },
    );
  }
}