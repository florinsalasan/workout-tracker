import '../widgets/sliver_layout.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomLayout(
        title: 'Analytics',
        body: Center(
          child: Text('Analytics content'),
        ));
  }
}
