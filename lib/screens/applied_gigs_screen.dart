import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'applicant_list_screen.dart'; // Import màn hình danh sách ứng viên

class AppliedGigsScreen extends StatefulWidget {
  AppliedGigsScreen({super.key});

  @override
  State<AppliedGigsScreen> createState() => _AppliedGigsScreenState();
}

class _AppliedGigsScreenState extends State<AppliedGigsScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  void _editGig(DocumentSnapshot gig) {
    Navigator.pushNamed(context, '/post_gig', arguments: gig);
  }

  Future<void> _deleteGig(String gigId, String gigTitle) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xác nhận xóa'),
        content: Text('Bạn có chắc chắn muốn xóa gig "$gigTitle"?'),
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
            SnackBar(content: Text('Đã xóa gig thành công.')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi xóa gig: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: 'Việc đã nhận'),
              Tab(text: 'Đã đăng'),
            ],
          ),
          Expanded(
            child: TabBarView(
          children: [
            // Tab 1: Gigs đã ứng tuyển
            StreamBuilder<QuerySnapshot>(
              // Sửa lại query: Lấy các gig mà worker này đã được chọn
              stream: FirebaseFirestore.instance
                  .collection('gigs')
                  .where('selected_worker_uid', isEqualTo: currentUser!.uid)
                  .orderBy('selection_time', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('Bạn chưa được chọn cho gig nào.'));
                }
                return ListView(
                  padding: EdgeInsets.all(8.0),
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final gigStatus = data['status'];
                    Widget statusWidget;

                    if (gigStatus == 'completed') {
                      statusWidget = Text('Đã hoàn thành', style: TextStyle(color: Colors.green));
                    } else if (gigStatus == 'in_progress') {
                      statusWidget = Text('Đang tiến hành', style: TextStyle(color: Colors.blue));
                    } else {
                      statusWidget = Text('Trạng thái: ${gigStatus ?? 'N/A'}');
                    }

                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      child: ListTile(
                        leading: Icon(Icons.work_history_outlined, color: Theme.of(context).primaryColor),
                        title: Text(data['title'] ?? 'N/A'),
                        subtitle: Text('Giá: ${data['price'] ?? '0'} - Tại: ${data['location'] ?? 'N/A'}'),
                        trailing: statusWidget,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            // Tab 2: Gigs đã đăng - Đã hoàn thiện
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('gigs')
                  .where('poster_uid', isEqualTo: currentUser!.uid)
                  .orderBy('created_at', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('Bạn chưa đăng gig nào.'));
                }
                return ListView(
                  padding: EdgeInsets.all(8.0),
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final gigStatus = data['status'];

                    Widget subtitleWidget = Text('Giá: ${data['price'] ?? '0'} - Tại: ${data['location'] ?? 'N/A'}');
                    Color cardColor = Colors.white;

                    if (gigStatus == 'completed') {
                      subtitleWidget = Text('Trạng thái: Đã hoàn thành', style: TextStyle(color: Colors.green));
                      cardColor = Colors.green.shade50;
                    } else if (gigStatus == 'in_progress') {
                      subtitleWidget = Text('Trạng thái: Đang tiến hành', style: TextStyle(color: Colors.blue));
                    }

                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      color: cardColor,
                      child: ListTile(
                        leading: Icon(Icons.post_add, color: Theme.of(context).primaryColor),
                        title: Text(data['title'] ?? 'N/A'),
                        subtitle: subtitleWidget,
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _editGig(doc);
                            } else if (value == 'delete') {
                              _deleteGig(doc.id, data['title'] ?? 'N/A');
                            }
                            // TODO: Thêm tùy chọn để xem danh sách ứng viên
                            else if (value == 'view_applicants') {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => ApplicantListScreen(
                                gigId: doc.id,
                                gigTitle: data['title'] ?? 'N/A',
                              )));
                            }
                          },
                          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                            const PopupMenuItem<String>(value: 'view_applicants', child: Text('Xem ứng viên')),
                            const PopupMenuItem<String>(value: 'edit', child: Text('Chỉnh sửa')),
                            const PopupMenuItem<String>(value: 'delete', child: Text('Xóa', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                        onTap: () {
                          // Khi nhấn vào ListTile, mặc định sẽ xem danh sách ứng viên
                          // Hoặc bạn có thể giữ lại _editGig(doc) nếu muốn ưu tiên chỉnh sửa
                          Navigator.push(context, MaterialPageRoute(builder: (context) => ApplicantListScreen(
                            gigId: doc.id,
                            gigTitle: data['title'] ?? 'N/A',
                          )));
                        },
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
          ),
        ],
      ),
    );
  }
}