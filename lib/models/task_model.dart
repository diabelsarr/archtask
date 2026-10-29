/// Niveaux de priorité disponibles pour une tâche.
enum TaskPriority { high, medium, low }

extension TaskPriorityLabel on TaskPriority {
  String get label {
    switch (this) {
      case TaskPriority.high:
        return 'High';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.low:
        return 'Low';
    }
  }
}

/// Représente une tâche telle que définie :
/// titre, contenu, date, priorité.
class Task {
  final String id;
  final String title;
  final String content;
  final DateTime dueDate;
  final TaskPriority priority;
  final bool isDone;
  const Task({
    required this.id,
    required this.title,
    required this.content,
    required this.dueDate,
    required this.priority,
    this.isDone = false,
  });

  Task copyWith({
    String? title,
    String? content,
    DateTime? dueDate,
    TaskPriority? priority,
    bool? isDone,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      isDone: isDone ?? this.isDone,
    );
  }

  /// Construit une Task à partir de la réponse Strapi.

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['documentId']?.toString() ?? json['id'].toString(),
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      dueDate: DateTime.tryParse(json['dueDate'] ?? '') ?? DateTime.now(),
      priority: _priorityFromString(json['priority']),
      isDone: json['isDone'] ?? false,
    );
  }

  /// Convertit une Task en JSON pour l'envoyer à Strapi.
  /// Strapi attend le body enveloppé dans { "data": {...} }.
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'dueDate': dueDate.toIso8601String(),
      'priority': priority.name,
      'isDone': isDone,
    };
  }

  static TaskPriority _priorityFromString(String? value) {
    switch (value) {
      case 'high':
        return TaskPriority.high;
      case 'low':
        return TaskPriority.low;
      case 'medium':
      default:
        return TaskPriority.medium;
    }
  }
}
