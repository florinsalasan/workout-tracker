import '../widgets/sliver_layout.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ExercisesScreen extends StatelessWidget {
  const ExercisesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomLayout(
        title: 'Exercises',
        body: Center(
          child: Text('Exercises content'),
        ));
  }
}
