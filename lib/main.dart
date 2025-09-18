import 'package:flutter/material.dart';
import 'package:interbridge/app/app.dart';
import 'package:interbridge/app/app_initializer.dart';

void main() async {
  await AppInitializer.initialize();
  runApp(MyApp());
}
