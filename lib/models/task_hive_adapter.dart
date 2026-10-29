import 'package:hive/hive.dart';
import 'task_model.dart';

/// Adaptateur pour l'enum TaskPriority.
/// typeId doit être unique dans tout le projet Hive (0, 1, 2... choisis-en
/// un qui n'est utilisé par aucun autre adaptateur).
class TaskPriorityAdapter extends TypeAdapter<TaskPriority> {
  @override
  final int typeId = 1;

  @override
  TaskPriority read(BinaryReader reader) {
    final index = reader.readByte();
    return TaskPriority.values[index];
  }

  @override
  void write(BinaryWriter writer, TaskPriority obj) {
    writer.writeByte(obj.index);
  }
}

/// Adaptateur pour la classe Task.
/// Écrit/lit chaque champ dans un ordre fixe (peu importe l'ordre choisi,
/// tant qu'il est cohérent entre write() et read()).
class TaskAdapter extends TypeAdapter<Task> {
  @override
  final int typeId = 0;

  @override
  Task read(BinaryReader reader) {
    return Task(
      id: reader.readString(),
      title: reader.readString(),
      content: reader.readString(),
      dueDate: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      priority: TaskPriority.values[reader.readByte()],
      isDone: reader.readBool(),
    );
  }

  @override
  void write(BinaryWriter writer, Task obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.title);
    writer.writeString(obj.content);
    writer.writeInt(obj.dueDate.millisecondsSinceEpoch);
    writer.writeByte(obj.priority.index);
    writer.writeBool(obj.isDone);
  }
}
