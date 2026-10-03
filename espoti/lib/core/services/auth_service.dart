import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  bool get isAuthenticated => _auth.currentUser != null;

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      throw getReadableAuthError(e);
    }
  }

  Future<UserCredential> registerWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final passwordError = validatePassword(password);
    if (passwordError != null) {
      throw passwordError;
    }

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      throw getReadableAuthError(e);
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  static bool isValidEmailDomain(String email) {
    final trimmed = email.trim();
    final regex = RegExp(
      r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*\.[a-zA-Z]{2,}$',
    );
    if (!regex.hasMatch(trimmed)) return false;
    final parts = trimmed.split('@');
    if (parts.length != 2) return false;
    final domain = parts[1];
    if (domain.startsWith('.') || domain.endsWith('.') || domain.contains('..')) {
      return false;
    }
    return true;
  }

  static String? validatePassword(String password) {
    if (password.isEmpty) {
      return 'La contraseña es obligatoria';
    }
    if (password.length < 8) {
      return 'La contraseña debe tener mínimo 8 caracteres';
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'La contraseña debe tener mínimo una letra mayúscula';
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'La contraseña debe tener mínimo una letra minúscula';
    }
    if (!RegExp(r'^[a-zA-Z0-9.]+$').hasMatch(password)) {
      return 'La contraseña no puede tener caracteres especiales ni emojis, solo punto (.)';
    }
    return null;
  }

  static String getReadableAuthError(FirebaseAuthException exception) {
    switch (exception.code) {
      case 'user-not-found':
        return 'No existe ninguna cuenta con este correo electrónico.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Credenciales inválidas. Revisa tu correo y contraseña.';
      case 'email-already-in-use':
        return 'Este correo ya está registrado en la base de datos.';
      case 'invalid-email':
        return 'El formato del correo electrónico no es válido.';
      case 'weak-password':
        return 'La contraseña debe tener mínimo 8 caracteres, mayúscula, minúscula y solo punto (.)';
      case 'user-disabled':
        return 'Esta cuenta ha sido inhabilitada.';
      case 'network-request-failed':
        return 'Error de conexión. Verifica tu conexión a internet.';
      case 'too-many-requests':
        return 'Demasiados intentos fallidos. Intenta más tarde.';
      default:
        return exception.message ?? 'Ocurrió un error inesperado de autenticación.';
    }
  }
}
