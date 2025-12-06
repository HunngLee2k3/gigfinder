import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DetailScreen extends StatefulWidget {
  final DocumentSnapshot gig;

  DetailScreen({required this.gig});

  @override
  _DetailScreenState createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  Map<String, dynamic>? _posterData;
  bool _isLoadingPoster = true;

  @override
  void initState() {
    super.initState();
    _fetchPosterDetails();
  }

  Future<void> _fetchPosterDetails() async {
    try {
      final posterId = (widget.gig.data() as Map<String, dynamic>)['poster_uid'];
      final doc = await FirebaseFirestore.instance.collection('users').doc(posterId).get();
      if (doc.exists) {
        setState(() {
          _posterData = doc.data();
        });
      }
    } catch (e) {
      print("Lỗi khi lấy thông tin người đăng: $e");
    } finally {
      setState(() => _isLoadingPoster = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Chuyển DocumentSnapshot thành Map để truy cập an toàn hơn
    final data = widget.gig.data() as Map<String, dynamic>;

    return Scaffold(
      appBar: AppBar(title: Text(data['title'] ?? 'Chi Tiết Gig')),
      body: ListView(
        children: [
          if (data.containsKey('image_url') && data['image_url'] != null)
            Image.network(
              data['image_url'],
              height: 250,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Container(height: 250, color: Colors.grey[300], child: Icon(Icons.image_not_supported)),
            )
          else
            Container(
              height: 250,
              color: Colors.grey[300],
              child: Icon(Icons.work, size: 80, color: Colors.grey[600]),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['title'] ?? 'Chưa có tiêu đề', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                Text('Giá: ${data['price'] ?? 'Chưa có giá'} VNĐ', style: TextStyle(fontSize: 20, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
                SizedBox(height: 10),
                Text('Địa điểm: ${data['location'] ?? 'Chưa có địa điểm'}', style: TextStyle(fontSize: 18)),
                Divider(height: 32),
                Text('Mô tả:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text(data['description'] ?? 'Không có mô tả.', style: TextStyle(fontSize: 16, height: 1.5)),
                Divider(height: 32),
                Text('Thông tin người đăng:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: _isLoadingPoster
                        ? Center(child: CircularProgressIndicator())
                        : _posterData != null
                            ? ListTile(
                                leading: CircleAvatar(
                                  child: Icon(Icons.person),
                                ),
                                title: Text(
                                  _posterData!['name'] ?? 'Người dùng ẩn danh',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(_posterData!['email'] ?? 'Không có email'),
                              )
                            : Text('Không thể tải thông tin người đăng.'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}