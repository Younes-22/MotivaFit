import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';

// This service acts as the bouncer for the app. It handles securely logging users in, creating brand new accounts, and logging them out using Firebase Authentication.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  // A live stream that constantly checks if someone is currently logged in or not. The app uses this to automatically route users to the Home Screen or kick them back to the Login Screen.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Creates a new account with an email and password. As soon as the account is securely created, it immediately talks to Firestore to set up their blank profile so they can start earning XP.
  Future<User?> signUp({required String email, required String password}) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      if (cred.user != null) {
        // We use the first half of their email as a temporary username until they pick a real one
        await _firestoreService.createUserProfile(cred.user!, email.split('@')[0]);
      }
      return cred.user;
    } catch (e) {
      rethrow;
    }
  }

  // Takes an existing user's email and password, securely verifies them with Firebase, and logs them back into their active session.
  Future<User?> signIn({required String email, required String password}) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return cred.user;
    } catch (e) {
      rethrow;
    }
  }

  // Clears the current user's active session, safely logging them out and locking down their personal data until they sign back in.
  Future<void> signOut() async {
    await _auth.signOut();
  }
}