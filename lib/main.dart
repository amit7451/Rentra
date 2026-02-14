import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:rentra/services/cloudinary_service.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase first as it's usually needed immediately
  await Firebase.initializeApp();

  await dotenv.load(fileName: ".env");
  await CloudinaryService.initialize();

  runApp(const MyApp());
}
