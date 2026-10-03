import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  static const String _storageKey = 'espoti_user_profile';

  final ValueNotifier<AppUser> userNotifier = ValueNotifier<AppUser>(mockUser);

  AppUser get currentUser => userNotifier.value;

  /// Inicializa el servicio leyendo el perfil guardado en SharedPreferences
  /// o construyéndolo a partir del usuario actual autenticado en Firebase.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString(_storageKey);

      if (savedJson != null && savedJson.isNotEmpty) {
        final Map<String, dynamic> map = jsonDecode(savedJson);
        userNotifier.value = AppUser.fromJson(map);
        return;
      }

      // Si no existe caché local, verificar el usuario actual en Firebase Auth
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        final displayName = firebaseUser.displayName ?? '';
        final parts = displayName.split(' ');
        final firstName = parts.isNotEmpty ? parts.first : '';
        final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

        userNotifier.value = AppUser(
          firstName: firstName,
          lastName: lastName,
          name: displayName.isNotEmpty ? displayName : 'User',
          code: 'ESP${(firebaseUser.uid.hashCode % 9000 + 1000).abs()}',
          location: 'Bogotá D.C.',
          preferences: const ['Walk', 'Eat'],
          maxRadiusKm: 10,
          avatarUrl: firebaseUser.photoURL ?? 'https://i.pravatar.cc/200?img=13',
          email: firebaseUser.email ?? '',
          description: '',
        );
      }
    } catch (e) {
      debugPrint('Error al inicializar UserService: $e');
    }
  }

  /// Actualiza y guarda de manera persistente el perfil del usuario actual.
  Future<void> saveUser(AppUser user) async {
    userNotifier.value = user;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(user.toJson()));

      // Sincronizar nombre para mostrar y foto con Firebase Auth si están disponibles
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        if (user.name.isNotEmpty && firebaseUser.displayName != user.name) {
          await firebaseUser.updateDisplayName(user.name);
        }
        if (user.avatarUrl.isNotEmpty && firebaseUser.photoURL != user.avatarUrl) {
          await firebaseUser.updatePhotoURL(user.avatarUrl);
        }
      }
    } catch (e) {
      debugPrint('Error al guardar perfil de usuario: $e');
    }
  }

  /// Restablece el perfil al cerrar sesión.
  Future<void> clearUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (e) {
      debugPrint('Error al limpiar perfil de usuario: $e');
    }
    userNotifier.value = mockUser;
  }
}
