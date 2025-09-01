import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'note.dart';
import 'local_db.dart';
import 'remote_db.dart';
import 'repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await LocalDb().init();
  runApp(const NotesApp());
}

class NotesApp extends StatelessWidget {
  const NotesApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notas: SQLite + Firestore',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const NotesPage(),
    );
  }
}

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});
  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  late final NoteRepository repo;
  final _controller = TextEditingController();
  List<Note> _notes = [];

  @override
  void initState() {
    super.initState();
    repo = NoteRepository(LocalDb(), RemoteDb());
    _loadLocal();
  }

  Future<void> _loadLocal() async {
    final items = await repo.loadLocal();
    setState(() => _notes = items);
  }

  Future<void> _addNote() async {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    final note = Note(
      id: _uuidLike(),
      title: title,
      createdAt: DateTime.now(),
    );
    await repo.save(note);
    _controller.clear();
    await _loadLocal();
  }

  Future<void> _syncFromRemote() async {
    await repo.syncFromRemote();
    await _loadLocal();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sincronizado do Firestore → SQLite')),
      );
    }
  }

  String _uuidLike() {
    // bem simples p/ demo. Na prática, use package 'uuid'.
    final r = Random();
    return List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notas (SQLite + Firestore)'),
        actions: [
          IconButton(
            onPressed: _syncFromRemote,
            tooltip: 'Puxar do Firestore',
            icon: const Icon(Icons.cloud_download),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'Título da nota',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addNote(),
                  ),
                ),
                SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _addNote,
                  icon: const Icon(Icons.add),
                  label: const Text('Salvar'),
                ),
              ],
            ),
          ),
          const Divider(height: 0),
          Expanded(
            child: _notes.isEmpty
                ? const Center(child: Text('Sem notas ainda'))
                : ListView.separated(
                    itemCount: _notes.length,
                    separatorBuilder: (_, __) => const Divider(height: 0),
                    itemBuilder: (context, i) {
                      final n = _notes[i];
                      return ListTile(
                        leading: const Icon(Icons.note),
                        title: Text(n.title),
                        subtitle: Text(n.createdAt.toIso8601String()),
                        dense: true,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}