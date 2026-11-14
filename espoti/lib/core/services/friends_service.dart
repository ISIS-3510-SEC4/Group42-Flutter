import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../models/contact.dart';
import '../../models/friend.dart';
import '../offline/local_store.dart';

/// Amigos del usuario: importados desde Google Contacts (con correo o
/// celular) o agregados con su código de Espoti.
///
/// El proyecto no tiene un backend de amistades (solicitudes, aceptación),
/// así que la lista se guarda en este dispositivo por usuario (LocalStore,
/// clave `espoti_friends_v1_<uid>`). No se crean amigos de ejemplo: la lista
/// empieza vacía.
class FriendsService {
  FriendsService._();
  static final FriendsService instance = FriendsService._();

  final ValueNotifier<List<Friend>> friends =
      ValueNotifier<List<Friend>>(const []);

  static String _key(String uid) => 'espoti_friends_v1_$uid';

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> load() async {
    final uid = _uid;
    if (uid == null) {
      friends.value = const [];
      return;
    }
    try {
      final raw = await LocalStore.instance.readJson(_key(uid));
      friends.value = raw is List
          ? raw.map(Friend.tryFromJson).whereType<Friend>().toList()
          : const [];
    } catch (e) {
      debugPrint('Friends not loaded: $e');
      friends.value = const [];
    }
  }

  /// Agrega los contactos elegidos sin duplicar. Devuelve cuántos se agregaron.
  Future<int> importContacts(List<GoogleContact> contacts) =>
      _addAll(contacts.map(Friend.fromContact));

  /// Agrega un amigo encontrado por código. Devuelve false si ya estaba.
  Future<bool> addFriend(Friend friend) async => await _addAll([friend]) == 1;

  Future<int> _addAll(Iterable<Friend> incoming) async {
    final known = {for (final f in friends.value) f.key};
    final added = [
      for (final f in incoming)
        if (f.key != 'phone:' && known.add(f.key)) f,
    ];
    if (added.isEmpty) return 0;
    await _save([...friends.value, ...added]);
    return added.length;
  }

  Future<void> remove(Friend friend) =>
      _save(friends.value.where((f) => f.key != friend.key).toList());

  Future<void> _save(List<Friend> list) async {
    list.sort((a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    friends.value = List.unmodifiable(list);
    final uid = _uid;
    if (uid == null) return;
    await LocalStore.instance
        .writeJson(_key(uid), [for (final f in list) f.toJson()]);
  }
}
