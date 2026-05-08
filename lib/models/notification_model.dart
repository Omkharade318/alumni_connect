import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType { 
  message, 
  connectionRequest,
  donation,
  event,
  job,
  news
}

class NotificationModel {
  final String id;
  final String userId; // Recipient
  final String senderId;
  final String senderName;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime createdAt;
  final bool isRead;
  final String? relatedId; // conversationId for messages, or targetUserId/senderId

  NotificationModel({
    required this.id,
    required this.userId,
    required this.senderId,
    required this.senderName,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.relatedId,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      type: NotificationType.values.firstWhere((e) => e.toString().split('.').last == data['type'], orElse: () => NotificationType.message),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      relatedId: data['relatedId'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'senderId': senderId,
      'senderName': senderName,
      'title': title,
      'body': body,
      'type': type.toString().split('.').last,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': isRead,
      'relatedId': relatedId,
    };
  }
}
