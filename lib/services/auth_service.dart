import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_config.dart';

/// Représente l'utilisateur actuellement connecté (session).
class AppUser {
  final int id;
  final String fullName;
  final String email;
  final String phone;
  final String token;
  final String? avatarUrl;

  AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.token,
    this.avatarUrl,
  });
}

/// Gère la connexion, l'inscription, la déconnexion, la mise à jour du
/// profil, et la persistance de session via les préférences utilisateur
/// (SharedPreferences) — Livrables 4 et 5.
class AuthService {
  static const _keyToken = 'auth_token';
  static const _keyUserId = 'auth_user_id';
  static const _keyFullName = 'auth_full_name';
  static const _keyEmail = 'auth_email';
  static const _keyPhone = 'auth_phone';
  static const _keyAvatarUrl = 'auth_avatar_url';

  /// Connexion via l'endpoint natif de Strapi (Users & Permissions plugin).
  Future<AppUser> login({
    required String identifier, // email ou username
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/local'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'identifier': identifier,
        'password': password,
      }),
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 200) {
      final jwt = body['jwt'];

      // /auth/local ne renvoie pas les champs média (comme "avatar") par
      // défaut. On refait un appel dédié pour le récupérer correctement.
      String? avatarUrl;
      try {
        final meResponse = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/users/me?populate=avatar'),
          headers: {'Authorization': 'Bearer $jwt'},
        );
        if (meResponse.statusCode == 200) {
          final meBody = jsonDecode(meResponse.body);
          avatarUrl = _extractAvatarUrl(meBody['avatar']);
        }
      } catch (_) {
        // Pas bloquant : l'utilisateur pourra re-uploader son avatar si besoin.
      }

      final user = AppUser(
        id: body['user']['id'],
        fullName: body['user']['fullName'] ?? '',
        email: body['user']['email'] ?? '',
        phone: body['user']['phone'] ?? '',
        token: jwt,
        avatarUrl: avatarUrl,
      );
      await _saveSession(user);
      return user;
    } else {
      final message = body['error']?['message'] ?? 'Échec de la connexion';
      throw Exception(message);
    }
  }

  /// Inscription en deux étapes :
  /// 1. Strapi /auth/local/register n'accepte que username/email/password
  ///    (il rejette les champs personnalisés avec "Invalid parameters").
  /// 2. On met donc à jour fullName/phone juste après, via /users/{id},
  ///    en utilisant le token JWT reçu à l'étape 1.
  Future<void> register({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) async {
    final registerResponse = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/local/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': email.split('@').first,
        'email': email,
        'password': password,
      }),
    );

    final registerBody = jsonDecode(registerResponse.body);

    if (registerResponse.statusCode != 200) {
      final message =
          registerBody['error']?['message'] ?? 'Échec de l\'inscription';
      throw Exception(message);
    }

    final userId = registerBody['user']['id'];
    final jwt = registerBody['jwt'];

    // Étape 2 : on complète le profil avec fullName et phone.
    // Si ça échoue (ex: permission "update" pas encore activée côté Strapi),
    // on ne bloque PAS l'inscription : le compte existe déjà à ce stade.
    try {
      await http.put(
        Uri.parse('${ApiConfig.baseUrl}/users/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwt',
        },
        body: jsonEncode({
          'fullName': fullName,
          'phone': phone,
        }),
      );
    } catch (_) {
      // On ignore volontairement : l'inscription reste un succès.
    }
    // Pas de connexion automatique : le cahier des charges demande une
    // redirection vers la page de connexion après inscription.
  }

  /// Met à jour les informations du profil (nom, téléphone, email).
  /// Met aussi à jour la session locale avec les nouvelles valeurs.
  Future<AppUser> updateProfile({
    required String fullName,
    required String phone,
    required String email,
  }) async {
    final session = await getSavedSession();
    if (session == null) throw Exception('Aucune session active');

    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/users/${session.id}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.token}',
      },
      body: jsonEncode({
        'fullName': fullName,
        'phone': phone,
        'email': email,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Échec de la mise à jour du profil');
    }

    final body = jsonDecode(response.body);
    final updated = AppUser(
      id: session.id,
      fullName: body['fullName'] ?? fullName,
      email: body['email'] ?? email,
      phone: body['phone'] ?? phone,
      token: session.token,
      avatarUrl: session.avatarUrl,
    );
    await _saveSession(updated);
    return updated;
  }

  /// Upload une photo vers Strapi (endpoint /api/upload), l'associe au
  /// champ "avatar" du compte utilisateur, et retourne l'URL complète.
  /// C'est cette association côté serveur qui manquait avant : sans elle,
  /// l'avatar était uploadé mais jamais rattaché au compte, donc il
  /// disparaissait à la prochaine connexion (le champ restait vide).
  Future<String> uploadAvatar(File imageFile) async {
    final session = await getSavedSession();
    if (session == null) throw Exception('Aucune session active');

    // Étape 1 : upload du fichier dans la médiathèque Strapi.
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/upload'),
    );
    request.headers['Authorization'] = 'Bearer ${session.token}';
    request.files
        .add(await http.MultipartFile.fromPath('files', imageFile.path));
