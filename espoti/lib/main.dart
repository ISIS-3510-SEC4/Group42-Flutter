import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'firebase_options.dart';
import 'app/app.dart';

import 'app/routes.dart';
import 'core/offline/sync_service.dart';
import 'core/services/analytics_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/user_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // La app solo funciona en vertical: se bloquea la rotación a horizontal
  // (también está declarado en AndroidManifest.xml e Info.plist).
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Firebase se inicializa antes que todo lo demás: Auth, Firestore y Analytics
  // dependen de esta llamada.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ); // Iniciar Firebase
  // Almacenamiento local: Hive (clave/valor en disco) solo lo usa
  // ZonePlacesStore para guardar los lugares encontrados por zona (respaldo
  // offline de la votación).
  await Hive.initFlutter();
  // sqflite has no browser backend: on the web SQLite runs as WebAssembly.
  if (kIsWeb) databaseFactory = databaseFactoryFfiWeb;

  // Independent local reads run in parallel: the sync outbox and the user
  // profile are loaded at the same time instead of one after the other.
  // Concurrencia: cargar el outbox (SyncService) y el perfil local
  // (UserService) son lecturas independientes, por eso se esperan juntas con
  // Future.wait. awaitRemote: false deja la lectura del perfil en Firestore en
  // segundo plano, así una red lenta no retrasa el primer frame de la app.
  await Future.wait([
    SyncService.instance.start(),
    UserService().init(awaitRemote: false),
  ]);

  // Planning funnel (VV2): an attempt left open when the app was closed is
  // recorded as abandoned at its last step. Runs after the outbox is loaded.
  // VV2 (abandono): si en la ejecución anterior quedó un intento de
  // planificación abierto (guardado en LocalStore), aquí se registra como
  // abandonado con reason = app_closed. Va después de cargar el outbox porque
  // el evento se encola en él. unawaited: no bloquea runApp.
  unawaited(AnalyticsService().recoverInterruptedAttempt());

  // Autenticación: FirebaseAuth restaura sola la sesión guardada en el
  // dispositivo; si hay usuario se entra directo a Home. Lo que se restaura es
  // la sesión de Firebase; la cuenta de Google (AuthService.googleAccount) NO
  // se restaura.
  final initialRoute =
      AuthService().isAuthenticated ? AppRoutes.home : AppRoutes.welcome;
      // Determinar la ruta inicial según el estado de autenticación

  runApp(EspotiApp(initialRoute: initialRoute));
}
