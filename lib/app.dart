import 'package:flutter/material.dart';
import 'package:pruebaa/features/selection/presentation/screens/selection_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AlterPapa',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        // You could move the theme to core/theme/app_theme.dart for more complex apps
      ),
      home: const SelectionScreen(), // The starting screen of the app
    );
  }
}