import 'package:cloud_firestore/cloud_firestore.dart';

class Todo {
  final String id;
  final String text;
  final String? priority;
  final DateTime? dueAt;
  final DateTime? createdAt;
  final DateTime? completedAt;
  final String? recurrence;

  Todo({
    required this.id,
    required this.text,
    this.priority,
    this.dueAt,
    this.createdAt,
    this.completedAt,
    this.recurrence,
  });

  factory Todo.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Todo(
      id: doc.id,
      text: data['text'] ?? '',
      priority: data['priority'],
      dueAt: (data['dueAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      recurrence: data['recurrence'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'priority': priority,
      'dueAt': dueAt,
      'createdAt': createdAt,
      'completedAt': completedAt,
      'recurrence': recurrence,
    };
  }

  Todo copyWith({
    String? id,
    String? text,
    String? priority,
    DateTime? dueAt,
    DateTime? createdAt,
    DateTime? completedAt,
    String? recurrence,
  }) {
    return Todo(
      id: id ?? this.id,
      text: text ?? this.text,
      priority: priority ?? this.priority,
      dueAt: dueAt ?? this.dueAt,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      recurrence: recurrence ?? this.recurrence,
    );
  }
}