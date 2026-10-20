import 'package:flutter/material.dart';

class CustomLayout extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;

  const CustomLayout({
    super.key,
    required this.title,
    required this.body,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar.large(
              title: Text(title),
              actions: actions,
              forceElevated: innerBoxIsScrolled,
            ),
          ];
        },
        body: body,
      ),
    );
  }
}
