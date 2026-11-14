import 'package:espoti/core/services/friend_code_service.dart';
import 'package:espoti/models/contact.dart';
import 'package:espoti/models/friend.dart';
import 'package:flutter_test/flutter_test.dart';

// Pruebas de amigos: contactos con solo celular y validación de códigos.
void main() {
  test('a contact with only a phone number becomes a friend', () {
    const contact = GoogleContact(id: 'people/c1', name: '', email: '', phone: '+57 300 123 4567');
    final friend = Friend.fromContact(contact);
    expect(friend.displayName, '+57 300 123 4567');
    expect(friend.detail, '+57 300 123 4567');
    expect(friend.key, 'phone:573001234567');
  });

  test('friend keys avoid duplicates: uid, then email, then phone', () {
    expect(const Friend(name: 'A', uid: 'u1', email: 'a@x.com').key, 'uid:u1');
    expect(const Friend(name: 'A', email: 'A@X.com').key, 'email:a@x.com');
  });

  test('friend survives a JSON round trip', () {
    const f = Friend(name: 'Ana', uid: 'u1', code: 'ESP4821', photoUrl: 'p');
    final restored = Friend.tryFromJson(f.toJson())!;
    expect(restored.uid, 'u1');
    expect(restored.code, 'ESP4821');
    expect(restored.detail, 'Espoti code: ESP4821');
  });

  test('friend codes are normalized and validated', () {
    expect(FriendCodeService.normalize(' esp-4821 '), 'ESP4821');
    expect(FriendCodeService.validate(''), isNotNull);
    expect(FriendCodeService.validate('ab'), isNotNull);
    expect(FriendCodeService.validate('ESP4821'), isNull);
  });
}
