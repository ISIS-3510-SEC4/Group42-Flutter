import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../models/friend.dart';
import '../constants/input_limits.dart';
import 'user_service.dart';

/// Búsqueda de amigos por su código de Espoti (por ejemplo, ESP4821).
///
/// Los perfiles completos (`users/{uid}`) son privados: cada usuario solo lee
/// el suyo. Para poder buscar por código existe un directorio mínimo y
/// público: `user_codes/{CODIGO}` con solo nombre, foto, código y uid (sin
/// correo ni teléfono). Las reglas permiten leer un código concreto (get)
/// pero no listar la colección, así que no se pueden recorrer todos los
/// usuarios: hay que conocer el código.
///
/// El código antiguo se generaba con un hash de 4 dígitos y puede repetirse
/// entre dos personas. Si al publicarlo el código ya es de otro usuario, se
/// genera uno nuevo aleatorio y se actualiza el perfil.
/// Estado de la publicación del código propio (se muestra en Amigos).
enum CodePublishStatus { unknown, publishing, published, failed }

class FriendCodeService {
  FriendCodeService._();
  static final FriendCodeService instance = FriendCodeService._();

  /// Si el código propio ya está en el directorio. Si falló, la pantalla de
  /// Amigos muestra el motivo y un botón para reintentar.
  final ValueNotifier<CodePublishStatus> status =
      ValueNotifier(CodePublishStatus.unknown);
  String? lastError;

  static const String collection = 'user_codes';
  static const Duration _timeout = Duration(seconds: 10);

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  bool _publishing = false;

  /// Normaliza lo que escribe el usuario: sin espacios y en mayúsculas.
  static String normalize(String code) =>
      code.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  /// Valida el formato antes de consultar. Devuelve el mensaje de error o null.
  static String? validate(String code) {
    final c = normalize(code);
    if (c.isEmpty) return 'Enter a friend code';
    if (c.length < 4) return 'The code is too short';
    if (c.length > InputLimits.friendCode) {
      return 'The code must be at most ${InputLimits.friendCode} characters';
    }
    return null;
  }

  static String _randomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // sin 0/O ni 1/I
    final r = Random.secure();
    return 'ESP${List.generate(5, (_) => chars[r.nextInt(chars.length)]).join()}';
  }

  /// Publica (o actualiza) el código del usuario actual en el directorio.
  /// Se llama al iniciar sesión y al guardar el perfil. Necesita conexión;
  /// si falla, se reintenta la próxima vez.
  Future<void> publishMyCode() async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null || _publishing) return;
    _publishing = true;
    status.value = CodePublishStatus.publishing;
    try {
      var user = UserService().currentUser;
      for (var attempt = 0; attempt < 3; attempt++) {
        final code = normalize(user.code);
        if (code.isEmpty) {
          user = user.copyWith(code: _randomCode());
          await UserService().saveUser(user);
          continue;
        }
        final ref = _db.collection(collection).doc(code);
        final taken = await _db.runTransaction<bool>((tx) async {
          final snap = await tx.get(ref);
          final owner = snap.data()?['uid'];
          if (snap.exists && owner != authUser.uid) return true;
          tx.set(ref, {
            'uid': authUser.uid,
            'code': code,
            'name': user.name,
            'avatarUrl': user.avatarUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          return false;
        }).timeout(_timeout);
        if (!taken) {
          lastError = null;
          status.value = CodePublishStatus.published;
          return;
        }
        // El código ya es de otra persona: se cambia por uno nuevo.
        user = user.copyWith(code: _randomCode());
        await UserService().saveUser(user);
      }
      lastError = 'Could not get a unique code. Try again.';
      status.value = CodePublishStatus.failed;
    } catch (e) {
      debugPrint('Friend code not published: $e');
      lastError = e is FirebaseException && e.code == 'permission-denied'
          ? 'Your code could not be published: check that the Firestore rules include user_codes.'
          : 'Your code is not visible to others yet (no connection). Try again.';
      status.value = CodePublishStatus.failed;
    } finally {
      _publishing = false;
    }
  }

  /// Busca a un usuario por su código. Devuelve null si no existe.
  /// Lanza [FriendCodeException] con un mensaje para la interfaz.
  Future<Friend?> findByCode(String rawCode) async {
    final error = validate(rawCode);
    if (error != null) throw FriendCodeException(error);
    final code = normalize(rawCode);
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) throw const FriendCodeException('Log in to search friends.');
    if (code == normalize(UserService().currentUser.code)) {
      throw const FriendCodeException('That is your own code.');
    }
    try {
      final snap = await _db
          .collection(collection)
          .doc(code)
          .get(const GetOptions(source: Source.server))
          .timeout(_timeout);
      var data = snap.data();
      // Respaldo: usuarios cuyo código aún no está en el directorio (no han
      // abierto la versión nueva de la app). Se busca en `users` por el campo
      // `code`; si las reglas no permiten leer perfiles ajenos, se ignora.
      if (!snap.exists || data == null) data = await _findInUsers(code);
      if (data == null) return null;
      final uid = data['uid'] as String?;
      if (uid == null) return null;
      if (uid == me.uid) {
        throw const FriendCodeException('That is your own code.');
      }
      return Friend(
        name: data['name'] as String? ?? '',
        photoUrl: data['avatarUrl'] as String? ?? '',
        uid: uid,
        code: code,
      );
    } on FriendCodeException {
      rethrow;
    } on FirebaseException catch (e) {
      debugPrint('Friend code search failed: $e');
      throw FriendCodeException(e.code == 'permission-denied'
          ? 'Searching by code is not allowed yet. Check that the Firestore rules are published.'
          : 'Could not search right now. Check your connection.');
    } catch (e) {
      debugPrint('Friend code search failed: $e');
      throw const FriendCodeException(
          'Could not search right now. Check your connection.');
    }
  }
}

extension on FriendCodeService {
  Future<Map<String, dynamic>?> _findInUsers(String code) async {
    try {
      final query = await _db
          .collection('users')
          .where('code', isEqualTo: code)
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(FriendCodeService._timeout);
      if (query.docs.isEmpty) return null;
      final doc = query.docs.first;
      final data = doc.data();
      // Solo se usan los datos públicos (nombre y foto), nunca correo o teléfono.
      return {
        'uid': data['firebaseUid'] as String? ?? doc.id,
        'name': data['name'] as String? ?? '',
        'avatarUrl': data['avatarUrl'] as String? ?? '',
      };
    } catch (e) {
      debugPrint('Fallback search in users not available: $e');
      return null;
    }
  }
}

class FriendCodeException implements Exception {
  final String message;
  const FriendCodeException(this.message);
  @override
  String toString() => message;
}
