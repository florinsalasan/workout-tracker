import 'package:flutter/material.dart';
import 'screen_controller.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Logo crimson used as the accent (secondary) color
    const logoCrimson = Color(0xFF9C0000);

    // Neutral grey seed for sleek surfaces:
    //   Light mode → off-white backgrounds
    //   Dark mode  → dark grey backgrounds
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6B6B6B),
      dynamicSchemeVariant: DynamicSchemeVariant.neutral,
    ).copyWith(
      primary: const Color(0xFF4A4A4A),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFE0E0E0),
      onPrimaryContainer: const Color(0xFF1A1A1A),
      secondary: logoCrimson,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFFFDAD6),
      onSecondaryContainer: const Color(0xFF410002),
    );

    final darkColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6B6B6B),
      brightness: Brightness.dark,
      dynamicSchemeVariant: DynamicSchemeVariant.neutral,
    ).copyWith(
      primary: const Color(0xFFCCCCCC),
      onPrimary: const Color(0xFF1A1A1A),
      primaryContainer: const Color(0xFF3A3A3A),
      onPrimaryContainer: const Color(0xFFE8E8E8),
      secondary: const Color(0xFFFFB4AB),
      onSecondary: const Color(0xFF690005),
      secondaryContainer: const Color(0xFF930009),
      onSecondaryContainer: const Color(0xFFFFDAD6),
    );
    return MaterialApp(
      title: 'Workout Tracker',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: darkColorScheme,
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}
