import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/fpl_models.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

class AuthService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _keyCookie = 'fpl_session_cookie';
  static const String _keyEntryId = 'fpl_entry_id';
  static const String _keyFirstName = 'fpl_first_name';
  static const String _keyLastName = 'fpl_last_name';
  static const String _keyEmail = 'fpl_email';

  // Official/Unofficial FPL Authentication Endpoints
  static const String _plLoginUrl =
      'https://users.premierleague.com/accounts/login/';
  static const String _plOAuthTokenUrl =
      'https://account.premierleague.com/as/token.oauth2';
  static const String _meEndpoint = '${kFplBaseUrl}me/';

  static FplUserSession? currentSession;

  static const Map<String, String> _baseHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
    'Accept': 'application/json, text/plain, */*',
    'Origin': 'https://fantasy.premierleague.com',
    'Referer': 'https://fantasy.premierleague.com/',
  };

  /// Restores saved session cookie/token on launch without ever storing the password.
  static Future<FplUserSession?> tryAutoLogin() async {
    try {
      final cookie = await _storage.read(key: _keyCookie);
      final entryIdStr = await _storage.read(key: _keyEntryId);
      if (cookie == null || cookie.isEmpty || entryIdStr == null) {
        return null;
      }
      final entryId = int.tryParse(entryIdStr) ?? 0;
      if (entryId <= 0) return null;

      final firstName = await _storage.read(key: _keyFirstName) ?? 'FPL';
      final lastName = await _storage.read(key: _keyLastName) ?? 'Manager';
      final email = await _storage.read(key: _keyEmail) ?? '';

      currentSession = FplUserSession(
        entryId: entryId,
        firstName: firstName,
        lastName: lastName,
        email: email,
        cookieHeader: cookie,
      );

      // Verify silently with /api/me/ if internet is available
      try {
        final refreshed = await _fetchMeProfile(cookie, email);
        if (refreshed != null) {
          currentSession = refreshed;
          await _saveSession(refreshed);
        }
      } catch (_) {
        // Keep cached session if offline
      }
      return currentSession;
    } catch (_) {
      return null;
    }
  }

  /// Performs direct in-app email + password login against FPL.
  static Future<FplUserSession> loginWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || password.isEmpty) {
      throw AuthException('Please enter both your FPL email and password.');
    }

    try {
      // Step 1: Direct POST to users.premierleague.com/accounts/login/
      final client = http.Client();
      try {
        final req = http.Request('POST', Uri.parse(_plLoginUrl));
        req.followRedirects = false;
        req.headers.addAll({
          ..._baseHeaders,
          'Content-Type': 'application/x-www-form-urlencoded',
        });
        req.bodyFields = {
          'login': cleanEmail,
          'password': password,
          'app': 'plfpl-web',
          'redirect_uri': 'https://fantasy.premierleague.com/a/login',
        };

        final streamed =
            await client.send(req).timeout(const Duration(seconds: 20));
        final resp = await http.Response.fromStream(streamed);

        final location = resp.headers['location'] ?? '';
        if (location.contains('state=fail') ||
            location.contains('error=') ||
            resp.statusCode == 401) {
          throw AuthException(
              'Wrong email or password. Please double-check your FPL login credentials.');
        }

        String cookieString = _extractCookies(resp.headers);

        // If cookies weren't returned on first hop, try following redirect or fallback OAuth
        if (cookieString.isEmpty && location.isNotEmpty) {
          final followUri = location.startsWith('http')
              ? Uri.parse(location)
              : Uri.parse('https://users.premierleague.com$location');
          final followReq = http.Request('GET', followUri)
            ..followRedirects = false
            ..headers.addAll(_baseHeaders);
          final followStream =
              await client.send(followReq).timeout(const Duration(seconds: 15));
          final followResp = await http.Response.fromStream(followStream);
          cookieString = _extractCookies(followResp.headers);
        }

        // Step 2: If classic endpoint didn't issue a cookie, try OAuth token exchange
        if (cookieString.isEmpty) {
          cookieString = await _tryOAuthTokenLogin(cleanEmail, password);
        }

        if (cookieString.isEmpty) {
          if (resp.statusCode == 403 || resp.statusCode == 503) {
            throw AuthException(
              'FPL login service blocked the request or changed (HTTP ${resp.statusCode}). Please check lib/services/auth_service.dart.',
            );
          }
          throw AuthException(
            'Wrong credentials or FPL login service changed (no session token returned).',
          );
        }

        // Step 3: Call https://fantasy.premierleague.com/api/me/ to get the user's Team ID
        final session = await _fetchMeProfile(cookieString, cleanEmail);
        if (session == null) {
          throw AuthException(
            'Logged in, but /api/me/ did not return an active 2026/27 FPL team ID. Make sure your FPL account has created a team for 2026/27, or check if FPL changed its login service.',
          );
        }

        currentSession = session;
        await _saveSession(session);
        return session;
      } finally {
        client.close();
      }
    } on SocketException {
      throw AuthException(
          'No internet connection. Please check your Wi-Fi or mobile data and try again.');
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(
          'Login failed or FPL login service changed: ${e.toString()}');
    }
  }

  static Future<String> _tryOAuthTokenLogin(
      String email, String password) async {
    try {
      final resp = await http
          .post(
            Uri.parse(_plOAuthTokenUrl),
            headers: {
              ..._baseHeaders,
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: {
              'grant_type': 'password',
              'username': email,
              'password': password,
              'client_id': 'bf82c263-ef12-49e5-942c-b37f2f2b7130',
              'scope': 'openid profile email offline_access',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (resp.statusCode == 400 || resp.statusCode == 401) {
        throw AuthException(
            'Wrong email or password. Please verify your Premier League account credentials.');
      }

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final accessToken = data['access_token']?.toString() ?? '';
        final cookies = _extractCookies(resp.headers);
        if (accessToken.isNotEmpty) {
          return cookies.isNotEmpty
              ? '$cookies; Bearer=$accessToken'
              : 'Bearer=$accessToken';
        }
        return cookies;
      }
    } on AuthException {
      rethrow;
    } catch (_) {}
    return '';
  }

  static Future<FplUserSession?> _fetchMeProfile(
      String cookieHeader, String email) async {
    final headers = <String, String>{
      ..._baseHeaders,
      'Cookie': cookieHeader,
    };
    if (cookieHeader.contains('Bearer=')) {
      final token = cookieHeader.split('Bearer=').last.split(';').first.trim();
      headers['Authorization'] = 'Bearer $token';
    }

    final resp = await http
        .get(Uri.parse(_meEndpoint), headers: headers)
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode == 401 || resp.statusCode == 403) {
      throw AuthException(
          'Session rejected by /api/me/ (HTTP ${resp.statusCode}). Wrong credentials or login service changed.');
    }

    if (resp.statusCode != 200) {
      throw AuthException(
          'FPL profile service returned HTTP ${resp.statusCode}. The login service may have changed.');
    }

    final Map<String, dynamic> data = jsonDecode(resp.body);
    final playerObj = data['player'];
    if (playerObj == null || playerObj is! Map<String, dynamic>) {
      return null;
    }

    final int entryId = playerObj['entry'] ?? data['entry'] ?? 0;
    if (entryId <= 0) {
      return null;
    }

    return FplUserSession(
      entryId: entryId,
      firstName: (playerObj['first_name'] ?? 'FPL').toString(),
      lastName: (playerObj['last_name'] ?? 'Manager').toString(),
      email: email,
      cookieHeader: cookieHeader,
    );
  }

  static String _extractCookies(Map<String, String> headers) {
    final rawSetCookie =
        headers['set-cookie'] ?? headers['Set-Cookie'] ?? '';
    if (rawSetCookie.isEmpty) return '';

    final parts = rawSetCookie.split(RegExp(r',(?=[^ ;]+=)'));
    final kept = <String>[];
    for (final part in parts) {
      final kv = part.split(';').first.trim();
      if (kv.contains('=')) {
        kept.add(kv);
      }
    }
    return kept.join('; ');
  }

  static Future<void> _saveSession(FplUserSession session) async {
    await _storage.write(key: _keyCookie, value: session.cookieHeader);
    await _storage.write(
        key: _keyEntryId, value: session.entryId.toString());
    await _storage.write(key: _keyFirstName, value: session.firstName);
    await _storage.write(key: _keyLastName, value: session.lastName);
    await _storage.write(key: _keyEmail, value: session.email);
  }

  static Map<String, String> getAuthHeaders() {
    final cookie = currentSession?.cookieHeader ?? '';
    final headers = <String, String>{..._baseHeaders};
    if (cookie.isNotEmpty) {
      headers['Cookie'] = cookie;
      if (cookie.contains('Bearer=')) {
        final token = cookie.split('Bearer=').last.split(';').first.trim();
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  static Future<void> logout() async {
    currentSession = null;
    await _storage.deleteAll();
  }
}
