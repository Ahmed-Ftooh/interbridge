import 'package:flutter/material.dart';
import 'package:interbridge/app/app.dart';
import 'package:interbridge/app/app_initializer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppInitializer.initialize();
  runApp(const MyApp());
}
