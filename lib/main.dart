import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/login_screen.dart';
import './screens/hive_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await HiveHelper.initHive();

  runApp(InfocontrolApp());
}

class InfocontrolApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Infocontrol',
        home: LoginScreen(),
        debugShowCheckedModeBanner: false);
  }
}
