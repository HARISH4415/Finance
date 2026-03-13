import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:finance2/screens/home_screen.dart';
import 'package:finance2/screens/login_screen.dart';
import 'package:finance2/services/auth_service.dart';
import 'package:finance2/services/customer_service.dart';
import 'package:finance2/services/localization_service.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.init();
  await CustomerService.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: LocalizationService.localeNotifier,
      builder: (context, locale, child) {
        return MaterialApp(
          title: 'Offline Auth Demo',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
          ),
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('ta')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: AuthService.isLoggedIn
              ? const HomeScreen()
              : const LoginScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}