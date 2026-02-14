import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:rentra/services/cloudinary_service.dart';
import 'app/app.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await dotenv.load(fileName: ".env");
  await CloudinaryService.initialize();
  OneSignal.initialize("1d61f646-cdfb-440a-93cf-036d1466de48");
  OneSignal.Notifications.requestPermission(true);
  runApp(const MyApp());
}
