import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

import '../data/todo.dart';
import 'details/detail_screen.dart';
import 'filter/filter_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  FilterSheetResult _filters = FilterSheetResult(
    sortBy: 'date',
    order: 'descending',
    showOnlyCompleted: false,
  );

  late AudioPlayer _audioPlayer; // Use AudioPlayer for playing sounds
  List<Todo> _todos = [];
  List<Todo> _filteredTodos = [];
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _controller = TextEditingController();
  Set<String> _selectedTodoIds = {};
  bool _isSelectionMode = false;
  User? user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();

    // Initialize AudioPlayer
    _audioPlayer = AudioPlayer();

    FirebaseFirestore.instance
        .collection('todos')
        .where('uid', isEqualTo: user?.uid)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _todos = snapshot.docs.map((doc) => Todo.fromSnapshot(doc)).toList();
        _filteredTodos = filterTodos();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _controller.dispose();
    _audioPlayer.dispose(); // Dispose AudioPlayer
    super.dispose();
  }

  List<Todo> filterTodos() {
    return _todos.where((todo) {
      final matchesSearch = _searchController.text.isEmpty ||
          todo.text.toLowerCase().contains(_searchController.text.toLowerCase());

      final matchesArchive = (_filters.showOnlyCompleted && todo.completedAt != null) ||
          (!_filters.showOnlyCompleted && todo.completedAt == null);

      return matchesSearch && matchesArchive;
    }).toList()
      ..sort((a, b) {
        int comparison = 0;

        if (_filters.sortBy == 'priority') {
          final priorityMap = {'low': 1, 'medium': 2, 'high': 3};
          comparison = (priorityMap[a.priority] ?? 0).compareTo(priorityMap[b.priority] ?? 0);
        } else if (_filters.sortBy == 'completed') {
          comparison = (a.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(b.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0));
        } else if (_filters.sortBy == 'date') {
          comparison = (a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0));
        }

        return _filters.order == 'ascending' ? comparison : -comparison;
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelectionMode ? '${_selectedTodoIds.length} Selected' : 'WeDo'),
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isSelectionMode = false;
                  _selectedTodoIds.clear();
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                for (String id in _selectedTodoIds) {
                  await FirebaseFirestore.instance.collection('todos').doc(id).delete();
                }
                setState(() {
                  _isSelectionMode = false;
                  _selectedTodoIds.clear();
                  _filteredTodos = filterTodos();
                });
              },
            ),
          ],
          if (!_isSelectionMode) ...[
            Row(
              children: [
                Switch(
                  value: _filters.showOnlyCompleted,
                  onChanged: (value) {
                    setState(() {
                      _filters = FilterSheetResult(
                        sortBy: _filters.sortBy,
                        order: _filters.order,
                        showOnlyCompleted: value,
                      );
                      _filteredTodos = filterTodos();
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.info),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('About WeDo'),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                              ),
                            ],
                          ),
                          content: const Text(
                            'WeDo is a simple TODO app that helps you manage your tasks efficiently. Use the bottom bar to add a task, and edit its due date notifications and priority by clicking on it once it has appeared. Use the search bar and sorting functionality to explore your tasks. Click on the checkbox next to a task to complete it, and use the toggle on the top right to explore an archive of completed tasks. You can long-press on a task to enter a selection mode that lets you delete multiple tasks at once. Let\'s have fun getting things done!',
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ],
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isDesktop = constraints.maxWidth > 600;
          return Center(
            child: SizedBox(
              width: isDesktop ? 600 : double.infinity,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        labelText: 'Search TODOs',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.filter_list),
                          onPressed: () async {
                            final result = await showModalBottomSheet<FilterSheetResult>(
                              context: context,
                              builder: (context) {
                                return FilterSheet(initialFilters: _filters);
                              },
                            );

                            if (result != null) {
                              setState(() {
                                _filters = result;
                                _filteredTodos = filterTodos();
                              });
                            }
                          },
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _filteredTodos = filterTodos();
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _filteredTodos?.isEmpty ?? true
                        ? const Center(child: Text('No TODOs found'))
                        : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      itemCount: _filteredTodos?.length ?? 0,
                      itemBuilder: (context, index) {
                        final todo = _filteredTodos?[index];
                        if (todo == null) return const SizedBox.shrink();

                        final isSelected = _selectedTodoIds.contains(todo.id);

                        return Container(
                          decoration: BoxDecoration(
                            border: isSelected
                                ? Border.all(color: Colors.blue, width: 2.0)
                                : null,
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: ListTile(
                            tileColor: todo.priority == 'low'
                                ? Colors.green[100]
                                : todo.priority == 'medium'
                                ? Colors.yellow[100]
                                : Colors.red[100],
                            leading: Checkbox(
                              value: todo.completedAt != null,
                              onChanged: (bool? value) async {
                                final updateData = {
                                  'completedAt': value == true
                                      ? FieldValue.serverTimestamp()
                                      : null
                                };
                                await FirebaseFirestore.instance
                                    .collection('todos')
                                    .doc(todo.id)
                                    .update(updateData);

                                // Play the sound using AudioPlayer
                                if (value == true) {
                                  await _audioPlayer.stop();
                                  await _audioPlayer.play(AssetSource('sounds/ding2.mp3'));
                                }
                              },
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            title: Text(
                              todo.text,
                              style: todo.completedAt != null
                                  ? const TextStyle(decoration: TextDecoration.lineThrough)
                                  : null,
                            ),
                            onTap: _isSelectionMode
                                ? () {
                              setState(() {
                                if (isSelected) {
                                  _selectedTodoIds.remove(todo.id);
                                } else {
                                  _selectedTodoIds.add(todo.id);
                                }
                              });
                            }
                                : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DetailScreen(todo: todo),
                                ),
                              );
                            },
                            onLongPress: () {
                              setState(() {
                                _isSelectionMode = true;
                                _selectedTodoIds.add(todo.id);
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    color: Colors.green[100],
                    padding: const EdgeInsets.all(32.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            keyboardType: TextInputType.text,
                            controller: _controller,
                            decoration: const InputDecoration(
                              labelText: 'Enter Task:',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            if (user != null && _controller.text.isNotEmpty) {
                              await FirebaseFirestore.instance.collection('todos').add({
                                'text': _controller.text,
                                'createdAt': FieldValue.serverTimestamp(),
                                'uid': user?.uid,
                                'priority': 'low',
                              });
                              _controller.clear();
                            }
                          },
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}