import 'package:flutter/cupertino.dart';

class CustomLayout extends StatelessWidget {
  final String title;
  final Widget body;

  const CustomLayout({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: <Widget>[
          CupertinoSliverNavigationBar(
            largeTitle: Text(title),
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
