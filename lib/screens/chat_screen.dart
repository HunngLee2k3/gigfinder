import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherParticipantName;

  const ChatScreen({
    Key? key,
    required this.chatId,
    required this.otherParticipantName,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  StreamSubscription? _gigSubscription;
  Map<String, dynamic>? _gigData;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _listenToGigChanges();
  }

  @override
  void dispose() {
    _gigSubscription?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  void _listenToGigChanges() {
    // widget.chatId chính là gigId
    _gigSubscription = FirebaseFirestore.instance
        .collection('gigs')
        .doc(widget.chatId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        setState(() {
          _gigData = snapshot.data();
        });
        print('ChatScreen: Gig data updated: $_gigData'); // Debug print
      }
    });
  }

  Future<void> _requestCompletion() async {
    await FirebaseFirestore.instance.collection('gigs').doc(widget.chatId).update({
      'completion_status': 'requested_by_worker',
    });
    final workerName = _gigData?['selected_worker_name'] ?? 'Worker';
    await _sendSystemMessage('Hệ thống: $workerName đã yêu cầu hoàn thành công việc.');
  }

  // Hàm helper để gửi tin nhắn hệ thống
  Future<void> _sendSystemMessage(String text) async {
    final messageData = {
      'sender_uid': 'system',
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    };

    // Thêm tin nhắn mới vào sub-collection 'messages'
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add(messageData);

    // Cập nhật thông tin tin nhắn cuối cùng trên document chat chính
    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
      'last_message': text,
      'last_message_time': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _confirmPaymentAndCompleteGig() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final gigRef = FirebaseFirestore.instance.collection('gigs').doc(widget.chatId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // 1. Đọc dữ liệu cần thiết trong transaction
        final gigSnapshot = await transaction.get(gigRef);
        if (!gigSnapshot.exists) {
          throw Exception("Gig không còn tồn tại!");
        }
        final gigData = gigSnapshot.data()!;
        final gigPrice = gigData['price'] as num;
        final employerUid = gigData['poster_uid'];
        final workerUid = gigData['selected_worker_uid'];

        final employerRef = FirebaseFirestore.instance.collection('users').doc(employerUid);
        final workerRef = FirebaseFirestore.instance.collection('users').doc(workerUid);

        final employerSnapshot = await transaction.get(employerRef);
        final workerSnapshot = await transaction.get(workerRef);

        if (!employerSnapshot.exists || !workerSnapshot.exists) {
          throw Exception("Không tìm thấy thông tin người dùng.");
        }

        final employerBalance = (employerSnapshot.data()!['wallet_balance'] as num);

        // 2. Kiểm tra điều kiện
        if (employerBalance < gigPrice) {
          throw Exception("Số dư của người thuê không đủ để thanh toán.");
        }

        // 3. Thực hiện các thao tác ghi
        final newEmployerBalance = employerBalance - gigPrice;
        final newWorkerBalance = (workerSnapshot.data()!['wallet_balance'] as num) + gigPrice;

        transaction.update(employerRef, {'wallet_balance': newEmployerBalance});
        transaction.update(workerRef, {'wallet_balance': newWorkerBalance});
        transaction.update(gigRef, {
          'status': 'completed',
          'completion_status': 'confirmed_by_employer',
        });
      });

      // Gửi tin nhắn hệ thống sau khi thanh toán thành công
      await _sendSystemMessage('Hệ thống: Công việc đã được hoàn thành và thanh toán.');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Thanh toán thành công! Gig đã hoàn thành.')),
        );
        _promptForReview(
          // Sửa lỗi: Xác định isEmployer và revieweeUid trong phạm vi của hàm này
          _currentUser?.uid == _gigData?['poster_uid'] ? _gigData!['selected_worker_uid'] : _gigData!['poster_uid'],
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi thanh toán: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _promptForReview(String revieweeUid) {
    double _rating = 3; // Default rating
    final _commentController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false, // Người dùng phải đánh giá
      builder: (context) => AlertDialog(
        title: Text('Đánh giá đối tác của bạn'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Bạn cảm thấy thế nào về trải nghiệm này?'),
              SizedBox(height: 16),
              RatingBar.builder(
                initialRating: _rating,
                minRating: 1,
                direction: Axis.horizontal,
                allowHalfRating: false,
                itemCount: 5,
                itemPadding: EdgeInsets.symmetric(horizontal: 4.0),
                itemBuilder: (context, _) => Icon(Icons.star, color: Colors.amber),
                onRatingUpdate: (rating) {
                  _rating = rating;
                },
              ),
              SizedBox(height: 16),
              TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  labelText: 'Để lại nhận xét (tùy chọn)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _submitReview(revieweeUid, _rating, _commentController.text.trim());
            },
            child: Text('Gửi đánh giá'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitReview(String revieweeUid, double rating, String comment) async {
    final reviewerUid = _currentUser!.uid;
    final reviewerDoc = await FirebaseFirestore.instance.collection('users').doc(reviewerUid).get();
    final reviewerName = (reviewerDoc.data() as Map<String, dynamic>)['name'] ?? 'Người dùng ẩn danh';

    final revieweeRef = FirebaseFirestore.instance.collection('users').doc(revieweeUid);
    final reviewRef = FirebaseFirestore.instance.collection('reviews').doc();

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final revieweeSnapshot = await transaction.get(revieweeRef);
        if (!revieweeSnapshot.exists) {
          throw Exception("Người dùng được đánh giá không tồn tại.");
        }

        final revieweeData = revieweeSnapshot.data()!;
        final oldRating = (revieweeData['rating'] as num?)?.toDouble() ?? 0.0;
        final oldReviewCount = (revieweeData['review_count'] as num?)?.toInt() ?? 0;

        final newReviewCount = oldReviewCount + 1;
        final newRating = ((oldRating * oldReviewCount) + rating) / newReviewCount;

        transaction.update(revieweeRef, {
          'rating': newRating,
          'review_count': newReviewCount,
        });

        transaction.set(reviewRef, {
          'gig_id': widget.chatId,
          'reviewer_uid': reviewerUid,
          'reviewer_name': reviewerName,
          'reviewee_uid': revieweeUid,
          'rating': rating,
          'comment': comment,
          'created_at': FieldValue.serverTimestamp(),
        });
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cảm ơn bạn đã đánh giá!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi gửi đánh giá: $e')));
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) {
      return;
    }

    final messageText = _messageController.text.trim();
    _messageController.clear();

    final messageData = {
      'sender_uid': _currentUser!.uid,
      'text': messageText,
      'timestamp': FieldValue.serverTimestamp(),
    };

    // Thêm tin nhắn mới vào sub-collection 'messages'
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add(messageData);

    // Cập nhật thông tin tin nhắn cuối cùng trên document chat chính
    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
      'last_message': messageText,
      'last_message_time': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isEmployer = _gigData != null && _gigData!['poster_uid'] == _currentUser?.uid;
    final bool isWorker = _gigData != null && _gigData!['selected_worker_uid'] == _currentUser?.uid;
    final String? completionStatus = _gigData?['completion_status'];
    final String? gigStatus = _gigData?['status'];

    print('ChatScreen Build Debug:');
    print('  _currentUser?.uid: ${_currentUser?.uid}');
    print('  _gigData: $_gigData');
    print('  isEmployer: $isEmployer');
    print('  isWorker: $isWorker');
    print('  completionStatus: $completionStatus');
    print('  gigStatus: $gigStatus');
    print('  Condition (isWorker && completionStatus == null): ${isWorker && completionStatus == null}');

    Widget? actionButton;
    if (_isProcessing) {
      actionButton = Padding(padding: const EdgeInsets.all(8.0), child: CircularProgressIndicator(color: Colors.white));
    } else if (gigStatus == 'completed') {
      actionButton = Center(child: Text('Đã hoàn thành', style: TextStyle(fontWeight: FontWeight.bold)));
    } else if (isWorker && completionStatus == null) {
      actionButton = TextButton(onPressed: _requestCompletion, child: Text('Yêu cầu hoàn thành'));
    } else if (isWorker && completionStatus == 'requested_by_worker') {
      actionButton = Center(child: Text('Chờ xác nhận'));
    } else if (isEmployer && completionStatus == 'requested_by_worker') {
      actionButton = TextButton(onPressed: _confirmPaymentAndCompleteGig, child: Text('Xác nhận thanh toán', style: TextStyle(fontWeight: FontWeight.bold)));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.otherParticipantName,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (actionButton != null)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Center(child: actionButton),
            )
          else if (_gigData == null) // Show loading if gig data is not yet available
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(child: CircularProgressIndicator(color: Colors.white)),
            )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('Bắt đầu cuộc trò chuyện!'));
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  padding: EdgeInsets.all(10.0),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index].data() as Map<String, dynamic>;
                    final isMe = message['sender_uid'] == _currentUser!.uid;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                        decoration: BoxDecoration(
                          color: isMe ? Theme.of(context).primaryColor : Colors.grey[300],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          message['text'] ?? '',
                          style: TextStyle(color: isMe ? Colors.white : Colors.black),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageComposer(),
        ],
      ),
    );
  }

  Widget _buildMessageComposer() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.0),
      height: 70.0,
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration.collapsed(hintText: 'Nhập tin nhắn...'),
            ),
          ),
          IconButton(
            icon: Icon(Icons.send),
            iconSize: 25.0,
            color: Theme.of(context).primaryColor,
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}