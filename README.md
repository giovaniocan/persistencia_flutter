# Notes Persist — SQLite + Firebase (Firestore)

Projeto exemplo mínimo de Flutter que salva notas localmente (SQLite) e remotamente (Firestore).

## Requisitos
- Flutter 3.22+
- Conta Firebase
- Android minSdkVersion 23

## Passo a passo
1. **Clone/extraia** este projeto.
2. **Instale dependências**:
   ```bash
   flutter pub get
   ```
3. **Configure Firebase** (uma única vez):
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   Isso criará `lib/firebase_options.dart`. (O arquivo aqui é um *placeholder* — substitua pelo gerado.)
4. **Android minSdk**: ajuste para 23 em `android/app/build.gradle` se necessário.
5. **Executar**:
   ```bash
   flutter run
   ```

### Desktop (Windows/macOS/Linux)
- Descomente `sqflite_common_ffi` e `sqlite3_flutter_libs` no `pubspec.yaml`.
- No `lib/local_db.dart`, descomente as linhas marcadas para inicializar o FFI.

## Estrutura
```
lib/
  main.dart
  note.dart
  local_db.dart
  remote_db.dart
  repository.dart
  firebase_options.dart   # substitua pelo arquivo gerado pelo flutterfire
pubspec.yaml
```

## Como funciona
- **Salvar**: insere no SQLite e tenta replicar no Firestore (com o mesmo `id`).
- **Sincronizar**: botão na AppBar puxa do Firestore e espelha no SQLite.

## Trocar a entidade
Se quiser trocar `Note` por outra entidade (ex.: `Task`, `Student`, `Order`), renomeie o model e ajuste os campos nos métodos `toSqlMap()/fromSqlMap()` e `toJson()/fromFirestore()`.

---

MIT © Jefferson Rodrigo Speck