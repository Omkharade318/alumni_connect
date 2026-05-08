import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  UserModel? _currentUser;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  AuthProvider() {
    _init();
  }

  void _init() {
    print('AuthProvider: Starting initialization');
    
    // Safety timeout: ensure _isInitialized is set to true even if authStateChanges hangs
    Future.delayed(const Duration(seconds: 5), () {
      if (!_isInitialized) {
        print('AuthProvider: Initialization safety timeout reached');
        _isInitialized = true;
        notifyListeners();
      }
    });

    _authService.authStateChanges.listen((user) async {
      // Important: authStateChanges can fire during sign-in/out transitions.
      // We should not set a persistent UI error based on transient null/refresh states.
      if (user == null) {
        // Don't clear if we are in a static admin session
        if (_currentUser?.uid != 'static-admin-uid') {
          _currentUser = null;
          _error = null;
        }
        _isInitialized = true;
        notifyListeners();
        return;
      }

      try {
        print('Auth state changed: User ${user.uid} is signed in');
        try {
          _currentUser = await _authService.getUser(user.uid);
        } catch (e) {
          // If Firestore read fails, fall back to basic Firebase Auth data
          // rather than pushing an authentication error to the UI.
          print('Failed to get user data from Firestore: $e');
          _currentUser = null;
        }

        if (_currentUser == null) {
          print('Creating basic user model from Firebase Auth data');
          final isAdmin = user.email == 'admin@alumni.com' || user.email == 'admin@gmail.com';
          _currentUser = UserModel(
            uid: user.uid,
            name: user.displayName ?? (isAdmin ? 'System Admin' : 'User'),
            email: user.email ?? '',
            isAdmin: isAdmin,
            phone: user.phoneNumber,
            profileImage: user.photoURL,
            createdAt: user.metadata.creationTime,
          );
        } else if (_currentUser!.email == 'admin@gmail.com') {
          // If we already have the admin user, ensure isAdmin remains true
          _currentUser = _currentUser!.copyWith(isAdmin: true);
        }
      } catch (e) {
        print('Error resolving user data: $e');
        _currentUser = null;
        // Only show listener errors while a sign-in/sign-up attempt is in progress.
        // This prevents brief "Authentication Failed" messages during redirects.
        if (_isLoading) {
          _error = _formatErrorMessage(e.toString());
        }
      } finally {
        _isInitialized = true;
        notifyListeners();
      }
    });
  }

  Future<bool> signIn(String email, String password) async {
    // --- Static Admin Check ---
    if (email == 'admin@gmail.com' && password == 'admin123') {
      try {
        // Actually sign in with Firebase Auth so Storage/Firestore have a valid token
        try {
          await _authService.signInWithEmailDirect(email, password);
        } catch (e) {
          // If admin account doesn't exist in Firebase Auth yet, create it
          if (e.toString().contains('user-not-found') || 
              e.toString().contains('invalid-credential')) {
            try {
              await _authService.createUserDirect(email, password);
            } catch (createError) {
              // Account may already exist with different state, try sign-in again
              if (createError.toString().contains('email-already-in-use')) {
                await _authService.signInWithEmailDirect(email, password);
              } else {
                print('Admin Firebase Auth setup failed: $createError');
                // Continue anyway — admin panel works, just uploads may not
              }
            }
          } else {
            print('Admin Firebase Auth sign-in failed: $e');
          }
        }
      } catch (e) {
        print('Admin auth setup error (non-critical): $e');
      }

      _currentUser = UserModel(
        uid: _authService.currentFirebaseUid ?? 'static-admin-uid',
        name: 'System Admin',
        email: email,
        isAdmin: true,
        jobTitle: 'App Administrator',
        createdAt: DateTime.now(),
      );
      _error = null;
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
      return true;
    }
    // ---------------------------

    // Clear any previous error immediately to prevent UI flash.
    _error = null;
    notifyListeners();
    _isLoading = true;
    notifyListeners();

    try {
      _currentUser = await _authService.signInWithEmail(email, password);
      
      // Store FCM token for push notifications
      if (_currentUser != null) {
        await NotificationService().storeTokenForUser(_currentUser!.uid);
        await NotificationService().subscribeToTopic(AppConstants.allUsersTopic);
      }

      // Ensure error stays null on successful sign-in.
      _error = null;
      
      _isLoading = false;
      notifyListeners();
      return _currentUser != null;
    } catch (e) {
      _error = _formatErrorMessage(e.toString());
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String branch,
    required String batch,
    required String company,
    required String jobTitle,
    required String city,
    String? degree,
    String? profileImage,
  }) async {
    // Clear any previous error immediately to prevent UI flash.
    _error = null;
    notifyListeners();
    _isLoading = true;
    notifyListeners();

    try {
      _currentUser = await _authService.signUpWithEmail(
        email: email,
        password: password,
        name: name,
        phone: phone,
        branch: branch,
        batch: batch,
        company: company,
        jobTitle: jobTitle,
        city: city,
        degree: degree,
        profileImage: profileImage,
      );
      
      // Store FCM token for push notifications
      if (_currentUser != null) {
        await NotificationService().storeTokenForUser(_currentUser!.uid);
        await NotificationService().subscribeToTopic(AppConstants.allUsersTopic);
      }

      // Ensure error stays null on successful sign-up.
      _error = null;
      
      _isLoading = false;
      notifyListeners();
      return _currentUser != null;
    } catch (e) {
      _error = _formatErrorMessage(e.toString());
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    // Clear any previous error immediately to prevent UI flash.
    _error = null;
    notifyListeners();
    _isLoading = true;
    notifyListeners();

    try {
      _currentUser = await _authService.signInWithGoogle();
      
      // Store FCM token for push notifications
      if (_currentUser != null) {
        await NotificationService().storeTokenForUser(_currentUser!.uid);
        await NotificationService().subscribeToTopic(AppConstants.allUsersTopic);
      }

      // Ensure error stays null on successful sign-in.
      _error = null;
      
      _isLoading = false;
      notifyListeners();
      return _currentUser != null;
    } catch (e) {
      _error = _formatErrorMessage(e.toString());
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  String _formatErrorMessage(String error) {
    // Handle specific Firebase Auth errors
    if (error.contains('type \'List<Object?>\' is not a subtype of type \'PigeonUserDetails?\'')) {
      return 'Authentication failed. Please try again.';
    }
    if (error.contains('cloud_firestore/unavailable') || error.contains('PERMISSION_DENIED')) {
      return 'Service temporarily unavailable. Please check your internet connection and try again.';
    }
    if (error.contains('Google credentials are invalid or expired')) {
      return 'Google session expired. Please try signing in again.';
    }
    if (error.contains('Google Sign-In was cancelled')) {
      return 'Sign-in was cancelled.';
    }
    if (error.contains('Failed to get Google authentication tokens')) {
      return 'Failed to authenticate with Google. Please try again.';
    }
    if (error.contains('account-exists-with-different-credential')) {
      return 'An account with this email already exists using a different sign-in method.';
    }
    if (error.contains('Could not get email from Google account')) {
      return 'Unable to get email from Google account. Please try again.';
    }
    if (error.contains('user-not-found')) {
      return 'No account found with this email address.';
    }
    if (error.contains('wrong-password')) {
      return 'Incorrect password. Please try again.';
    }
    if (error.contains('email-already-in-use')) {
      return 'An account with this email already exists.';
    }
    if (error.contains('weak-password')) {
      return 'Password is too weak. Please choose a stronger password.';
    }
    if (error.contains('invalid-email')) {
      return 'Invalid email address.';
    }
    if (error.contains('user-disabled')) {
      return 'This account has been disabled.';
    }
    if (error.contains('too-many-requests')) {
      return 'Too many failed attempts. Please try again later.';
    }
    if (error.contains('network-request-failed') || error.contains('Network error')) {
      return 'Network error. Please check your connection.';
    }
    if (error.contains('Email and password cannot be empty')) {
      return 'Please enter both email and password.';
    }
    if (error.contains('Email, password, and name are required')) {
      return 'Please fill in all required fields.';
    }
    if (error.contains('Password must be at least 6 characters long')) {
      return 'Password must be at least 6 characters long.';
    }
    
    // Generic error handling
    return error.replaceAll('Exception:', '').replaceAll('PlatformException:', '').trim();
  }

  Future<void> signOut() async {
    final currentUserId = _currentUser?.uid;

    // Clear any existing error so the sign-in UI doesn't flash stale messages.
    _error = null;
    _isLoading = false;
    notifyListeners();
    
    // Remove FCM token before signing out
    if (currentUserId != null) {
      try {
        await NotificationService().removeTokenForUser(currentUserId);
      } catch (e) {
        print('Error removing FCM token: $e');
      }
    }
    
    await _authService.signOut();
    _currentUser = null;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    if (_authService.currentUser != null) {
      try {
        // First refresh the Firebase credentials
        await _authService.refreshCredentials();
        
        // Then get updated user data
        try {
          _currentUser = await _authService.getUser(_authService.currentUser!.uid);
          if (_currentUser != null) {
            print('User data refreshed from Firestore');
          } else {
            print('No user data in Firestore, using Firebase Auth data');
            final user = _authService.currentUser!;
            _currentUser = UserModel(
              uid: user.uid,
              name: user.displayName ?? 'User',
              email: user.email ?? '',
              isAdmin: false, // Default to false for regular users
              phone: user.phoneNumber,
              profileImage: user.photoURL,
              createdAt: user.metadata.creationTime,
            );
          }
        } catch (e) {
          print('Failed to refresh user data from Firestore: $e');
          print('Using Firebase Auth data for user model');
          final user = _authService.currentUser!;
          _currentUser = UserModel(
            uid: user.uid,
            name: user.displayName ?? 'User',
            email: user.email ?? '',
            isAdmin: false, // Default to false for regular users
            phone: user.phoneNumber,
            profileImage: user.photoURL,
            createdAt: user.metadata.creationTime,
          );
        }
        
        notifyListeners();
      } catch (e) {
        print('Error refreshing user data: $e');
        _error = _formatErrorMessage(e.toString());
        notifyListeners();
      }
    }
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    if (_currentUser == null) return;
    await _authService.updateProfile(_currentUser!.uid, data);
    await refreshUser();
  }

  Future<void> updateProfileImage(String url) async {
    if (_currentUser == null) return;
    await _authService.updateProfileImage(_currentUser!.uid, url);
    await refreshUser();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
