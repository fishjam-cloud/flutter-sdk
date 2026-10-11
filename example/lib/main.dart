import 'package:flutter/material.dart';

import 'join_screen.dart';

void main() => runApp(const FishjamExampleApp());

class FishjamExampleApp extends StatelessWidget {
  const FishjamExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Fishjam example',
    theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
    home: const JoinScreen(),
  );
}
