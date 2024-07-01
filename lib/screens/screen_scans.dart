import '../widgets/sliver_layout.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomLayout(
        title: 'Scans',
        body: Center(
          child: Text('Scans not implemented yet'),
        ));
  }
}
