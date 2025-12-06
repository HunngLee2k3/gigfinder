import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Center(child: Text('Vui lòng đăng nhập để xem tin nhắn.'));
    }

    return StreamBuilder<QuerySnapshot>(
      // Query các phòng chat mà người dùng hiện tại là employer hoặc worker
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUser.uid)
          .orderBy('last_message_time', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Lỗi: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('Bạn chưa có cuộc trò chuyện nào.'));
        }

        final chatDocs = snapshot.data!.docs;

        return ListView.builder(
          itemCount: chatDocs.length,
          itemBuilder: (context, index) {
            final chatData = chatDocs[index].data() as Map<String, dynamic>;
            final chatId = chatDocs[index].id;

            // Xác định tên và avatar của người còn lại
            final otherParticipantUid = (chatData['participants'] as List)
                .firstWhere((uid) => uid != currentUser.uid, orElse: () => '');
            
            String otherParticipantName = 'Người dùng';
            if (currentUser.uid == chatData['employer_uid']) {
              otherParticipantName = chatData['worker_name'] ?? 'Worker';
            } else {
              otherParticipantName = chatData['employer_name'] ?? 'Employer';
            }

            final gigTitle = chatData['gig_title'] ?? 'Tên công việc không xác định';
            final displayTitle = '$otherParticipantName - "$gigTitle"';

            final lastMessage = chatData['last_message'] ?? 'Chưa có tin nhắn.';
            final lastMessageTime = (chatData['last_message_time'] as Timestamp?)?.toDate();

            return Card(
              margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  child: Icon(Icons.person),
                  // TODO: Lấy avatar thật của người dùng
                ),
                title: Text(
                  displayTitle, // Sử dụng tiêu đề mới để dễ phân biệt
                  style: TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: lastMessageTime != null
                    ? Text(
                        DateFormat('HH:mm').format(lastMessageTime),
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      )
                    : null,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        chatId: chatId,
                        otherParticipantName: displayTitle, // Truyền tiêu đề mới sang màn hình chat
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}