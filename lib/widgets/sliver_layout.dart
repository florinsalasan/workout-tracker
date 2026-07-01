import 'package:flutter/material.dart';

class CustomLayout extends StatelessWidget {
  final String title;
  final Widget body;

  const CustomLayout({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar.large(
            title: Text(title),
            // Optional: You can add properties here like floating: true, pinned: true,
            // or even background colors if you want to customize the header further.
          ),
          SliverFillRemaining(
            hasScrollBody: true,
            child: body,
          ),
        ],
      ),
    );
  }
}
