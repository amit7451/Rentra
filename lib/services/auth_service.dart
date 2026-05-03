import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';
import '../models/user_model.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'notification_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '360291447254-88beq1qn1vf7a9me7e3718hpghqimfmq.apps.googleusercontent.com',
  );
  final FirestoreService _firestoreService = FirestoreService();
  final NotificationService _notificationService = NotificationService();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Check if user has a password linked
  bool get hasPassword =>
      _auth.currentUser?.providerData.any((p) => p.providerId == 'password') ??
      false;

  // Check if user is a Google user
  bool get isGoogleUser =>
      _auth.currentUser?.providerData.any(
        (p) => p.providerId == 'google.com',
      ) ??
      false;

  // Sign up with email and password
  Future<UserModel?> signUp({
    required String email,
    required String password,
    required String name,
    required String phoneNumber,
    DateTime? dateOfBirth,
    String? gender,
    bool isAdmin = false,
    String? profileImage = ' ',
  }) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = result.user;
      if (user != null) {
        try {
          // Create user model
          final userModel = UserModel(
            uid: user.uid,
            email: email,
            name: name,
            phoneNumber: phoneNumber,
            dateOfBirth: dateOfBirth,
            gender: gender,
            createdAt: DateTime.now(),
            isAdmin: isAdmin,
            photoUrl: profileImage,
          );

          // Save user data to Firestore
          await _firestoreService.createUser(userModel);

          // Save user data to Firestore
          await _firestoreService.createUser(userModel);

          // Initialize OneSignal
          _notificationService.login(user.uid);
          _notificationService.setUserTags(role: isAdmin ? 'admin' : 'user');

          return userModel;
        } catch (e) {
          // Rollback: delete auth user if firestore fails
          await user.delete();
          rethrow;
        }
      }
      return null;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'An unexpected error occurred. Please try again.';
    }
  }

  Future<User?> signInWithGoogle() async {
    // 1. Trigger the authentication flow
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // User canceled the sign-in

    // 2. Obtain the auth details from the request
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    // 3. Create a new credential
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // 4. Once signed in, return the UserCredential
    final UserCredential userCredential = await _auth.signInWithCredential(
      credential,
    );
    final user = userCredential.user;

    if (user != null) {
      // Initialize OneSignal
      _notificationService.login(user.uid);

      // 1. Check if user document exists in Firestore (Direct UID match)
      final existingUser = await _firestoreService.getUser(user.uid);

      if (existingUser != null) {
        if (existingUser.accountStatus == 'deleted') {
          // Reactivate soft-deleted account (Same UID)
          await _firestoreService.reactivateUser(user.uid);
        }
        _notificationService.setUserTags(
          role: existingUser.isAdmin ? 'admin' : 'user',
        );
      } else {
        // Create new user document if it doesn't exist
        final newUser = UserModel(
          uid: user.uid,
          email: user.email ?? '',
          name: user.displayName ?? 'New User',
          phoneNumber: user.phoneNumber,
          photoUrl: user.photoURL,
          createdAt: DateTime.now(),
          isAdmin: false,
        );
        await _firestoreService.createUser(newUser);
        _notificationService.setUserTags(role: 'user');
      }
    }

    return user;
  }

  // Sign in with email and password
  Future<UserModel?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = result.user;
      if (user != null) {
        // Get user data from Firestore
        final userModel = await _firestoreService.getUser(user.uid);

        if (userModel == null) {
          // User exists in Auth but not in Firestore (incomplete signup)
          await _auth.signOut();
          throw 'Account not found. Please sign up.';
        }

        if (userModel.accountStatus == 'deleted') {
          // Reactivate soft-deleted account
          await _firestoreService.reactivateUser(user.uid);
        }

        // Initialize OneSignal
        _notificationService.login(user.uid);
        _notificationService.setUserTags(
          role: userModel.isAdmin ? 'admin' : 'user',
        );

        return userModel;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _notificationService.logout();
    } catch (e) {
      throw 'Failed to sign out. Please try again.';
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Failed to send reset email. Please try again.';
    }
  }

  // Update user profile
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.updateDisplayName(displayName);
        await user.updatePhotoURL(photoURL);
      }
    } catch (e) {
      throw 'Failed to update profile. Please try again.';
    }
  }

  // Update password directly (after re-authentication)
  Future<void> updatePassword(String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.updatePassword(newPassword);
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Failed to update password. Please try again.';
    }
  }

  // Link Email/Password to existing account (for Google users)
  Future<void> linkEmailPassword(String email, String password) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final credential = EmailAuthProvider.credential(
          email: email,
          password: password,
        );
        await user.linkWithCredential(credential);
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Failed to set password. Please try again.';
    }
  }

  // Re-authenticate with Email/Password
  Future<void> reauthenticateWithEmail(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) throw 'User not logged in';

    AuthCredential credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );

    await user.reauthenticateWithCredential(credential);
  }

  // Re-authenticate with Google
  Future<void> reauthenticateWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null) throw 'User not logged in';

    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw 'Google authentication cancelled';

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    await user.reauthenticateWithCredential(credential);
  }

  // Soft Delete Flow (Layered)
  Future<void> reauthenticateAndDelete({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) throw 'No user found';

    // 1. Re-authenticate
    if (password != null) {
      // Email user
      await reauthenticateWithEmail(password);
    } else {
      // Google user
      await reauthenticateWithGoogle();
    }

    // 2. Soft delete in Firestore (update status + deactivate properties)
    await _firestoreService.softDeleteUser(user.uid);
    _notificationService.logout(); // Logout from OneSignal

    // 3. Delete from Firebase Auth (Hard delete from Auth side)
    await user.delete();
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'user-not-found':
        return 'Account deleted or not found. Please sign up again.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      case 'operation-not-allowed':
        return 'This operation is not allowed.';
      default:
        return 'An authentication error occurred. Please try again.';
    }
  }
}
