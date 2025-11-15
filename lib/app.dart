import 'package:flutter/material.dart';
import 'package:pos_desktop/pages/index_page.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: const IndexPage(),
      ),
    );
  }
}
