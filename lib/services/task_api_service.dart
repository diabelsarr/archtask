import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/task_model.dart';
import '../utils/api_config.dart';
import 'auth_service.dart';

/// Service qui gère toutes les communications avec l'API Strapi.
/// Toutes les requêtes incluent maintenant le token JWT de l'utilisateur
/// connecté, requis depuis qu'on a restreint l'accès aux tâches aux
/// utilisateurs authentifiés (Livrable 4).
class TaskApiService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Récupère la liste de toutes les tâches.
  Future<List<Task>> getTasks() async {
    final headers = await _authHeaders();
    final response =
        await http.get(Uri.parse('${ApiConfig.baseUrl}/tasks'), headers: headers);

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final List<dynamic> data = body['data'];
      return data.map((item) => Task.fromJson(item)).toList();
    } else {
      throw Exception('Échec du chargement des tâches (${response.statusCode})');
    }
  }

  /// Crée une nouvelle tâche et retourne la tâche créée (avec son id Strapi).
  Future<Task> createTask(Task task) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/tasks'),
      headers: headers,
      body: jsonEncode({'data': task.toJson()}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final body = jsonDecode(response.body);
      return Task.fromJson(body['data']);
    } else {
      throw Exception('Échec de la création de la tâche (${response.statusCode})');
    }
  }

  /// Modifie une tâche existante. [id] doit être le documentId Strapi.
  Future<Task> updateTask(String id, Task task) async {
    final headers = await _authHeaders();
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/tasks/$id'),
      headers: headers,
      body: jsonEncode({'data': task.toJson()}),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return Task.fromJson(body['data']);
    } else {
      throw Exception('Échec de la modification (${response.statusCode})');
    }
  }

  /// Supprime une tâche. [id] doit être le documentId Strapi.
  Future<void> deleteTask(String id) async {
    final headers = await _authHeaders();
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/tasks/$id'),
      headers: headers,
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Échec de la suppression (${response.statusCode})');
    }
  }
}
