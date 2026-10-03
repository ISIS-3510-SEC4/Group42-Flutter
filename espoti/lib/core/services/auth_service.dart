import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Stream to listen to real-time authentication state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Currently logged in user, or null if unauthenticated.
  User? get currentUser => _auth.currentUser;

  /// Whether a user is currently logged in.
  bool get isAuthenticated => _auth.currentUser != null;
  GoogleSignInAccount? get googleAccount => _googleAccount;

  /// Sign in with email and password.
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

  /// Register a new account with email and password.
  Future<UserCredential> registerWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
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

  Future<void>? _googleInit;
  GoogleSignInAccount? _googleAccount;

  /// Google Sign-In instance, initialized once. On Android the client id is
  /// taken from google-services.json (default_web_client_id); an optional
  /// override can be passed with --dart-define=GOOGLE_SERVER_CLIENT_ID=...
  Future<GoogleSignIn> get googleSignIn async {
    const serverClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
    _googleInit ??= GoogleSignIn.instance.initialize(
      serverClientId: serverClientId.isEmpty ? null : serverClientId,
    );
    try {
      await _googleInit;
    } catch (_) {
      _googleInit = null; // allow retry
      rethrow;
    }
    return GoogleSignIn.instance;
  }

  /// Sign in with Google through the existing Firebase Auth project.
  /// Returns null if the user cancels; throws a readable String on errors.
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final google = await googleSignIn;
      if (!google.supportsAuthenticate()) {
        throw 'Google Sign-In no está disponible en esta plataforma.';
      }
      final account = await google.authenticate();
      _googleAccount = account;
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw 'No se pudo obtener la credencial de Google. Inténtalo de nuevo.';
      }
      return await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      debugPrint('Google sign-in error: ${e.code} ${e.description}');
      throw 'No se pudo iniciar sesión con Google. Verifica tu conexión y la configuración de la app.';
    } on FirebaseAuthException catch (e) {
      throw getReadableAuthError(e);
    }
  }

  /// Sign out the current user (Firebase and Google session).
  Future<void> signOut() async {
    try {
      await (await googleSignIn).signOut();
    } catch (e) {
      debugPrint('Google sign-out skipped: $e');
    }
    _googleAccount = null;
    await _auth.signOut();
  }

  /// Validates that an email has a proper syntax and a valid domain with a TLD.
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

  /// Translates common Firebase auth error codes into friendly Spanish messages.
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
        return 'La contraseña es muy débil. Debe tener al menos 6 caracteres.';
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
