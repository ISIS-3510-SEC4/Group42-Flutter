import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:espoti/core/services/auth_service.dart';
import 'package:espoti/models/user.dart';

void main() {
  group('AuthService error message translations', () {
    test('translates user-not-found properly', () {
      final exception = FirebaseAuthException(code: 'user-not-found');
      final message = AuthService.getReadableAuthError(exception);
      expect(message, 'No existe ninguna cuenta con este correo electrónico.');
    });

    test('translates invalid-credential properly', () {
      final exception = FirebaseAuthException(code: 'invalid-credential');
      final message = AuthService.getReadableAuthError(exception);
      expect(message, 'Credenciales inválidas. Revisa tu correo y contraseña.');
    });

    test('translates email-already-in-use properly', () {
      final exception = FirebaseAuthException(code: 'email-already-in-use');
      final message = AuthService.getReadableAuthError(exception);
      expect(message, 'Este correo ya está registrado en la base de datos.');
    });

    test('translates weak-password properly', () {
      final exception = FirebaseAuthException(code: 'weak-password');
      final message = AuthService.getReadableAuthError(exception);
      expect(message, 'La contraseña debe tener mínimo 8 caracteres, mayúscula, minúscula y solo punto (.)');
    });

    test('falls back to custom message or default on unknown code', () {
      final exception = FirebaseAuthException(code: 'unknown-code', message: 'Custom message');
      final message = AuthService.getReadableAuthError(exception);
      expect(message, 'Custom message');
    });
  });

  group('AuthService.validatePassword', () {
    test('rechaza contraseñas con menos de 8 caracteres', () {
      expect(AuthService.validatePassword('Pass1.'), 'La contraseña debe tener mínimo 8 caracteres');
    });

    test('rechaza contraseñas sin mayúscula', () {
      expect(AuthService.validatePassword('password123.'), 'La contraseña debe tener mínimo una letra mayúscula');
    });

    test('rechaza contraseñas sin minúscula', () {
      expect(AuthService.validatePassword('PASSWORD123.'), 'La contraseña debe tener mínimo una letra minúscula');
    });

    test('rechaza caracteres especiales prohibidos como punto y coma, asterisco, numeral y emojis', () {
      expect(AuthService.validatePassword('Password;123'), isNotNull);
      expect(AuthService.validatePassword('Password*123'), isNotNull);
      expect(AuthService.validatePassword('Password#123'), isNotNull);
      expect(AuthService.validatePassword('Password😄123'), isNotNull);
      expect(AuthService.validatePassword('Password 123'), isNotNull);
    });

    test('acepta contraseñas válidas con mayúscula, minúscula, números y punto opcional', () {
      expect(AuthService.validatePassword('MiPassword123.'), isNull);
      expect(AuthService.validatePassword('SuperClave2026'), isNull);
      expect(AuthService.validatePassword('ClaveConPunto.'), isNull);
    });
  });

  group('AuthService.isValidEmailDomain', () {
    test('accepts valid email domains', () {
      expect(AuthService.isValidEmailDomain('test@gmail.com'), isTrue);
      expect(AuthService.isValidEmailDomain('user.name@uniandes.edu.co'), isTrue);
      expect(AuthService.isValidEmailDomain('hello-world@company.org'), isTrue);
    });

    test('rejects invalid email formats and domains', () {
      expect(AuthService.isValidEmailDomain('invalid'), isFalse);
      expect(AuthService.isValidEmailDomain('invalid@'), isFalse);
      expect(AuthService.isValidEmailDomain('invalid@domain'), isFalse);
      expect(AuthService.isValidEmailDomain('invalid@domain.'), isFalse);
      expect(AuthService.isValidEmailDomain('invalid@.com'), isFalse);
      expect(AuthService.isValidEmailDomain('invalid@domain..com'), isFalse);
      expect(AuthService.isValidEmailDomain(''), isFalse);
    });
  });

  group('AppUser model', () {
    test('serializes and deserializes properly', () {
      const user = AppUser(
        firstName: 'Carlos',
        lastName: 'Pérez',
        name: 'Carlos Pérez',
        code: 'ESP123',
        location: 'Bogotá',
        preferences: ['Walk', 'Coffee'],
        maxRadiusKm: 15,
        avatarUrl: 'https://avatar.url/1',
        email: 'carlos@test.com',
        description: 'Amante del café',
      );

      final json = user.toJson();
      final fromJson = AppUser.fromJson(json);

      expect(fromJson.firstName, 'Carlos');
      expect(fromJson.lastName, 'Pérez');
      expect(fromJson.name, 'Carlos Pérez');
      expect(fromJson.code, 'ESP123');
      expect(fromJson.preferences, ['Walk', 'Coffee']);
      expect(fromJson.avatarUrl, 'https://avatar.url/1');
    });

    test('copyWith updates fields correctly', () {
      const user = AppUser(
        firstName: 'Ana',
        lastName: 'Gómez',
        name: 'Ana Gómez',
        code: 'ESP456',
        location: 'Medellín',
        preferences: ['Study'],
        maxRadiusKm: 5,
        email: 'ana@test.com',
        description: '',
      );

      final updated = user.copyWith(
        firstName: 'Ana María',
        preferences: ['Study', 'Party'],
      );

      expect(updated.firstName, 'Ana María');
      expect(updated.lastName, 'Gómez');
      expect(updated.name, 'Ana María Gómez');
      expect(updated.preferences, ['Study', 'Party']);
      expect(updated.location, 'Medellín');
    });
  });
}
