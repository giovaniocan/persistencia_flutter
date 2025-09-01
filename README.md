# Persistência de Dados Local no Flutter (SQLite) — Guia Completo

Este README explica **passo a passo** como construir um app Flutter com **persistência local** usando **SQLite**, incluindo:
- arquitetura do projeto,
- por que usar `SQLite` e quando usar outras opções,
- detalhes de **todas as classes e métodos** do exemplo,
- como funciona o **Singleton** do banco,
- execução em **Android/iOS**, **Desktop (Windows/macOS/Linux)** e **Web (IndexedDB via WASM)**,
- solução de erros comuns (inclusive os que você encontrou).

> **Projeto exemplo:** CRUD de `Pessoa (id, nome, idade)` com uma única tela (formulário + lista).  
> **Banco:** `meu_banco.db`, tabela `pessoas`.

---

## Sumário
1. [Por que SQLite?](#por-que-sqlite)
2. [Dependências & versões](#dependências--versões)
3. [Estrutura do projeto](#estrutura-do-projeto)
4. [Modelo `Pessoa`](#modelo-pessoa)
5. [Camada de Acesso a Dados](#camada-de-acesso-a-dados)
   - [Padrão Singleton: por que e como](#padrão-singleton-por-que-e-como)
   - [`DatabaseHelper`: atributos e métodos](#databasehelper-atributos-e-métodos)
6. [Inicialização por plataforma (Mobile/Desktop/Web)](#inicialização-por-plataforma-mobiledesktopweb)
7. [Tela (UI) — CRUD](#tela-ui--crud)
8. [Execução (Android/iOS, Desktop, Web)](#execução-androidios-desktop-web)
9. [Migrações de banco (onUpgrade)](#migrações-de-banco-onupgrade)
10. [Desempenho & Boas práticas](#desempenho--boas-práticas)
11. [Erros comuns & Soluções](#erros-comuns--soluções)
12. [Extensões & Próximos passos](#extensões--próximos-passos)

---

## Por que SQLite?

**SQLite** é ideal quando você precisa de:
- **estrutura de dados mais complexa** do que chave-valor simples;
- **consultas** (filtrar, ordenar, paginar, JOINs simples);
- **persistência offline** confiável e relacional, sem depender de rede;
- controle total sobre o **schema** (DDL) e **transações**.

Alternativas:
- **SharedPreferences**: chave-valor, ótimo para preferências simples (tema, flags).
- **Hive**: banco NoSQL rápido e fácil de usar; ótimo para objetos simples/velozes sem SQL.
- **Isar/Drift**: opções mais avançadas/ergonômicas dependendo do caso de uso.

---

## Dependências & versões

No `pubspec.yaml` (exemplo usado neste projeto):

```yaml
dependencies:
  flutter:
    sdk: flutter

  # SQL
  sqflite: ^2.3.0

  # Paths
  path: ^1.9.0

  # Suporte extra por plataforma
  sqflite_common_ffi: ^2.3.3          # Desktop (Windows/Linux/macOS)
  sqflite_common_ffi_web: ^1.0.1      # Web (IndexedDB via WASM)
```

> Observação: você **não precisa** de `path_provider` para este exemplo específico, pois usamos `getDatabasesPath()` do `sqflite` em mobile/desktop e **IndexedDB** no Web (sem caminho). Se quiser armazenar o DB em outra pasta, aí sim `path_provider` pode ser útil.

---

## Estrutura do projeto

```
lib/
  main.dart            # App completo (modelo, helper, UI)
web/
  index.html           # Deve conter <base href="/">
  sqlite3.wasm         # (Web) binário do SQLite WASM
  sqflite_sw.js        # (Web) shared worker do sqflite
```

> No Web, é **obrigatório** ter `sqlite3.wasm` e `sqflite_sw.js` em `web/`.  
> Como obter: `dart run sqflite_common_ffi_web:setup` (precisa do `git` no PATH) **ou** copie manualmente do cache do Pub.

---

## Modelo `Pessoa`

```dart
class Pessoa {
  final int? id;        // id opcional (gerado pelo SQLite via AUTOINCREMENT)
  final String nome;
  final int idade;

  const Pessoa({this.id, required this.nome, required this.idade});

  Pessoa copyWith({int? id, String? nome, int? idade}) => Pessoa(
        id: id ?? this.id,
        nome: nome ?? this.nome,
        idade: idade ?? this.idade,
      );

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{'nome': nome, 'idade': idade};
    if (id != null) map['id'] = id; // não envia se for null (para INSERT)
    return map;
  }

  factory Pessoa.fromMap(Map<String, dynamic> map) => Pessoa(
        id: map['id'] as int?,
        nome: map['nome'] as String,
        idade: (map['idade'] as num).toInt(),
      );
}
```

**Por que `id` é opcional?**  
Para permitir `AUTOINCREMENT` no SQLite. Você insere sem `id` e o banco gera.

---

## Camada de Acesso a Dados

### Padrão Singleton: por que e como?

- Queremos **uma única instância** do banco de dados durante o ciclo de vida do app.
- Evita abrir/fechar conexões repetidamente, melhora performance e reduz bugs de concorrência.
- Implementação: **construtor privado**, **instância estática**, **inicialização tardia (lazy)**.

### `DatabaseHelper`: atributos e métodos

#### Atributos
- `_dbName`: nome do arquivo do banco (`meu_banco.db`).  
- `_table`: nome da tabela (`pessoas`).  
- `_db`: instância `Database` (cacheada após abrir).  
- `instance`: instância Singleton (`DatabaseHelper._internal()`).

#### Métodos principais
- `Future<Database> get database`  
  - Retorna o `Database` aberto; abre uma vez com `_initDB()` e **reusa** nas próximas chamadas.
- `_initDB()`  
  - Mobile/Desktop: cria/abre banco em `getDatabasesPath()` + `join`.  
  - Web: **não usa path**; abre por nome usando `databaseFactoryFfiWeb` e armazena em **IndexedDB**.  
  - Define `onCreate` com a DDL da tabela.
- `insert(Pessoa)` / `getById(int)` / `getAll()` / `update(Pessoa)` / `delete(int)`  
  - CRUD completo, usando helpers do `sqflite` (`insert`, `query`, `update`, `delete`).

---

## Inicialização por plataforma (Mobile/Desktop/Web)

No `main()`:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    // Web -> IndexedDB + WASM/Worker
    databaseFactory = databaseFactoryFfiWeb;
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // Desktop -> FFI nativo
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const PessoasApp());
}
```

- **Web**: usa `databaseFactoryFfiWeb` (WASM).  
- **Desktop**: inicializa FFI (`sqfliteFfiInit`) e troca `databaseFactory`.  
- **Android/iOS**: `sqflite` já se configura sozinho (nada extra necessário).

> **Importante no Web:** garanta `web/sqlite3.wasm` e `web/sqflite_sw.js`.  
> Dica: `dart run sqflite_common_ffi_web:setup --force`

---

## Tela (UI) — CRUD

A tela `PessoasPage` mantém:
- Formulário com `TextFormField` para `nome` e `idade` (validação incluída).
- Botões **Adicionar/Salvar** (editando se `_editingId != null`) e **Cancelar edição**.
- Lista com `Dismissible` para apagar e `onTap` para editar.
- Mecanismo para **recarregar a lista** sem “travar” a UI: `FutureBuilder` + `_reloadTick`.

### Por que `_reloadTick`?
O `FutureBuilder` às vezes “recicla” o mesmo Future já concluído (especialmente no Web).  
Ao mudar a **key** (`ValueKey(_reloadTick)`) a cada `_refresh()`, garantimos o `rebuild`.

### Trecho essencial da UI (lista)
```dart
Expanded(
  child: FutureBuilder<List<Pessoa>>(
    key: ValueKey(_reloadTick),
    future: _futurePessoas,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(child: Text('Erro: ${snapshot.error}'));
      }
      final pessoas = snapshot.data ?? const <Pessoa>[];
      if (pessoas.isEmpty) {
        return const Center(child: Text('Nenhuma pessoa cadastrada.'));
      }
      return ListView.separated(
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
```

### UX e estabilidade
- **Evitar duplo submit**: flag `_isSaving` para **desabilitar** botão enquanto salva.
- **Limpar formulário**: `clear()` nos controllers + `unfocus()` + `setState` para atualizar o botão.
- **SnackBars**: use **`ScaffoldMessenger.of(context)`** (sem casts).

---

## Execução (Android/iOS, Desktop, Web)

### 1) Android/iOS
```bash
flutter pub get
flutter run -d emulator-5554   # Android (exemplo)
flutter run -d ios             # iOS (Xcode/config necessários)
```

### 2) Desktop
Ative o desktop se necessário:
```bash
flutter config --enable-windows-desktop
flutter config --enable-macos-desktop
flutter config --enable-linux-desktop
```
Rode:
```bash
flutter run -d windows   # ou -d macos / -d linux
```

### 3) Web (Chrome/Edge/Firefox)

**Arquivos obrigatórios em `web/`:**
- `sqlite3.wasm`
- `sqflite_sw.js`

**Formas de obter:**
- Automática (requer Git no PATH):
  ```bash
  dart run sqflite_common_ffi_web:setup --force
  ```
- Manual: copiar do cache do Pub para `web/`.

**Rode:**
```bash
flutter run -d chrome
# Em caso de cache do navegador, rode com perfil limpo:
flutter run -d chrome --web-browser-flag="--user-data-dir=C:\temp\flutter_chrome"
```

**Dicas Web:**
- Use sempre a mesma **porta** ao depurar (IndexedDB é por origem+porta).
- Se já quebrou antes, limpe: DevTools (F12) → Application → Clear storage → *Clear site data*.

---

## Migrações de banco (`onUpgrade`)

Quando mudar o schema, **aumente** a `version` e implemente `onUpgrade`:
```dart
openDatabase(
  path,
  version: 2,
  onCreate: _onCreate,
  onUpgrade: (db, oldV, newV) async {
    if (oldV < 2) {
      await db.execute('ALTER TABLE pessoas ADD COLUMN email TEXT');
    }
  },
);
```

> **Nunca** diminua a versão; crie passos incrementais. Evite `DROP TABLE` sem backup.

---

## Desempenho & Boas práticas

- **Batches/Transações**: agrupe múltiplos `INSERT/UPDATE/DELETE`:
  ```dart
  await db.transaction((txn) async {
    final batch = txn.batch();
    // batch.insert(...)
    // batch.update(...)
    await batch.commit(noResult: true);
  });
  ```
- **Índices**: crie índices para colunas muito filtradas/ordenadas.
- **Evite bloquear a UI**: nunca use operações síncronas pesadas no build.
- **Conflitos**: escolha `conflictAlgorithm` adequado (`replace`, `abort`, etc.).

---

## Erros comuns & Soluções

**1) `Context` não é `BuildContext`**  
Conflito com `package:path/path.dart`:
```dart
import 'package:path/path.dart' as p;   // use alias
final path = p.join(dbDir, _dbName);    // e use p.join(...)
```

**2) Web: `SqfliteFfiWebException()` / 404 em `sqlite3.wasm`**  
Faltam os arquivos em `web/`. Rode o setup ou copie manualmente.

**3) “This app is linked to the debug service...” e não atualiza lista**  
`FutureBuilder` reciclando o `Future`. Use `key: ValueKey(_reloadTick)` ao atualizar.

**4) Travou ao inserir / dois SnackBars**  
Duplo submit (Enter + clique). Use `_isSaving` para desabilitar o botão e ignore submissões enquanto salva.

**5) Flutter não consegue apagar `.plugin_symlinks` (Windows)**  
Feche IDE/terminais que seguram a pasta. Se só vai rodar Web, pode desabilitar desktop temporariamente:
```bash
flutter config --no-enable-windows-desktop
```
Depois `flutter clean` e `flutter pub get`.

**6) `Target of URI doesn't exist: path_provider`**  
Se não usa `path_provider`, remova o import/dep. Caso use, adicione no `pubspec.yaml` e rode `flutter pub get`.

---

## Extensões & Próximos passos

- **DAO/Repository**: separe interfaces para facilitar testes/mocks e camadas.  
- **Filtros/Busca**: crie métodos com `where`/`whereArgs`.  
- **Paginação**: use `limit`/`offset` no `query`.  
- **Sincronização remota**: combine com uma fonte remota (ex.: Firestore/REST) e reconcilie mudanças.  
- **Validações avançadas**: checagens de duplicidade, constraints únicas etc.

---