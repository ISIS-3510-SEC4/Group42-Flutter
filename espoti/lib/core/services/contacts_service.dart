import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../../models/contact.dart';
import 'auth_service.dart';

class ContactsException implements Exception {
  final String message;
  final bool permissionDenied;
  const ContactsException(this.message, {this.permissionDenied = false});

  @override
  String toString() => message;
}

/// Reads the user's Google Contacts (read-only) through the People API.
/// The access token comes from Google's authorization flow at runtime;
/// no key or secret is stored in the app.
class ContactsService {
  ContactsService({http.Client? client}) : _client = client ?? http.Client();

  static const String contactsScope =
      'https://www.googleapis.com/auth/contacts.readonly';

  final http.Client _client;

  Future<String> _accessToken({bool forceRefresh = false}) async {
    try {
      final account = AuthService().googleAccount;

      if (account == null) {
        throw const ContactsException(
          'Sign in with Google to access your contacts.',
        );
      }

      final authClient = account.authorizationClient;
      var authorization = forceRefresh
          ? null
          : await authClient.authorizationForScopes([contactsScope]);
      authorization ??= await authClient.authorizeScopes([contactsScope]);
      return authorization.accessToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const ContactsException(
          'We need your permission to read your Google contacts.',
          permissionDenied: true,
        );
      }
      throw const ContactsException(
          'Access to your Google contacts could not be authorized.');
    }
  }

  /// Fetches contacts that have an email address or a phone number, sorted by
  /// name. (Se piden también los teléfonos: el permiso contacts.readonly ya
  /// los incluye, no hace falta un permiso nuevo.)
  Future<List<GoogleContact>> fetchContacts() async {
    // Authenticate Actors: only signed-in Espoti users can read contacts.
    if (!AuthService().isAuthenticated) {
      throw const ContactsException('Log in to invite contacts.');
    }

    var token = await _accessToken();
    final contacts = <GoogleContact>[];
    String? pageToken;
    var retried = false;

    for (var page = 0; page < 5; page++) {
      final uri = Uri.https('people.googleapis.com', '/v1/people/me/connections', {
        'personFields': 'names,emailAddresses,phoneNumbers,photos',
        'pageSize': '200',
        'sortOrder': 'FIRST_NAME_ASCENDING',
        if (pageToken != null) 'pageToken': pageToken,
      });

      http.Response response;
      try {
          response = await _client
              .get(uri, headers: {'Authorization': 'Bearer $token'});

          // Status only: the body holds the user's contacts (personal data).
          debugPrint('CONTACTS STATUS: ${response.statusCode}');
      } catch (_) {
        throw const ContactsException(
            'Connection error while loading your contacts.');
      }

      if (response.statusCode == 401 && !retried) {
        retried = true;
        token = await _accessToken(forceRefresh: true);
        page--;
        continue;
      }
      if (response.statusCode == 403) {
        throw const ContactsException(
            'Google denied access to your contacts. Check that the People API is enabled.',
            permissionDenied: true);
      }
      if (response.statusCode != 200) {
        throw const ContactsException('Your contacts could not be loaded.');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const ContactsException('Invalid response from Google Contacts.');
      }
      for (final person in (decoded['connections'] as List? ?? const [])) {
        final contact = _parse(person);
        if (contact != null) contacts.add(contact);
      }
      pageToken = decoded['nextPageToken'] as String?;
      if (pageToken == null) break;
    }

    contacts.sort((a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return contacts;
  }

  GoogleContact? _parse(dynamic person) {
    if (person is! Map) return null;
    final emails = person['emailAddresses'];
    final email = (emails is List && emails.isNotEmpty && emails.first is Map)
        ? ((emails.first as Map)['value'] as String? ?? '').trim()
        : '';
    final phones = person['phoneNumbers'];
    final phone = (phones is List && phones.isNotEmpty && phones.first is Map)
        ? (((phones.first as Map)['canonicalForm'] ??
                    (phones.first as Map)['value']) as String? ??
                '')
            .trim()
        : '';
    // Sin correo ni celular no hay cómo identificar al contacto.
    if (email.isEmpty && phone.isEmpty) return null;

    final names = person['names'];
    final name = (names is List && names.isNotEmpty && names.first is Map)
        ? ((names.first as Map)['displayName'] as String? ?? '')
        : '';
    final photos = person['photos'];
    final photo = (photos is List && photos.isNotEmpty && photos.first is Map)
        ? ((photos.first as Map)['url'] as String? ?? '')
        : '';

    return GoogleContact(
      id: person['resourceName'] as String? ?? (email.isNotEmpty ? email : phone),
      name: name,
      email: email,
      phone: phone,
      photoUrl: photo,
    );
  }

  void close() => _client.close();
}
