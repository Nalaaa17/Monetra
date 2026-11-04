import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'data/database/app_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Database lokal & seed data jika belum ada
  await AppDatabase.instance;

  runApp(
    const ProviderScope(
      child: MonetraApp(),
    ),
  );
}
