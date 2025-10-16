import 'package:flutter/material.dart';

class DetailScreen extends StatelessWidget {
  final dynamic gig; // Dữ liệu gig được truyền từ Home Screen

  DetailScreen({required this.gig});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(gig['title'] ?? 'Chi Tiết Gig'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tiêu đề: ${gig['title'] ?? 'Chưa có tiêu đề'}',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'Giá: ${gig['price'] ?? 'Chưa có giá'}',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 10),
            Text(
              'Địa điểm: ${gig['location'] ?? 'Chưa có địa điểm'}',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Quay lại Home Screen
              },
              child: Text('Quay lại'),
            ),
          ],
        ),
      ),
    );
  }
}