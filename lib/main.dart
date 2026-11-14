import 'package:flutter/material.dart';
import 'screens/home_shell.dart';
import 'theme/vital_orbit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  loadBOTheme(); // restores the saved VITAL ORBIT theme before first frame settles
  runApp(const BlackBoxMDApp());
}

class BlackBoxMDApp extends StatelessWidget {
  const BlackBoxMDApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: boThemeName,
      builder: (_, name, __) => MaterialApp(
        title: 'BlackBox MD',
        debugShowCheckedModeBanner: false,
        theme: boMaterialTheme(boTokensFor(name)),
        home: const OrbitShell(),
      ),
    );
  }
}
