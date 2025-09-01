class Note {
  final String id;       // UUID local (ou docId remoto)
  final String title;
  final DateTime createdAt;

  Note({required this.id, required this.title, required this.createdAt});

  // ---- SQLite ----
  Map<String, Object?> toSqlMap() => {
    'id': id,
    'title': title,
    'created_at': createdAt.toIso8601String(),
  };

  factory Note.fromSqlMap(Map<String, Object?> map) => Note(
    id: map['id'] as String,
    title: map['title'] as String,
    createdAt: DateTime.parse(map['created_at'] as String),
  );

  // ---- Firestore ----
  Map<String, Object?> toJson() => {
    'title': title,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Note.fromFirestore(String docId, Map<String, Object?> json) => Note(
    id: docId,
    title: json['title'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}