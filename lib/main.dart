import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'widgets/workout_overlay.dart';
import 'services/db_helpers.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dbHelper = DatabaseHelper.instance;

  final Database database = await dbHelper.database;
  runApp(
    MultiProvider(
      providers: [
        Provider<Database>.value(value: database),
        ChangeNotifierProvider(create: (_) => WorkoutState()),
      ],
      child: MyApp(),
    ),
  );
}
