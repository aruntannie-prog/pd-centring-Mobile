import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;

  /// Stream of user authentication state changes.
  static Stream<User?> get userStream => _auth.authStateChanges();

  /// Returns the current logged-in user, or null.
  static User? get currentUser => _auth.currentUser;

  /// Attempts to log in with [email] and [password].
  /// Returns null on success, or an error message string on failure.
  static Future<String?> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      debugPrint('AuthService: ✅ Logged in as $email');
      return null; // Success
    } on FirebaseAuthException catch (e) {
      debugPrint('AuthService: ❌ Login failed: ${e.code}');
      switch (e.code) {
        case 'user-not-found':
          return 'No user found for that email.';
        case 'wrong-password':
          return 'Wrong password provided.';
        case 'invalid-email':
          return 'The email address is badly formatted.';
        case 'user-disabled':
          return 'This user account has been disabled.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        default:
          return 'Login failed. Please check your credentials.';
      }
    } catch (e) {
      debugPrint('AuthService: ❌ Unknown error: $e');
      return 'An unexpected error occurred.';
    }
  }

  /// Logs out the current user.
  static Future<void> logout() async {
    try {
      await _auth.signOut();
      debugPrint('AuthService: ✅ Logged out');
    } catch (e) {
      debugPrint('AuthService: ❌ Logout error: $e');
    }
  }
}
