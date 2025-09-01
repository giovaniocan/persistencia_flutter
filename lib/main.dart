import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

import 'package:sqflite_common_ffi/sqflite_ffi.dart' show sqfliteFfiInit, databaseFactoryFfi;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart' show databaseFactoryFfiWeb;

// ---------------------------
// 1) MODELO
// ---------------------------
class Pessoa {
  final int? id; // id opcional para permitir AUTOINCREMENT
  final String nome;
  final int idade;

  const Pessoa({this.id, required this.nome, required this.idade});

  Pessoa copyWith({int? id, String? nome, int? idade}) {
    return Pessoa(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      idade: idade ?? this.idade,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'nome': nome,
      'idade': idade,
    };
    if (id != null) map['id'] = id; // só inclui se existir
    return map;
  }

  factory Pessoa.fromMap(Map<String, dynamic> map) {
    return Pessoa(
      id: map['id'] as int?,
      nome: map['nome'] as String,
      idade: (map['idade'] as num).toInt(),
    );
  }

  @override
  String toString() => 'Pessoa(id: $id, nome: $nome, idade: $idade)';
}

// ---------------------------
// 2) DATABASE HELPER (Singleton)
// ---------------------------
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const String _dbName = 'meu_banco.db';
  static const String _table = 'pessoas';

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

