class AppConstants {
  static const String appName = 'Alumni Connect';
  static const String usersCollection = 'users';
  static const String postsCollection = 'posts';
  static const String commentsCollection = 'comments';
  static const String messagesCollection = 'messages';
  static const String conversationsCollection = 'conversations';
  static const String eventsCollection = 'events';
  static const String donationsCollection = 'donations';
  static const String connectionsCollection = 'connections';
  static const String notificationsCollection = 'notifications';
  static const String jobsCollection = 'jobs';
  static const String newsCollection = 'news';

  // FCM Configuration (HTTP v1)
  // IMPORTANT: In production, do NOT store your service account key in the app.
  // Use Firebase Cloud Functions to send push notifications securely.
  static const String fcmProjectId = 'alumni-50bc8';
  static const String fcmServiceAccountJson = r'''{
  "type": "service_account",
  "project_id": "alumni-50bc8",
  "private_key_id": "8f0a6a62bf32ce1b1433413c70d9b022b1e3bfca",
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDJceKlS3gFtBQf\n2AyZc1CbumfZzVAcsc6vpC9gteARYJvs98yIo9qsZzKkw62FRyD1Hq62qcLRsA6m\nTxSgpDf63qaI6oe7Ri3DdWboT4IgjVLupAO3ia7lNWHTnPEksNW82jyiHiHUR0Tx\nSgohpyHTi1RLknHNH96swi1JXpRgIfc7LLjHIs1aiJM9KJ5QPxrkED0lfbLd/Toe\njz1YBnHbuLPNvulT+vC2ka9Y85QlwG7hgpibm/6yP3Ft/8uuo5kIWlLLEcC/EHAN\njZwKswjkHHXkVDtQxx38IpKfHoQEjjtVjlKn5D7dxNeMl1JH8u5JmS8qetEureIh\nY38Kg+mXAgMBAAECggEADRy1GyZE6zYereNIZVVHX25BjpXvINcFXuhpzw/iRFn3\nUZ7gONqq2VhO8xZA6AZ1Djok4YM+SPDT8J5Vd46zjXL1qxQnqUMhp8cvX3AMG9Cn\nH8fG7X5FnJTIx9c/g7Bg++McBD9q20rs9rm83BY+vOrPngBWblAklIvVGnamDiBk\n3NlOqvk7it7C9af5bY0yKxPaAn34MwMPPCDFneFmjC16CpaLruWVO7jxXrDMNEL2\nV3k86DpXlBNTK2LaSWmJMs1kEEJrUsfBdPGg8pu3e/HSV9cIt4C5Wmb3wIYOgihZ\nSWflXkuXPUX3HhNMIzLF582WrGFLahMXEg0zI4f5AQKBgQD2fgioYMJYGjUacKyK\n31zrEpR7+F+lvDeB2HvMheWV/NQ1jgaOUGq2XMdlVc0w3bcZzeg6mapNC8d+1f8y\ny2V+KbLpp4Y6xKJPVCu+zQLvcO/uWGDzUgyX3bgjEVSpA8f6ZxOjRud4thfGpU/+\n1+CDwe60tMVfVEhCvVmxvt10lwKBgQDRNwjT5rfDnEQKAIdfg6ZXh5Z5fdq6BtyP\nOXaLne1X1xbuC/6sSILJmbO9Og+FCNBqPptLZ/BnwsKHCkNo7rIKfHq64sNt5s02\nUP8r5GFtslkSJ3AkZ+cXXA79F46P3ZDtMy6DhNEdCkSct+JsZyVDek293WakRVPc\nRi+ti6LTAQKBgGOD8MTiA7SEKCpbkR2kHiR95NrEJQGJorNWjmy9JjrOz3Iru/Pa\n/apQfOQppuTyrojJe9ek0H+4oLtRdG2ydnBgL25sByJU3t6+Mccfh+7ZntSQc9vo\npVLu3feyeIagEy3CTcheyPcQNTsq5MgTqf4n3tKwJPte0Km5PqwnTctTAoGBAKIC\miVtnpQtqEqOikYermtNperC2OQBeD644uHPFAJXn3wLcdV7+TugeJ1qHqaIYsxD\nWwKTpIjVOspT2kuhu+F+75NVEr1CY1tScadNnVzTJUJ3o9GtXDisoza+TTl+/EGS\nxsw1x7FTSDqL8xy66xJL3XPPxTIkNYJ4H2emoBoBAoGAWiFli5rN/QviXd4SKB2X\nZdiKXup5QqFsJp3O9sJh5OMBLjdzfuK4zXfHmRIPFOQyVMg7fDBP6kxFwcjUB0qk\nkDRipRjgcS4ofHtVbAQYuuKcRY+KQDvirPxpc5CMXNeFVuwQS3oLTOO7t/qASD+T\nLXzZSFwc/2Ia91tiGL0p05U=\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-fbsvc@alumni-50bc8.iam.gserviceaccount.com",
  "client_id": "108915357765026637319",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40alumni-50bc8.iam.gserviceaccount.com",
  "universe_domain": "googleapis.com"
}''';
  static const String allUsersTopic = 'all_users';

  static const List<String> branches = [
    'CSE',
    'ECE',
    'EEE',
    'MECH',
    'CIVIL',
    'IT',
    'Other',
  ];

  static const List<String> degrees = [
    'B.Tech',
    'M.Tech',
    'MBA',
    'BCA',
    'MCA',
    'B.Sc',
    'M.Sc',
    'Other',
  ];

  static const List<String> donationCategories = [
    'Infrastructure',
    'Computer Labs',
  ];
}
