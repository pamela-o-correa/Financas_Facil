import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Canal sqflite com SQLite real em memória, sem acesso a bancos do usuário.
class SQLiteReal {
  SQLiteReal._(this._processo, this._linhas);
  final Process _processo;
  final StreamIterator<String> _linhas;
  String? falharSql;
  static const _canal = MethodChannel('com.tekartik.sqflite');

  static Future<SQLiteReal> abrir() async {
    final processo = await Process.start(
      Platform.environment['VALIDACAO_PYTHON'] ?? 'python',
      ['test/sqlite_bridge.py'],
    );
    // Evita bloqueio se o interpretador emitir mensagens de diagnóstico.
    unawaited(processo.stderr.drain<void>());
    final ponte = SQLiteReal._(
      processo,
      StreamIterator(
        processo.stdout.transform(utf8.decoder).transform(const LineSplitter()),
      ),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_canal, ponte._chamar);
    return ponte;
  }

  Future<Object?> _chamar(MethodCall call) async {
    if (call.method == 'getDatabasesPath') return Directory.systemTemp.path;
    if (call.method == 'openDatabase') return {'id': 1};
    if (call.method == 'closeDatabase') return null;
    final args = Map<String, dynamic>.from(call.arguments as Map);
    if (falharSql != null &&
        (args['sql'] as String? ?? '').contains(falharSql!)) {
      throw PlatformException(
        code: 'sqlite_error',
        message: 'Falha simulada de migração',
      );
    }
    _processo.stdin.writeln(jsonEncode({...args, 'method': call.method}));
    await _processo.stdin.flush();
    if (!await _linhas.moveNext()) throw StateError('SQLite finalizado');
    final resposta = jsonDecode(_linhas.current) as Map;
    if (resposta.containsKey('error')) {
      throw PlatformException(
        code: 'sqlite_error',
        message: resposta['error'] as String,
      );
    }
    return resposta['result'];
  }

  Future<void> fechar() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_canal, null);
    await _linhas.cancel();
    await _processo.stdin.close();
    await _processo.exitCode.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _processo.kill();
        return -1;
      },
    );
  }
}
