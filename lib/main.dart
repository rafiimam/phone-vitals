import 'package:flutter/material.dart';
import 'screens/home_shell.dart';
void main(){ WidgetsFlutterBinding.ensureInitialized(); runApp(const PhoneVitalsApp()); }
class PhoneVitalsApp extends StatelessWidget {
  const PhoneVitalsApp({super.key});
  @override Widget build(BuildContext context){
    const navy = Color(0xFF17457A);
    return MaterialApp(title:'PhoneVitals', debugShowCheckedModeBanner:false,
      theme: ThemeData(
        useMaterial3:true,
        colorScheme: ColorScheme.fromSeed(seedColor: navy, brightness: Brightness.light),
        scaffoldBackgroundColor: const Color(0xFFF3F6FA),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFF3F6FA), surfaceTintColor: Colors.transparent, elevation: 0, titleTextStyle: TextStyle(color: Color(0xFF12283F), fontSize: 20, fontWeight: FontWeight.w700)),
        cardTheme: CardThemeData(elevation: 0, color: Colors.white, clipBehavior: Clip.antiAlias, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFDFE8F1)))),
        navigationBarTheme: NavigationBarThemeData(backgroundColor: Colors.white, indicatorColor: const Color(0xFFD6E6F5), labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14))),
      ),
      home: const HomeShell());
  }
}
