import 'note.dart';
import 'local_db.dart';
import 'remote_db.dart';

class NoteRepository {
  final LocalDb _local;
  final RemoteDb _remote;

  NoteRepository(this._local, this._remote);

  /// Salva local e tenta salvar remoto. Se falhar remoto, mantém local.
  Future<void> save(Note note) async {
    await _local.insertNote(note);
    try {
      await _remote.add(note);
    } catch (_) {
      // você pode logar/encostar num "outbox" aqui para sincronizar depois
    }
  }

  Future<List<Note>> loadLocal() => _local.getAll();

  /// Exemplo de "pull" do remoto e grava localmente (espelha)
  Future<void> syncFromRemote() async {
    final remote = await _remote.getAll();
    for (final n in remote) {
      await _local.insertNote(n);
    }
  }
}