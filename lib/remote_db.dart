import 'package:cloud_firestore/cloud_firestore.dart';
import 'note.dart';

class RemoteDb {
  final _col = FirebaseFirestore.instance.collection('notes');

  Future<void> add(Note note) async {
    // usa id como docId (útil p/ conciliar local-remoto)
    await _col.doc(note.id).set(note.toJson(), SetOptions(merge: true));
  }

  Future<List<Note>> getAll() async {
    final snap = await _col.orderBy('createdAt', descending: true).get();
    return snap.docs
        .map((d) => Note.fromFirestore(d.id, Map<String, Object?>.from(d.data())))
        .toList();
  }
}