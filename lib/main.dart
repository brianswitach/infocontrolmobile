import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(InfocontrolApp());
}

class InfocontrolApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Infocontrol',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
      ),
      home: LoginScreen(),
    );
  }
}