//back to review this part
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Échec de l\'envoi de la photo');
    }

    final List<dynamic> body = jsonDecode(response.body);
    final int fileId = body.first['id'];
    final String relativeUrl = body.first['url'];
    final domain = ApiConfig.baseUrl.replaceAll('/api', '');
    final fullUrl = '$domain$relativeUrl';

    // Étape 2 : on attache ce fichier au champ "avatar" du compte -
    // c'est l'étape qui manquait avant.
    final attachResponse = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/users/${session.id}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.token}',
      },
      body: jsonEncode({'avatar': fileId}),
    );

    if (attachResponse.statusCode != 200) {
      throw Exception('Photo envoyée mais impossible de l\'associer au profil');
    }

    return fullUrl;
  }

  /// Associe l'avatar uploadé au compte utilisateur, et met à jour la
  /// session locale pour que l'UI se rafraîchisse immédiatement.
  Future<void> updateAvatarUrl(String avatarUrl) async {
    final session = await getSavedSession();
    if (session == null) throw Exception('Aucune session active');

    final updated = AppUser(
      id: session.id,
      fullName: session.fullName,
      email: session.email,
      phone: session.phone,
      token: session.token,
      avatarUrl: avatarUrl,
    );
    await _saveSession(updated);
  }

  String? _extractAvatarUrl(dynamic avatarField) {
    if (avatarField == null) return null;
    final relativeUrl = avatarField['url'];
    if (relativeUrl == null) return null;
    final domain = ApiConfig.baseUrl.replaceAll('/api', '');
    return '$domain$relativeUrl';
  }

  Future<void> _saveSession(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, user.token);
    await prefs.setInt(_keyUserId, user.id);
    await prefs.setString(_keyFullName, user.fullName);
    await prefs.setString(_keyEmail, user.email);
    await prefs.setString(_keyPhone, user.phone);
    if (user.avatarUrl != null) {
      await prefs.setString(_keyAvatarUrl, user.avatarUrl!);
    }
  }

  /// Récupère la session sauvegardée (null si personne n'est connecté).
  Future<AppUser?> getSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyToken);
    if (token == null) return null;

    return AppUser(
      id: prefs.getInt(_keyUserId) ?? 0,
      fullName: prefs.getString(_keyFullName) ?? '',
      email: prefs.getString(_keyEmail) ?? '',
      phone: prefs.getString(_keyPhone) ?? '',
      token: token,
      avatarUrl: prefs.getString(_keyAvatarUrl),
    );
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyFullName);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyPhone);
    await prefs.remove(_keyAvatarUrl);
  }
}