import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'widgets/workout_overlay.dart';
import 'app.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => WorkoutState(),
      child: const MyApp(),
    ),
  );
}
