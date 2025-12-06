import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ApplicantListScreen extends StatefulWidget {
  final String gigId;
  final String gigTitle;

  const ApplicantListScreen({Key? key, required this.gigId, required this.gigTitle}) : super(key: key);

  @override
  _ApplicantListScreenState createState() => _ApplicantListScreenState();
}

class _ApplicantListScreenState extends State<ApplicantListScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  String? _selectedWorkerUid; // UID của worker đã được chọn cho gig này
  String? _gigStatus; // Trạng thái hiện tại của gig

  @override
  void initState() {
    super.initState();
    _listenToGigChanges(); // Lắng nghe thay đổi của gig để cập nhật trạng thái
  }

  void _listenToGigChanges() {
    FirebaseFirestore.instance.collection('gigs').doc(widget.gigId).snapshots().listen((gigSnapshot) {
      if (gigSnapshot.exists) {
        final data = gigSnapshot.data() as Map<String, dynamic>;
        setState(() {
          _selectedWorkerUid = data['selected_worker_uid'];
          _gigStatus = data['status'];
        });
      }
    });
  }

  Future<void> _selectWorker(String workerUid, String workerName) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xác nhận chọn Worker'),
        content: Text('Bạn có chắc chắn muốn chọn "$workerName" cho gig "${widget.gigTitle}" không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Chọn', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Cập nhật gig: đặt trạng thái là 'in_progress' và lưu worker đã chọn
        final gigRef = FirebaseFirestore.instance.collection('gigs').doc(widget.gigId);
        await gigRef.update({
          'status': 'in_progress', // Trạng thái mới: đang tiến hành
          'selected_worker_uid': workerUid,
          'selected_worker_name': workerName,
          'selection_time': FieldValue.serverTimestamp(),
        });

        // Giai đoạn 3: Tạo phòng chat
        final employerDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).get();
        final employerName = (employerDoc.data() as Map<String, dynamic>)['name'] ?? 'Employer';

        final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.gigId);
        
        // Tin nhắn hệ thống đầu tiên
        final systemMessage = 'Hệ thống: $employerName đã chọn bạn cho công việc "${widget.gigTitle}". Hãy bắt đầu trao đổi.';

        // Tạo phòng chat
        await chatRef.set({
          'gig_id': widget.gigId,
          'gig_title': widget.gigTitle,
          'employer_uid': _currentUser!.uid,
          'employer_name': employerName,
          'worker_uid': workerUid,
          'worker_name': workerName,
          'participants': [_currentUser!.uid, workerUid], // Mảng để query dễ dàng
          'last_message': systemMessage,
          'last_message_time': FieldValue.serverTimestamp(),
        });

        // Thêm tin nhắn hệ thống vào sub-collection
        await chatRef.collection('messages').add({
          'sender_uid': 'system', // Tin nhắn từ hệ thống
          'text': systemMessage,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // TODO: Giai đoạn 3 - Gửi thông báo cho worker đã được chọn

        if (mounted) {
          setState(() { // Cập nhật trạng thái cục bộ sau khi chọn thành công
            _selectedWorkerUid = workerUid;
            _gigStatus = 'in_progress';
          });
          ScaffoldMessenger.of(context).showSnackBar( // Hiển thị thông báo
            SnackBar(content: Text('Đã chọn "$workerName" cho gig "${widget.gigTitle}".')),
          );
          // Không pop màn hình, để người dùng thấy trạng thái "Đã chọn"
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi chọn worker: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ứng viên cho: ${widget.gigTitle}'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('gigs')
            .doc(widget.gigId)
            .collection('applicants')
            .orderBy('applied_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('Chưa có ứng viên nào cho gig này.'));
          }

          return ListView.builder(
            padding: EdgeInsets.all(8.0),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var applicantDoc = snapshot.data!.docs[index];
              final data = applicantDoc.data() as Map<String, dynamic>;
              final workerUid = data['worker_uid'];

              // Xác định widget hiển thị ở cuối ListTile dựa trên trạng thái gig
              Widget trailingWidget;
              if (_gigStatus == 'in_progress' && _selectedWorkerUid == workerUid) {
                trailingWidget = Text('Đã chọn', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold));
              } else if (_gigStatus == 'in_progress' && _selectedWorkerUid != workerUid) {
                trailingWidget = ElevatedButton(
                  onPressed: null, // Vô hiệu hóa nút nếu đã có worker khác được chọn
                  child: Text('Đã có người được chọn'),
                );
              } else { // Gig đang ở trạng thái 'open' hoặc chưa có worker nào được chọn
                trailingWidget = ElevatedButton(
                  onPressed: () => _selectWorker(workerUid, data['worker_name']),
                  child: Text('Chọn người này'),
                );
              }

              return Card(
                margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: ListTile(
                  leading: CircleAvatar(child: Icon(Icons.person)),
                  title: Text(data['worker_name'] ?? 'N/A'),
                  subtitle: Text('Email: ${data['worker_email'] ?? 'N/A'}\nĐánh giá: ${data['worker_rating'] ?? 0.0}'),
                  trailing: trailingWidget,
                  onTap: () {
                    // TODO: Có thể điều hướng đến hồ sơ của worker
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}