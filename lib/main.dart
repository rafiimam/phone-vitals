import 'package:flutter/material.dart';
import 'screens/home_shell.dart';
void main(){ WidgetsFlutterBinding.ensureInitialized(); runApp(const PhoneVitalsApp()); }
class PhoneVitalsApp extends StatelessWidget {
  const PhoneVitalsApp({super.key});
  @override Widget build(BuildContext context){
    return MaterialApp(title:'PhoneVitals', debugShowCheckedModeBanner:false,
      theme: ThemeData(useMaterial3:true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF17457A))),
      home: const HomeShell());
  }
}
