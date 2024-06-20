import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/workout.dart';
import 'app.dart';

void main() {
  runApp(ChangeNotifierProvider(
    create: (_) => WorkoutState(),
    child: const MyApp(),
  ));
}
