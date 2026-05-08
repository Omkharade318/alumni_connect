import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';
import '../models/notification_model.dart';
import '../screens/chat_screen.dart';
import '../screens/messaging_screen.dart';
import '../screens/news_screen.dart';
import '../utils/constants.dart';
import '../screens/connections_screen.dart';
import '../screens/donation_screen.dart';
import '../screens/events_calendar_screen.dart';
import '../screens/jobs_screen.dart';
import '../services/firestore_service.dart';

// Top-level function for background messaging (must be top-level)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
  
  // For data-only messages in background, we might need to show a local notification
  // if the notification block is missing.
  if (message.notification == null) {
    final title = message.data['title'] ?? 'New Notification';
    final body = message.data['body'] ?? 'You have a new update';
    
    final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('ic_notification');
    const iosInit = DarwinInitializationSettings();
    await localNotifications.initialize(const InitializationSettings(android: androidInit, iOS: iosInit));

    const channel = AndroidNotificationChannel(
      'high_importance_channel_v4',
      'High Importance Notifications',
      importance: Importance.max,
    );

    await localNotifications.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          importance: Importance.max,
          priority: Priority.max,
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      payload: message.data['type'],
    );
  }
}

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  // Global navigator key for navigation from background/terminated state
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // flutter_local_notifications setup
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel_v4',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  // ─── Initialization ──────────────────────────────────────────────────────────

  Future<void> initialize() async {
    // 1. Request permissions
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // 2. Create Android notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // 3. Initialize flutter_local_notifications
    const androidInit = AndroidInitializationSettings('ic_notification');
    const iosInit = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        _handlePayload(payload);
      },
    );

    // 4. Register background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 5. Handle app opened from terminated state
    try {
      final RemoteMessage? initialMessage = await _fcm.getInitialMessage().timeout(const Duration(seconds: 3));
      if (initialMessage != null) {
        Future.delayed(const Duration(seconds: 1), () => _handleMessage(initialMessage));
      }
    } catch (e) {
      print('Error getting initial message: $e');
    }
  }

  void _handlePayload(String? payload) {
    if (payload == null || payload.isEmpty) return;

    try {
      final data = jsonDecode(payload);
      final type = data['type'];
      final relatedId = data['relatedId'];
      final senderId = data['senderId'];
      final userId = data['userId'];

      if (type == 'message' && relatedId != null && senderId != null) {
        _navigateToChat(relatedId, senderId, userId);
      } else {
        _navigateToScreen(type);
      }
    } catch (e) {
      // If not JSON, it might be the old simple payload
      _navigateToScreen(payload);
    }
  }

  void _navigateToScreen(String? type) {
    if (type == 'connectionRequest') {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const ConnectionsScreen(initialTab: 1)),
      );
    } else if (type == 'donation') {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const DonationScreen()),
      );
    } else if (type == 'event') {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const EventsCalendarScreen()),
      );
    } else if (type == 'job') {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const JobsScreen()),
      );
    } else if (type == 'news') {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const NewsScreen()),
      );
    }
  }

  Future<void> _navigateToChat(String relatedId, String senderId, String? userId) async {
    final sender = await FirestoreService().getUser(senderId);
    if (sender != null) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: relatedId,
            otherUser: sender,
            currentUserId: userId ?? '',
          ),
        ),
      );
    }
  }

  void configureHandlers() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final notification = message.notification;
      
      final title = notification?.title ?? message.data['title'] ?? 'New Notification';
      final body = notification?.body ?? message.data['body'] ?? 'You have a new message';
      final type = message.data['type'] ?? 'message';
      
      _showLocalNotification(
        title: title,
        body: body,
        payload: jsonEncode({
          'type': type,
          'relatedId': message.data['relatedId'],
          'senderId': message.data['senderId'],
          'userId': message.data['userId'],
        }),
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
  }

  // ─── Push Notification Sending ──────────────────────────────────────────────

  Future<void> sendPushNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // 1. Get user's FCM token
      final userDoc = await _firestore.collection(AppConstants.usersCollection).doc(userId).get();
      final String? token = userDoc.data()?['fcmToken'];

      if (token == null) {
        print('NotificationService: No FCM token found for user $userId');
        return;
      }

      await _sendFCM(token: token, title: title, body: body, data: data);
    } catch (e) {
      print('Error sending push notification: $e');
    }
  }

  Future<void> sendTopicNotification({
    required String topic,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await _sendFCM(topic: topic, title: title, body: body, data: data);
  }

  Future<String?> _getAccessToken() async {
    try {
      final credentials = ServiceAccountCredentials.fromJson(AppConstants.fcmServiceAccountJson);
      final client = await clientViaServiceAccount(credentials, ['https://www.googleapis.com/auth/cloud-platform']);
      final token = client.credentials.accessToken.data;
      client.close();
      return token;
    } catch (e) {
      print('Error getting FCM access token: $e');
      return null;
    }
  }

  Future<void> _sendFCM({
    String? token,
    String? topic,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final String? accessToken = await _getAccessToken();
      if (accessToken == null) {
        print('NotificationService: Failed to obtain OAuth 2.0 token.');
        return;
      }

      const String url = 'https://fcm.googleapis.com/v1/projects/${AppConstants.fcmProjectId}/messages:send';

      // FCM HTTP v1 payload structure
      final Map<String, dynamic> payload = {
        'message': {
          if (token != null) 'token': token else 'topic': topic,
          'notification': {
            'title': title,
            'body': body,
          },
          'data': {
            ...data?.map((key, value) => MapEntry(key, value.toString())) ?? {},
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'title': title,
            'body': body,
          },
          'android': {
            'priority': 'high',
            'notification': {
              'channel_id': 'high_importance_channel_v4',
              'sound': 'default',
            },
          },
          'apns': {
            'payload': {
              'aps': {
                'sound': 'default',
              },
            },
          },
        }
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        print('NotificationService: Push notification sent successfully via HTTP v1');
      } else {
        print('NotificationService: Failed to send push notification. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      print('Error in _sendFCM (v1): $e');
    }
  }

  // ─── Topic Management ────────────────────────────────────────────────────────

  Future<void> subscribeToTopic(String topic) async {
    await _fcm.subscribeToTopic(topic);
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _fcm.unsubscribeFromTopic(topic);
  }

  // ─── Local Banner Notification ────────────────────────────────────────────────

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String payload = '',
  }) async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.max,
          visibility: NotificationVisibility.public,
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      payload: payload,
    );
  }

  // ─── Deep-link navigation ─────────────────────────────────────────────────────

  void _handleMessage(RemoteMessage message) async {
    final type = message.data['type'];
    final relatedId = message.data['relatedId'];
    final senderId = message.data['senderId'];
    final userId = message.data['userId'];

    print('NotificationService: Handling message of type $type');

    if (type == 'message' && relatedId != null && senderId != null) {
      _navigateToChat(relatedId, senderId, userId);
    } else {
      _navigateToScreen(type);
    }
  }

  // ─── FCM Token management ─────────────────────────────────────────────────────

  Future<void> storeTokenForUser(String userId) async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(userId)
            .update({'fcmToken': token});
      }
    } catch (e) {
      print('Error storing FCM token: $e');
    }
  }

  Future<void> removeTokenForUser(String userId) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .update({'fcmToken': FieldValue.delete()});
    } catch (e) {
      print('Error removing FCM token: $e');
    }
  }

  // ─── Firestore notification CRUD ─────────────────────────────────────────────

  /// Documents are sorted client-side after fetching.
  Stream<List<NotificationModel>> getNotificationsStream(String userId) {
    return _firestore
        .collection(AppConstants.notificationsCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc))
          .toList();
      // Sort newest first client-side
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<void> createNotification(NotificationModel notification, {bool sendPush = true}) async {
    await _firestore
        .collection(AppConstants.notificationsCollection)
        .add(notification.toFirestore());

    if (sendPush) {
      await sendPushNotification(
        userId: notification.userId,
        title: notification.title,
        body: notification.body,
        data: {
          'type': notification.type.toString().split('.').last,
          'relatedId': notification.relatedId,
          'senderId': notification.senderId,
          'senderName': notification.senderName,
          'userId': notification.userId,
        },
      );
    }
  }

  Future<void> markAsRead(String notificationId) async {
    await _firestore
        .collection(AppConstants.notificationsCollection)
        .doc(notificationId)
        .update({'isRead': true});
  }

  Future<void> deleteNotification(String notificationId) async {
    await _firestore
        .collection(AppConstants.notificationsCollection)
        .doc(notificationId)
        .delete();
  }

  Stream<int> getUnreadNotificationCountStream(String userId) {
    return _firestore
        .collection(AppConstants.notificationsCollection)
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // ─── In-app notification tap navigation ──────────────────────────────────────

  void handleNotificationClick(BuildContext context, NotificationModel notification) async {
    print('NotificationService: In-app click for type ${notification.type}');
    deleteNotification(notification.id);

    if (notification.type == NotificationType.message && notification.relatedId != null) {
      final sender = await FirestoreService().getUser(notification.senderId);
      if (sender != null && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: notification.relatedId!,
              otherUser: sender,
              currentUserId: notification.userId,
            ),
          ),
        );
      }
    } else if (notification.type == NotificationType.connectionRequest) {
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ConnectionsScreen(initialTab: 1),
          ),
        );
      }
    } else if (notification.type == NotificationType.donation) {
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const DonationScreen(),
          ),
        );
      }
    } else if (notification.type == NotificationType.event) {
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const EventsCalendarScreen(),
          ),
        );
      }
    } else if (notification.type == NotificationType.job) {
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const JobsScreen(),
          ),
        );
      }
    } else if (notification.type == NotificationType.news) {
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const NewsScreen(),
          ),
        );
      }
    }
  }
}