Future<Database> _initDB() async {
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_table(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        idade INTEGER NOT NULL
      )
    ''');
  }

  if (kIsWeb) {
    // Web: usar apenas o NOME do banco (IndexedDB). Sem paths.
    return await databaseFactory.openDatabase(
      _dbName, // ex.: "meu_banco.db"
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: _onCreate,
      ),
    );
  } else {
    // Android/iOS/desktop: usar caminho em getDatabasesPath()
    final dbDir = await getDatabasesPath();
    final path = p.join(dbDir, _dbName);
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }
}

  // CREATE
  Future<int> insert(Pessoa p) async {
    final db = await database;
    return db.insert(_table, p.toMap(), conflictAlgorithm: ConflictAlgorithm.abort);
  }

  // READ by id
  Future<Pessoa?> getById(int id) async {
    final db = await database;
    final result = await db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
    if (result.isEmpty) return null;
    return Pessoa.fromMap(result.first);
  }

  // READ all
  Future<List<Pessoa>> getAll() async {
    final db = await database;
    final maps = await db.query(_table, orderBy: 'id DESC');
    return maps.map((m) => Pessoa.fromMap(m)).toList();
  }

  // UPDATE
  Future<int> update(Pessoa p) async {
    if (p.id == null) return 0;
    final db = await database;
    return db.update(_table, p.toMap(), where: 'id = ?', whereArgs: [p.id]);
  }

  // DELETE
  Future<int> delete(int id) async {
    final db = await database;
    return db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}

// ---------------------------
// 3) APP
// ---------------------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialização específica para cada plataforma
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  runApp(const PessoasApp());
}

class PessoasApp extends StatelessWidget {
  const PessoasApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Persistência Local (SQLite)',
      theme: ThemeData(useMaterial3: true),
      home: const PessoasPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ---------------------------
// 4) UI (CRUD)
// ---------------------------
class PessoasPage extends StatefulWidget {
  const PessoasPage({super.key});

  @override
  State<PessoasPage> createState() => _PessoasPageState();
}

class _PessoasPageState extends State<PessoasPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _idadeCtrl = TextEditingController();

  int? _editingId; // se != null, estamos editando
  late Future<List<Pessoa>> _futurePessoas;
  bool _isSaving = false;
  int _reloadTick = 0; // <--- NOVO  

  @override
  void initState() {
    super.initState();
    _futurePessoas = DatabaseHelper.instance.getAll();
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _idadeCtrl.dispose();
    super.dispose();
  }

  void _limparFormulario() {
    _formKey.currentState?.reset();
    _nomeCtrl.clear();
    _idadeCtrl.clear();
    _editingId = null;

    // desfoca teclado (especialmente no Web)
    FocusScope.of(context).unfocus();

    // avisa a UI que mudou (para atualizar botão/estado)
    setState(() {});
  }

  Future<void> _refresh() async {
    setState(() {
      _futurePessoas = DatabaseHelper.instance.getAll();
      _reloadTick++; // muda a key e força rebuild do FutureBuilder
    });
  }

  Future<void> _salvar() async {
    if (_isSaving) return;             // evita duplo clique / enter+clique
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);
    try {
      final nome = _nomeCtrl.text.trim();
      final idade = int.parse(_idadeCtrl.text.trim());

      if (_editingId == null) {
        await DatabaseHelper.instance.insert(Pessoa(nome: nome, idade: idade));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pessoa adicionada!')),
        );
      } else {
        await DatabaseHelper.instance.update(
          Pessoa(id: _editingId, nome: nome, idade: idade),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pessoa atualizada!')),
        );
      }

      _limparFormulario();
      // deixa a UI respirar, e o FutureBuilder atualiza assim que o Future completar
      _refresh();                   // dispara o FutureBuilder atualizar
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _apagar(int id) async {
    await DatabaseHelper.instance.delete(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pessoa removida.')),
    );
    await _refresh();
  }

  void _carregarParaEdicao(Pessoa p) {
    setState(() {
      _editingId = p.id;
      _nomeCtrl.text = p.nome;
      _idadeCtrl.text = p.idade.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _editingId != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pessoas (SQLite)'),
        actions: [
          IconButton(
            tooltip: 'Recarregar',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ---------------------------
            // Formulário
            // ---------------------------
            Padding(
              padding: const EdgeInsets.all(12),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nomeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nome',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Informe o nome';
                        }
                        if (v.trim().length < 2) {
                          return 'Nome muito curto';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _idadeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Idade',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Informe a idade';
                        }
                        final n = int.tryParse(v.trim());
                        if (n == null || n < 0 || n > 150) {
                          return 'Idade inválida';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) {
                        if (!_isSaving) _salvar();
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _salvar,
                            icon: _isSaving ? const SizedBox(
                              width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2),
                            ) : Icon(isEditing ? Icons.save : Icons.add),
                            label: Text(isEditing ? 'Salvar alterações' : 'Adicionar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (isEditing)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _limparFormulario,
                              icon: const Icon(Icons.close),
                              label: const Text('Cancelar edição'),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            // ---------------------------
            // Lista
            // ---------------------------
            Expanded(
              child: FutureBuilder<List<Pessoa>>(
                key: ValueKey(_reloadTick), // <- força rebuild quando _reloadTick muda                
                future: _futurePessoas,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ));
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Erro: ${snapshot.error}'));
                  }
                  final pessoas = snapshot.data ?? const <Pessoa>[];
                  if (pessoas.isEmpty) {
                    return const Center(child: Text('Nenhuma pessoa cadastrada.'));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: pessoas.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final p = pessoas[index];
                      return Dismissible(
                        key: ValueKey(p.id ?? '${p.nome}-${p.idade}-$index'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          color: Colors.red,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (_) async {
                          return await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Remover registro'),
                                  content: Text('Deseja remover ${p.nome}?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Cancelar'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Remover'),
                                    ),
                                  ],
                                ),
                              ) ??
                              false;
                        },
                        onDismissed: (_) => _apagar(p.id!),
                        child: ListTile(
                          tileColor: Colors.grey.withValues(alpha: 0.06),
                          title: Text('${p.nome} (${p.idade})'),
                          subtitle: Text('ID: ${p.id ?? '-'}'),
                          onTap: () => _carregarParaEdicao(p),
                          trailing: IconButton(
                            tooltip: 'Editar',
                            icon: const Icon(Icons.edit),
                            onPressed: () => _carregarParaEdicao(p),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
