import 'package:flutter/material.dart';
import 'routes.dart';
import 'theme.dart';
import '../core/constants/app_strings.dart';

class EspotiApp extends StatelessWidget {
  const EspotiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.welcome,
      routes: AppRoutes.routes,
    );
  }
}
