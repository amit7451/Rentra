import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase first
  await Firebase.initializeApp();

  runApp(const MyApp());
}
