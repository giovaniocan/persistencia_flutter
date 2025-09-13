import 'package:exemplo/screens/pessoas_page.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show sqfliteFfiInit, databaseFactoryFfi;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart'
    show databaseFactoryFfiWeb;

// O main.dart agora está mais simples, como você pediu.
// Apenas inicializa as dependências do sqflite por plataforma.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
