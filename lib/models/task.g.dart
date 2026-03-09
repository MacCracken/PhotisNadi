// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TaskAdapter extends TypeAdapter<Task> {
  @override
  final int typeId = 0;

  @override
  Task read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Task(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String?,
      status: fields[3] as TaskStatus,
      priority: fields[4] as TaskPriority,
      createdAt: fields[5] as DateTime,
      dueDate: fields[6] as DateTime?,
      projectId: fields[7] as String?,
      tags: (fields[8] as List).cast<String>(),
      taskKey: fields[9] as String?,
      modifiedAt: fields[10] as DateTime?,
      dependsOn: (fields[11] as List).cast<String>(),
      subtasks:
          fields.containsKey(12) ? (fields[12] as List).cast<String>() : [],
      estimatedMinutes: fields.containsKey(13) ? fields[13] as int? : null,
      trackedMinutes: fields.containsKey(14) ? fields[14] as int? ?? 0 : 0,
      recurrence: fields.containsKey(15) ? fields[15] as String? : null,
      attachments:
          fields.containsKey(16) ? (fields[16] as List).cast<String>() : [],
    );
  }

  @override
  void write(BinaryWriter writer, Task obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.priority)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.dueDate)
      ..writeByte(7)
      ..write(obj.projectId)
      ..writeByte(8)
      ..write(obj.tags)
      ..writeByte(9)
      ..write(obj.taskKey)
      ..writeByte(10)
      ..write(obj.modifiedAt)
      ..writeByte(11)
      ..write(obj.dependsOn)
      ..writeByte(12)
      ..write(obj.subtasks)
      ..writeByte(13)
      ..write(obj.estimatedMinutes)
      ..writeByte(14)
      ..write(obj.trackedMinutes)
      ..writeByte(15)
      ..write(obj.recurrence)
      ..writeByte(16)
      ..write(obj.attachments);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TaskStatusAdapter extends TypeAdapter<TaskStatus> {
  @override
  final int typeId = 1;

  @override
  TaskStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TaskStatus.todo;
      case 1:
        return TaskStatus.inProgress;
      case 2:
        return TaskStatus.inReview;
      case 3:
        return TaskStatus.blocked;
      case 4:
        return TaskStatus.done;
      default:
        return TaskStatus.todo;
    }
  }

  @override
  void write(BinaryWriter writer, TaskStatus obj) {
    switch (obj) {
      case TaskStatus.todo:
        writer.writeByte(0);
        break;
      case TaskStatus.inProgress:
        writer.writeByte(1);
        break;
      case TaskStatus.inReview:
        writer.writeByte(2);
        break;
      case TaskStatus.blocked:
        writer.writeByte(3);
        break;
      case TaskStatus.done:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TaskPriorityAdapter extends TypeAdapter<TaskPriority> {
  @override
  final int typeId = 2;

  @override
  TaskPriority read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TaskPriority.low;
      case 1:
        return TaskPriority.medium;
      case 2:
        return TaskPriority.high;
      default:
        return TaskPriority.low;
    }
  }

  @override
  void write(BinaryWriter writer, TaskPriority obj) {
    switch (obj) {
      case TaskPriority.low:
        writer.writeByte(0);
        break;
      case TaskPriority.medium:
        writer.writeByte(1);
        break;
      case TaskPriority.high:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskPriorityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
