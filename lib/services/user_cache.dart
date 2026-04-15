import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class UserCache {
  static UserModel? _user;

  static Future<UserModel?> getUser() async {
    if (_user != null) return _user;

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return null;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(firebaseUser.uid)
        .get();

    if (!doc.exists) return null;

    _user = UserModel.fromMap(doc.data()!);
    return _user;
  }

  static void update(UserModel user) {
    _user = user;
  }

  static void clear() {
    _user = null;
  }
}


