import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../data/todo.dart';
import '../../notification_helper.dart';

final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

class DetailScreen extends StatefulWidget {
  final Todo todo;

  const DetailScreen({super.key, required this.todo});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late TextEditingController _textController;
  DateTime? _selectedDueDate;
  String? _selectedPriority;
  String? _selectedRecurrence; // Add recurrence field

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.todo.text);
    _selectedDueDate = widget.todo.dueAt;
    _selectedPriority = widget.todo.priority;
    _selectedRecurrence = widget.todo.recurrence; // Initialize recurrence
  }

  Future<void> _updateRecurrence(String? recurrence) async {
    try {
      await FirebaseFirestore.instance
          .collection('todos')
          .doc(widget.todo.id)
          .update({'recurrence': recurrence});

      if (recurrence != null && _selectedDueDate != null) {
        await NotificationHelper.scheduleNotification(
          id: widget.todo.id.hashCode,
          title: 'Reminder: ${widget.todo.text}',
          body: 'This is a reminder for your task.',
          scheduledTime: _selectedDueDate!,
          recurrence: recurrence,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recurrence updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update recurrence: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Todo'),
                  content: const Text('Are you sure you want to delete this todo?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await _delete();
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                border: UnderlineInputBorder(),
              ),
              onSubmitted: (newText) async {
                if (newText.isNotEmpty && newText != widget.todo.text) {
                  await _updateText(newText);
                }
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Priority'),
              subtitle: DropdownButton<String>(
                value: _selectedPriority,
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('! Low Priority')),
                  DropdownMenuItem(value: 'medium', child: Text('!! Medium Priority')),
                  DropdownMenuItem(value: 'high', child: Text('!!! High Priority')),
                ],
                onChanged: (value) async {
                  if (value != null && value != _selectedPriority) {
                    setState(() {
                      _selectedPriority = value;
                    });
                    await _updatePriority(value);
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Due Date'),
              subtitle: Text(_selectedDueDate?.toLocal().toString().split('.')[0] ?? 'No due date'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_selectedDueDate != null)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () async {
                        _updateDueDate(null);
                        setState(() {
                          _selectedDueDate = null;
                        });
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () async {
                      final selectedDate = await showDatePicker(
                        context: context,
                        initialDate: _selectedDueDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2050),
                      );
                      if (selectedDate == null) return;

                      final selectedTime = await showTimePicker(
                        context: context,
                        initialTime:
                            _selectedDueDate != null ? TimeOfDay.fromDateTime(_selectedDueDate!) : TimeOfDay.now(),
                      );
                      if (selectedTime == null) return;

                      final DateTime dueDate = DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        selectedTime.hour,
                        selectedTime.minute,
                      );

                      setState(() {
                        _selectedDueDate = dueDate;
                      });

                      await _updateDueDate(dueDate);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Recurrence'),
              subtitle: DropdownButton<String>(
                value: _selectedRecurrence,
                items: const [
                  DropdownMenuItem(value: null, child: Text('None')),
                  DropdownMenuItem(value: 'daily', child: Text('Daily')),
                  DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                ],
                onChanged: _selectedDueDate == null
                    ? null // Disable the dropdown if no due date is set
                    : (value) async {
                  setState(() {
                    _selectedRecurrence = value;
                  });
                  await _updateRecurrence(value);
                },
                disabledHint: const Text('Set a due date first'), // Hint when disabled
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete() async {
    try {
      await FirebaseFirestore.instance.collection('todos').doc(widget.todo.id).delete();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Todo deleted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete todo: $e')),
        );
      }
    }
  }

  Future<void> _updateText(String newText) async {
    try {
      await FirebaseFirestore.instance.collection('todos').doc(widget.todo.id).update({'text': newText});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Todo text updated!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update text: $e')),
      );
    }
  }

  Future<void> _updatePriority(String priority) async {
    try {
      await FirebaseFirestore.instance.collection('todos').doc(widget.todo.id).update({'priority': priority});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Priority updated!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update priority: $e')),
      );
    }
  }

  Future<void> _updateDueDate(DateTime? dueDate) async {
    try {
      await FirebaseFirestore.instance
          .collection('todos')
          .doc(widget.todo.id)
          .update({'dueAt': dueDate == null ? null : Timestamp.fromDate(dueDate)});

      // Reset recurrence to None if due date is removed
      if (dueDate == null) {
        setState(() {
          _selectedRecurrence = null;
        });
        await _updateRecurrence(null); // Update Firestore to reflect the change
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Due date updated!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update due date: $e')),
      );
    }
  }
}

