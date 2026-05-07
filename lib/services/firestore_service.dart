import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../models/event_model.dart';
import '../models/message_model.dart';
import '../models/donation_model.dart';
import '../models/donation_contribution_model.dart';
import '../models/notification_model.dart';
import '../models/job_model.dart';
import '../models/news_model.dart';
import '../models/comment_model.dart';
import 'notification_service.dart';
import 'storage_service.dart';
import '../utils/constants.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createUser(UserModel user) async {
    await _firestore.collection(AppConstants.usersCollection).doc(user.uid).set(user.toFirestore());
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _firestore.collection(AppConstants.usersCollection).doc(uid).get();
    return doc.exists ? UserModel.fromFirestore(doc) : null;
  }

  Stream<UserModel?> getUserStream(String uid) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }

  Future<List<String>> getAllUserIds() async {
    final query = await _firestore.collection(AppConstants.usersCollection).get();
    return query.docs.map((doc) => doc.id).toList();
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _firestore.collection(AppConstants.usersCollection).doc(uid).update(data);
  }

  Stream<List<UserModel>> getAlumniStream({
    String? branch,
    String? batch,
    String? degree,
    String? search,
    List<String>? excludeUserIds,
    List<String>? includeUserIds,
  }) {
    Query query = _firestore.collection(AppConstants.usersCollection);
    if (branch != null && branch.isNotEmpty) query = query.where('branch', isEqualTo: branch);
    if (batch != null && batch.isNotEmpty) query = query.where('batch', isEqualTo: batch);
    if (degree != null && degree.isNotEmpty) query = query.where('degree', isEqualTo: degree);
    return query.snapshots().map((snapshot) {
      var users = snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
      if (excludeUserIds != null && excludeUserIds.isNotEmpty) {
        users = users.where((u) => !excludeUserIds.contains(u.uid)).toList();
      }
      if (includeUserIds != null) {
        users = users.where((u) => includeUserIds.contains(u.uid)).toList();
      }
      return users;
    });
  }

  Future<List<UserModel>> searchAlumni({
    String? name,
    String? branch,
    String? batch,
    String? city,
    List<String>? excludeUserIds,
  }) async {
    Query query = _firestore.collection(AppConstants.usersCollection);
    if (branch != null && branch.isNotEmpty) query = query.where('branch', isEqualTo: branch);
    if (batch != null && batch.isNotEmpty) query = query.where('batch', isEqualTo: batch);
    if (city != null && city.isNotEmpty) query = query.where('city', isEqualTo: city);

    final snapshot = await query.get();
    var users = snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    if (name != null && name.isNotEmpty) {
      users = users.where((u) => u.name.toLowerCase().contains(name.toLowerCase())).toList();
    }
    if (excludeUserIds != null && excludeUserIds.isNotEmpty) {
      users = users.where((u) => !excludeUserIds.contains(u.uid)).toList();
    }
    return users;
  }

  Future<void> createPost(PostModel post) async {
    await _firestore.collection(AppConstants.postsCollection).doc(post.id).set(post.toFirestore());
  }

  Stream<List<PostModel>> getPostsStream() {
    return _firestore
        .collection(AppConstants.postsCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => PostModel.fromFirestore(doc)).toList());
  }

  Future<void> likePost(String postId, String userId, bool isLiked) async {
    final docRef = _firestore.collection(AppConstants.postsCollection).doc(postId);
    if (isLiked) {
      await docRef.update({'likes': FieldValue.arrayRemove([userId])});
    } else {
      await docRef.update({'likes': FieldValue.arrayUnion([userId])});
    }
  }

  Future<void> addComment(String postId) async {
    await _firestore.collection(AppConstants.postsCollection).doc(postId).update({
      'commentCount': FieldValue.increment(1),
    });
  }

  Stream<List<CommentModel>> getCommentsStream(String postId) {
    return _firestore
        .collection(AppConstants.postsCollection)
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => CommentModel.fromFirestore(doc)).toList());
  }

  Future<void> createComment(String postId, CommentModel comment) async {
    await _firestore
        .collection(AppConstants.postsCollection)
        .doc(postId)
        .collection('comments')
        .add(comment.toFirestore());
    await addComment(postId);
  }

  Future<void> updateComment(String postId, String commentId, String newContent) async {
    await _firestore
        .collection(AppConstants.postsCollection)
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .update({'content': newContent});
  }

  Future<void> deleteComment(String postId, String commentId) async {
    await _firestore
        .collection(AppConstants.postsCollection)
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .delete();
    await _firestore.collection(AppConstants.postsCollection).doc(postId).update({
      'commentCount': FieldValue.increment(-1),
    });
  }

  Stream<EventModel?> getEventStream(String eventId) {
    return _firestore
        .collection(AppConstants.eventsCollection)
        .doc(eventId)
        .snapshots()
        .map((doc) => doc.exists ? EventModel.fromFirestore(doc) : null);
  }

  Stream<List<EventModel>> getEventsStream() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    
    return _firestore
        .collection(AppConstants.eventsCollection)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => EventModel.fromFirestore(doc)).toList());
  }

  Future<void> createEvent(EventModel event, {String? senderName}) async {
    await _firestore.collection(AppConstants.eventsCollection).doc(event.id).set(event.toFirestore());
    await notifyAllUsers(
      title: 'New Event: ${event.title}',
      body: 'A new event has been scheduled. Tap to check it out!',
      type: NotificationType.event,
      relatedId: event.id,
      senderId: event.organizerId ?? 'admin',
      senderName: senderName ?? 'Admin',
    );
  }

  /// Updates only the provided fields. Callers must avoid sending fields
  /// like `attendees` unless they explicitly intend to overwrite them.
  Future<void> updateEventDetails(String eventId, Map<String, dynamic> data) async {
    await _firestore.collection(AppConstants.eventsCollection).doc(eventId).update(data);
  }

  Future<void> deleteEvent(String eventId) async {
    final doc = await _firestore.collection(AppConstants.eventsCollection).doc(eventId).get();
    if (doc.exists) {
      final imageUrl = doc.data()?['imageUrl'] as String?;
      if (imageUrl != null) {
        await StorageService().deleteImageFromUrl(imageUrl);
      }
      await doc.reference.delete();
    }
  }

  Future<void> cleanupExpiredData() async {
    final now = DateTime.now();
    
    // 1. Cleanup News (older than 5 days)
    final fiveDaysAgo = now.subtract(const Duration(days: 5));
    final expiredNews = await _firestore.collection(AppConstants.newsCollection)
        .where('createdAt', isLessThan: Timestamp.fromDate(fiveDaysAgo))
        .get();
    
    for (var doc in expiredNews.docs) {
      await deleteNews(doc.id);
    }

    // 2. Cleanup Events (expired the next day of the event date)
    // If event is on Oct 27, it expires on Oct 28.
    // So if today is Oct 28 or later, it's expired.
    // Logic: event.date < today_start (where today_start is Oct 28 00:00)
    final todayStart = DateTime(now.year, now.month, now.day);
    final expiredEvents = await _firestore.collection(AppConstants.eventsCollection)
        .where('date', isLessThan: Timestamp.fromDate(todayStart))
        .get();

    for (var doc in expiredEvents.docs) {
      await deleteEvent(doc.id);
    }
  }

  Future<void> rsvpEvent(String eventId, String userId, bool attending) async {
    final docRef = _firestore.collection(AppConstants.eventsCollection).doc(eventId);
    if (attending) {
      await docRef.update({'attendees': FieldValue.arrayUnion([userId])});
    } else {
      await docRef.update({'attendees': FieldValue.arrayRemove([userId])});
    }
  }

  Stream<List<DonationModel>> getDonationsStream() {
    return _firestore
        .collection(AppConstants.donationsCollection)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => DonationModel.fromFirestore(doc)).toList());
  }

  Future<void> createDonation(DonationModel donation, {String? senderId, String? senderName}) async {
    await _firestore.collection(AppConstants.donationsCollection).doc(donation.id).set(donation.toFirestore());
    await notifyAllUsers(
      title: 'New Donation Campaign',
      body: 'Support our ${donation.category}: ${donation.title}',
      type: NotificationType.donation,
      relatedId: donation.id,
      senderId: senderId ?? 'admin',
      senderName: senderName ?? 'Admin',
    );
  }

  /// Updates only the provided fields. Callers must avoid sending
  /// `collectedAmount` unless they intend to modify the collected total.
  Future<void> updateDonationDetails(String donationId, Map<String, dynamic> data) async {
    await _firestore.collection(AppConstants.donationsCollection).doc(donationId).update(data);
  }

  Future<void> deleteDonation(String donationId) async {
    final doc = await _firestore.collection(AppConstants.donationsCollection).doc(donationId).get();
    if (doc.exists) {
      final imageUrl = doc.data()?['imageUrl'] as String?;
      if (imageUrl != null) {
        await StorageService().deleteImageFromUrl(imageUrl);
      }
      await doc.reference.delete();
    }
  }

  Stream<List<DonationContributionModel>> getDonationContributionsStream(String donationId) {
    return _firestore
        .collection(AppConstants.donationsCollection)
        .doc(donationId)
        .collection('contributions')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => DonationContributionModel.fromFirestore(doc)).toList());
  }
  
  Future<void> addDonation(String donationId, double amount, String userId) async {
    await _firestore.collection(AppConstants.donationsCollection).doc(donationId).update({
      'collectedAmount': FieldValue.increment(amount),
    });
    await _firestore.collection(AppConstants.donationsCollection).doc(donationId).collection('contributions').add({
      'userId': userId,
      'amount': amount,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
  
  Future<void> updateLastViewedDonations(String userId) async {
    await _firestore.collection(AppConstants.usersCollection).doc(userId).update({
      'lastViewedDonations': FieldValue.serverTimestamp(),
    });
  }

  Stream<int> getUnreadDonationsCountStream(String userId) {
    return _firestore.collection(AppConstants.usersCollection).doc(userId).snapshots().switchMap((userDoc) {
      if (!userDoc.exists) return Stream.value(0);
      final lastViewed = (userDoc.data() as Map<String, dynamic>)['lastViewedDonations'] as Timestamp?;
      
      Query<Map<String, dynamic>> query = _firestore.collection(AppConstants.donationsCollection);
      if (lastViewed != null) {
        query = query.where('createdAt', isGreaterThan: lastViewed);
      }
      
      return query.snapshots().map((snapshot) => snapshot.docs.length);
    });
  }

  Future<String> getOrCreateConversation(String user1, String user2) async {
    final participants = [user1, user2]..sort();
    final query = await _firestore
        .collection(AppConstants.conversationsCollection)
        .where('participants', isEqualTo: participants)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) return query.docs.first.id;

    final docRef = await _firestore.collection(AppConstants.conversationsCollection).add({
      'participants': participants,
      'lastMessage': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadCounts': {
        user1: 0,
        user2: 0,
      },
    });
    return docRef.id;
  }

  Future<void> sendMessage(String conversationId, MessageModel message) async {
    await _firestore
        .collection(AppConstants.conversationsCollection)
        .doc(conversationId)
        .collection('messages')
        .add(message.toFirestore());
    await _firestore.collection(AppConstants.conversationsCollection).doc(conversationId).update({
      'lastMessage': message.content,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadCounts.${message.receiverId}': FieldValue.increment(1),
    });

    // Send notification to recipient
    final conversationDoc = await _firestore.collection(AppConstants.conversationsCollection).doc(conversationId).get();
    final participants = List<String>.from(conversationDoc['participants']);
    final recipientId = participants.firstWhere((id) => id != message.senderId);
    
    final sender = await getUser(message.senderId);
    
    await NotificationService().createNotification(NotificationModel(
      id: '',
      userId: recipientId,
      senderId: message.senderId,
      senderName: sender?.name ?? 'Someone',
      title: 'New Message',
      body: message.content.length > 50 ? '${message.content.substring(0, 47)}...' : message.content,
      type: NotificationType.message,
      createdAt: DateTime.now(),
      relatedId: conversationId,
    ));
  }

  Stream<List<DocumentSnapshot>> getConversationsStream(String userId) {
    return _firestore
        .collection(AppConstants.conversationsCollection)
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      final docs = snapshot.docs;
      docs.sort((a, b) {
        final aTime = (a.data() as Map<String, dynamic>)['lastMessageAt'] as Timestamp?;
        final bTime = (b.data() as Map<String, dynamic>)['lastMessageAt'] as Timestamp?;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });
      return docs;
    });
  }

  Future<void> markMessagesAsRead(String conversationId, String userId) async {
    // 1. Reset unread count in conversation document
    await _firestore
        .collection(AppConstants.conversationsCollection)
        .doc(conversationId)
        .update({'unreadCounts.$userId': 0});

    // 2. Mark individual messages as read
    final query = await _firestore
        .collection(AppConstants.conversationsCollection)
        .doc(conversationId)
        .collection('messages')
        .where('receiverId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    if (query.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (var doc in query.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> notifyAllUsers({
    required String title,
    required String body,
    required NotificationType type,
    String? relatedId,
    required String senderId,
    required String senderName,
  }) async {
    final userIds = await getAllUserIds();
    final batch = _firestore.batch();
    
    for (var userId in userIds) {
      if (userId == senderId) continue; // Don't notify the sender
      
      final docRef = _firestore.collection(AppConstants.notificationsCollection).doc();
      final notification = NotificationModel(
        id: docRef.id,
        userId: userId,
        senderId: senderId,
        senderName: senderName,
        title: title,
        body: body,
        type: type,
        createdAt: DateTime.now(),
        relatedId: relatedId,
      );
      batch.set(docRef, notification.toFirestore());
    }
    
    await batch.commit();
  }

  Stream<int> getUnreadMessagesCountStream(String userId) {
    // This is a bit tricky with nested collections in Firestore.
    // For now, we'll listen to all conversations the user is part of, 
    // and for each one, we'll sum up the unread count.
    // Alternatively, we could keep an unreadCount per participant in the conversation doc itself.
    // Let's try the unreadCount in conversation doc approach as it's more efficient.
    
    // BUT, for now, let's use a simpler approach if possible.
    // Actually, listening to all messages across all conversations is expensive.
    // Let's add 'unreadCount' to the conversation document for each participant.
    // Map<String, int> unreadCounts = {userId1: 0, userId2: 5}
    
    return _firestore
        .collection(AppConstants.conversationsCollection)
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          int total = 0;
          for (var doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final unreadCounts = data['unreadCounts'] as Map<String, dynamic>? ?? {};
            total += (unreadCounts[userId] ?? 0) as int;
          }
          return total;
        });
  }

  Stream<List<MessageModel>> getMessagesStream(String conversationId) {
    return _firestore
        .collection(AppConstants.conversationsCollection)
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => MessageModel.fromFirestore(doc)).toList());
  }

  Future<String?> getConnectionStatus(String userId, String targetUserId) async {
    final query = await _firestore.collection(AppConstants.connectionsCollection)
        .where('userId', isEqualTo: userId)
        .where('targetUserId', isEqualTo: targetUserId)
        .get();
    
    if (query.docs.isNotEmpty) {
      return query.docs.first['status'] as String;
    }

    final receivedQuery = await _firestore.collection(AppConstants.connectionsCollection)
        .where('userId', isEqualTo: targetUserId)
        .where('targetUserId', isEqualTo: userId)
        .get();

    if (receivedQuery.docs.isNotEmpty) {
      return receivedQuery.docs.first['status'] as String;
    }

    return null;
  }

  Future<bool> isConnected(String userId, String targetUserId) async {
    final sent = await _firestore.collection(AppConstants.connectionsCollection)
        .where('userId', isEqualTo: userId)
        .where('targetUserId', isEqualTo: targetUserId)
        .where('status', isEqualTo: 'accepted')
        .get();
    if (sent.docs.isNotEmpty) return true;

    final received = await _firestore.collection(AppConstants.connectionsCollection)
        .where('userId', isEqualTo: targetUserId)
        .where('targetUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'accepted')
        .get();
    return received.docs.isNotEmpty;
  }

  Future<void> addConnection(String userId, String targetUserId) async {
    // Check if connection already exists
    final query = await _firestore.collection(AppConstants.connectionsCollection)
        .where('userId', isEqualTo: userId)
        .where('targetUserId', isEqualTo: targetUserId)
        .get();
    if (query.docs.isNotEmpty) return;

    await _firestore.collection(AppConstants.connectionsCollection).add({
      'userId': userId,
      'targetUserId': targetUserId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Send notification to target user
    final sender = await getUser(userId);
    await NotificationService().createNotification(NotificationModel(
      id: '',
      userId: targetUserId,
      senderId: userId,
      senderName: sender?.name ?? 'Someone',
      title: 'New Connection Request',
      body: '${sender?.name ?? "Someone"} wants to connect with you.',
      type: NotificationType.connectionRequest,
      createdAt: DateTime.now(),
      relatedId: userId,
    ));
  }

  Future<void> acceptConnection(String connectionId) async {
    await _firestore.collection(AppConstants.connectionsCollection).doc(connectionId).update({
      'status': 'accepted',
    });
  }

  Future<void> rejectConnection(String connectionId) async {
    await _firestore.collection(AppConstants.connectionsCollection).doc(connectionId).delete();
  }

  Stream<List<UserModel>> getAcceptedConnectionsStream(String userId) {
    // We need to check both userId and targetUserId where status is accepted
    final sentQuery = _firestore.collection(AppConstants.connectionsCollection)
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'accepted')
        .snapshots();

    final receivedQuery = _firestore.collection(AppConstants.connectionsCollection)
        .where('targetUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'accepted')
        .snapshots();

    // Combine both streams
    return Rx.combineLatest2<QuerySnapshot, QuerySnapshot, List<String>>(
      sentQuery,
      receivedQuery,
      (sent, received) {
        final ids = <String>[];
        for (var doc in sent.docs) {
          ids.add(doc['targetUserId']);
        }
        for (var doc in received.docs) {
          ids.add(doc['userId']);
        }
        return ids;
      },
    ).asyncMap((ids) async {
      if (ids.isEmpty) return [];
      final userDocs = await _firestore.collection(AppConstants.usersCollection)
          .where(FieldPath.documentId, whereIn: ids)
          .get();
      return userDocs.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    });
  }

  Stream<List<Map<String, dynamic>>> getPendingRequestsStream(String userId) {
    // Requests received by the user
    return _firestore.collection(AppConstants.connectionsCollection)
        .where('targetUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .asyncMap((snapshot) async {
      final results = <Map<String, dynamic>>[];
      for (var doc in snapshot.docs) {
        final userDoc = await _firestore.collection(AppConstants.usersCollection).doc(doc['userId']).get();
        if (userDoc.exists) {
          results.add({
            'connectionId': doc.id,
            'user': UserModel.fromFirestore(userDoc),
          });
        }
      }
      return results;
    });
  }

  Stream<List<String>> getConnectedUserIdsStream(String userId) {
    final sent = _firestore.collection(AppConstants.connectionsCollection)
        .where('userId', isEqualTo: userId)
        .snapshots();
    final received = _firestore.collection(AppConstants.connectionsCollection)
        .where('targetUserId', isEqualTo: userId)
        .snapshots();

    return Rx.combineLatest2(sent, received, (QuerySnapshot s, QuerySnapshot r) {
      final ids = <String>{};
      for (var doc in s.docs) {
        ids.add(doc['targetUserId'] as String);
      }
      for (var doc in r.docs) {
        ids.add(doc['userId'] as String);
      }
      return ids.toList();
    });
  }

  /// Returns only user IDs with accepted (confirmed) connections.
  Stream<List<String>> getAcceptedConnectionIdsStream(String userId) {
    final sent = _firestore.collection(AppConstants.connectionsCollection)
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'accepted')
        .snapshots();
    final received = _firestore.collection(AppConstants.connectionsCollection)
        .where('targetUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'accepted')
        .snapshots();

    return Rx.combineLatest2(sent, received, (QuerySnapshot s, QuerySnapshot r) {
      final ids = <String>{};
      for (var doc in s.docs) ids.add(doc['targetUserId'] as String);
      for (var doc in r.docs) ids.add(doc['userId'] as String);
      return ids.toList();
    });
  }

  /// Returns only user IDs with pending (not yet accepted) connection requests.
  Stream<List<String>> getPendingConnectionIdsStream(String userId) {
    final sent = _firestore.collection(AppConstants.connectionsCollection)
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
    final received = _firestore.collection(AppConstants.connectionsCollection)
        .where('targetUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots();

    return Rx.combineLatest2(sent, received, (QuerySnapshot s, QuerySnapshot r) {
      final ids = <String>{};
      for (var doc in s.docs) ids.add(doc['targetUserId'] as String);
      for (var doc in r.docs) ids.add(doc['userId'] as String);
      return ids.toList();
    });
  }

  Future<List<String>> getAllConnectedUserIds(String userId) async {
    final sent = await _firestore.collection(AppConstants.connectionsCollection)
        .where('userId', isEqualTo: userId)
        .get();
    final received = await _firestore.collection(AppConstants.connectionsCollection)
        .where('targetUserId', isEqualTo: userId)
        .get();

    final ids = <String>[];
    for (var doc in sent.docs) {
      ids.add(doc['targetUserId']);
    }
    for (var doc in received.docs) {
      ids.add(doc['userId']);
    }
    return ids;
  }

  // ──────────────── Jobs & Mentorship ────────────────
  
  Stream<List<JobModel>> getJobsStream() {
    return _firestore
        .collection(AppConstants.jobsCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => JobModel.fromFirestore(doc)).toList());
  }

  Future<void> createJob(JobModel job, {String? senderName}) async {
    await _firestore.collection(AppConstants.jobsCollection).doc(job.id).set(job.toFirestore());
    await notifyAllUsers(
      title: 'New Job Opportunity',
      body: '${job.title} at ${job.company}',
      type: NotificationType.job,
      relatedId: job.id,
      senderId: 'admin',
      senderName: senderName ?? 'Admin',
    );
  }

  Future<void> updateJob(String jobId, Map<String, dynamic> data) async {
    await _firestore.collection(AppConstants.jobsCollection).doc(jobId).update(data);
  }

  Future<void> deleteJob(String jobId) async {
    final doc = await _firestore.collection(AppConstants.jobsCollection).doc(jobId).get();
    if (doc.exists) {
      final logoUrl = doc.data()?['companyLogo'] as String?;
      if (logoUrl != null) {
        await StorageService().deleteImageFromUrl(logoUrl);
      }
      await doc.reference.delete();
    }
  }

  Future<void> updatePostContent(String postId, String newContent) async {
    await _firestore.collection(AppConstants.postsCollection).doc(postId).update({'content': newContent});
  }

  Future<void> deletePost(String postId) async {
    final doc = await _firestore.collection(AppConstants.postsCollection).doc(postId).get();
    if (doc.exists) {
      final imageUrls = doc.data()?['imageUrls'] as List<dynamic>?;
      if (imageUrls != null && imageUrls.isNotEmpty) {
        for (var url in imageUrls) {
          await StorageService().deleteImageFromUrl(url as String);
        }
      }
      await doc.reference.delete();
    }
  }

  // ──────────────── News & Updates ────────────────

  Stream<List<NewsModel>> getNewsStream() {
    final now = DateTime.now();
    final fiveDaysAgo = now.subtract(const Duration(days: 5));

    return _firestore
        .collection(AppConstants.newsCollection)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(fiveDaysAgo))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => NewsModel.fromFirestore(doc)).toList());
  }

  Future<void> createNews(NewsModel news) async {
    await _firestore
        .collection(AppConstants.newsCollection)
        .doc(news.id)
        .set(news.toFirestore());
  }

  Future<void> updateNews(String newsId, Map<String, dynamic> data) async {
    await _firestore
        .collection(AppConstants.newsCollection)
        .doc(newsId)
        .update(data);
  }

  Future<void> deleteNews(String newsId) async {
    final doc = await _firestore.collection(AppConstants.newsCollection).doc(newsId).get();
    if (doc.exists) {
      final imageUrl = doc.data()?['imageUrl'] as String?;
      if (imageUrl != null) {
        await StorageService().deleteImageFromUrl(imageUrl);
      }
      await doc.reference.delete();
    }
  }
}
