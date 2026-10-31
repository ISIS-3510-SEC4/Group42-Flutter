import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'firebase_options.dart';
import 'app/app.dart';

import 'app/routes.dart';
import 'core/offline/sync_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/user_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ); // Iniciar Firebase
  await Hive.initFlutter();
  // sqflite has no browser backend: on the web SQLite runs as WebAssembly.
  if (kIsWeb) databaseFactory = databaseFactoryFfiWeb;

  // Independent local reads run in parallel: the sync outbox and the user
  // profile are loaded at the same time instead of one after the other.
  await Future.wait([
    SyncService.instance.start(),
    UserService().init(awaitRemote: false),
  ]);

  final initialRoute =
      AuthService().isAuthenticated ? AppRoutes.home : AppRoutes.welcome;
      // Determinar la ruta inicial según el estado de autenticación

  runApp(EspotiApp(initialRoute: initialRoute));
}
