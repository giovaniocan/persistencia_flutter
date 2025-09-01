Claro, aqui está um guia sobre como fazer uma aula de persistência de dados local no Flutter.

### Visão geral da aula

A aula abordará o básico da persistência de dados local no Flutter, usando um banco de dados **SQLite**. A principal biblioteca para isso é a **`sqflite`**, mas também exploraremos o **`path_provider`** para encontrar o caminho correto para o banco de dados no dispositivo.

-----

### Tópicos da aula

#### 1\. Introdução à persistência de dados

  * O que é persistência de dados?
  * Por que é importante salvar dados localmente?
  * Tipos de armazenamento local no Flutter (SharedPreferences, Hive, SQLite).
  * Por que escolher o SQLite para este exemplo? (Estrutura de dados complexa, consultas).

#### 2\. Configuração do projeto

  * Adicionar as dependências no arquivo `pubspec.yaml`:

      * **`sqflite`**: A biblioteca principal para interagir com o SQLite.
      * **`path_provider`**: Essencial para obter o caminho do banco de dados no sistema de arquivos do dispositivo.

    <!-- end list -->

    ```yaml
    dependencies:
      flutter:
        sdk: flutter
      sqflite: ^2.3.0
      path_provider: ^2.1.1
    ```

  * Rodar `flutter pub get` no terminal para baixar as dependências.

#### 3\. Criação do modelo de dados

  * Definir uma classe em Dart que represente o objeto que você quer salvar (ex: `Pessoa`, `Produto`).

  * A classe deve ter um construtor e um método `toMap()` para converter o objeto em um `Map` (formato necessário para o banco de dados) e um construtor `fromMap()` para criar um objeto a partir de um `Map`.

    ```dart
    class Pessoa {
      final int id;
      final String nome;
      final int idade;

      Pessoa({required this.id, required this.nome, required this.idade});

      Map<String, dynamic> toMap() {
        return {
          'id': id,
          'nome': nome,
          'idade': idade,
        };
      }

      factory Pessoa.fromMap(Map<String, dynamic> map) {
        return Pessoa(
          id: map['id'],
          nome: map['nome'],
          idade: map['idade'],
        );
      }
    }
    ```

#### 4\. Criando a classe de banco de dados

  * Crie uma classe responsável por gerenciar o banco de dados (abrir, criar tabelas, inserir, buscar, atualizar e deletar).

  * Use `getDatabasesPath()` do **`path_provider`** para encontrar o caminho e `openDatabase()` do **`sqflite`** para abrir ou criar o banco.

  * No método `onCreate` do `openDatabase`, defina o comando SQL para criar a tabela.

    ```dart
    import 'package:sqflite/sqflite.dart';
    import 'package:path/path.dart';

    class DatabaseHelper {
      static Database? _database;
      static const String _tableName = 'pessoas';

      Future<Database> get database async {
        if (_database != null) return _database!;
        _database = await _initDB();
        return _database!;
      }

      Future<Database> _initDB() async {
        final databasePath = await getDatabasesPath();
        final path = join(databasePath, 'meu_banco.db');

        return await openDatabase(
          path,
          version: 1,
          onCreate: (db, version) {
            return db.execute(
              "CREATE TABLE $_tableName(id INTEGER PRIMARY KEY, nome TEXT, idade INTEGER)",
            );
          },
        );
      }
    }
    ```

#### 5\. Implementando as operações CRUD

  * Adicione métodos na classe **`DatabaseHelper`** para as operações:

      * **`insert(Pessoa pessoa)`**: Insere um novo objeto no banco de dados.
      * **`getById(int id)`**: Busca um objeto específico pelo ID.
      * **`getAll()`**: Retorna uma lista de todos os objetos na tabela.
      * **`update(Pessoa pessoa)`**: Atualiza um objeto existente.
      * **`delete(int id)`**: Remove um objeto pelo ID.

    <!-- end list -->

    ```dart
    // Exemplo de método de inserção
    Future<int> insert(Pessoa pessoa) async {
      final db = await database;
      return await db.insert(
        _tableName,
        pessoa.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // Exemplo de método para buscar todos
    Future<List<Pessoa>> getAll() async {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(_tableName);
      return List.generate(maps.length, (i) {
        return Pessoa.fromMap(maps[i]);
      });
    }
    ```

#### 6\. Construindo a UI (Tela)

  * Crie uma tela com `TextField`s para o usuário inserir os dados (nome e idade).
  * Adicione um botão "Salvar".
  * Ao clicar no botão, instancie o objeto `Pessoa` com os dados da tela e chame o método `insert()` da classe **`DatabaseHelper`**.
  * Use um `FutureBuilder` para carregar e exibir a lista de pessoas salvas na tela.

-----