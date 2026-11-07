part of 'main.dart';

/// Resumo apenas visual: a descrição original continua salva e pesquisável.
String resumirDescricao(String original) {
  final texto = original.trim().replaceAll(RegExp(r'\s+'), ' ');
  final pix = RegExp(
    r'^Transfer[eê]ncia (enviada|recebida) pelo Pix\s*-\s*(.+)',
    caseSensitive: false,
  ).firstMatch(texto);
  if (pix != null) {
    final nome = pix.group(2)!.split(RegExp(r'\s+-\s+')).first.trim();
    return '${pix.group(1)!.toLowerCase() == 'enviada' ? 'Pix para' : 'Pix de'} $nome';
  }
  final compra = RegExp(
    r'^Compra no d[eé]bito(?: via [^-]+)?\s*-\s*(.+)',
    caseSensitive: false,
  ).firstMatch(texto);
  return compra?.group(1)?.trim() ?? (texto.isEmpty ? 'Movimentação' : texto);
}

class AlteracaoHistorico {
  AlteracaoHistorico._(
    this.db,
    this.antes,
    this.depois,
    this.agendaAntes,
    this.agendaDepois,
  );
  final Database db;
  final Map<int, Map<String, Object?>?> antes,
      depois,
      agendaAntes,
      agendaDepois;
  bool _desfeita = false;
  List<int> _lixeiraIds = [];

  static Future<Map<int, Map<String, Object?>?>> _ler(
    DatabaseExecutor db,
    String tabela,
    Iterable<int> ids,
  ) async {
    final resultado = <int, Map<String, Object?>?>{};
    for (final id in ids) {
      final linhas = await db.query(tabela, where: 'id = ?', whereArgs: [id]);
      resultado[id] = linhas.isEmpty ? null : Map.of(linhas.single);
    }
    return resultado;
  }

  static Future<AlteracaoHistorico> executar(
    Database db,
    Set<int> ids, {
    bool? ativa,
    Categoria? categoria,
    bool excluir = false,
  }) async {
    if (ids.isEmpty ||
        [ativa != null, categoria != null, excluir].where((v) => v).length !=
            1) {
      throw StateError('Selecione uma ação e ao menos uma movimentação.');
    }
    return db.transaction((txn) async {
      final originais = await _ler(txn, 'movimentacoes', ids);
      if (originais.values.any((m) => m == null)) {
        throw StateError('A lista mudou. Atualize o histórico.');
      }
      if (categoria != null) {
        final categorias = await txn.query(
          'categorias',
          where: 'id = ? AND tipo = ? AND nome = ?',
          whereArgs: [categoria.id, categoria.tipo.name, categoria.nome],
        );
        if (categorias.isEmpty ||
            originais.values.any((m) => m!['tipo'] != categoria.tipo.name)) {
          throw StateError(
            'Selecione somente receitas ou somente despesas para categorizar.',
          );
        }
      }
      final relacionados = {...ids};
      for (final m in originais.values) {
        if (m!['transferencia_par'] case final int par) relacionados.add(par);
      }
      final antes = await _ler(txn, 'movimentacoes', relacionados);
      final agendaAntes = <int, Map<String, Object?>?>{};
      for (final id in relacionados) {
        for (final a in await txn.query(
          'agenda',
          where: 'movimentacao_id = ?',
          whereArgs: [id],
        )) {
          agendaAntes[a['id'] as int] = Map.of(a);
        }
      }
      final lixeiraIds = <int>[];
      if (excluir) {
        for (final id in ids) { lixeiraIds.addAll(await LixeiraBanco.arquivar(txn, 'id = ?', [id])); }
      }
      for (final id in ids) {
        if (excluir) {
          await txn.delete('movimentacoes', where: 'id = ?', whereArgs: [id]);
        } else {
          await txn.update(
            'movimentacoes',
            {
              if (ativa != null) 'ativa': ativa ? 1 : 0,
              if (categoria != null) 'categoria': categoria.nome,
            },
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }
      return AlteracaoHistorico._(
        db,
        antes,
        await _ler(txn, 'movimentacoes', relacionados),
        agendaAntes,
        await _ler(txn, 'agenda', agendaAntes.keys),
      ).._lixeiraIds = lixeiraIds;
    });
  }

  static bool _iguais(Map<String, Object?>? a, Map<String, Object?>? b) =>
      a == null || b == null
      ? a == b
      : a.length == b.length &&
            a.keys.every((k) => b.containsKey(k) && a[k] == b[k]);

  Future<void> desfazer({Future<void> Function(DatabaseExecutor)? junto}) async {
    if (_desfeita) return;
    await db.transaction((txn) async {
      for (final id in _lixeiraIds) {
        final itens = await txn.query('lixeira', where: 'id = ? AND expira_em > ?', whereArgs: [id, DateTime.now().toUtc().toIso8601String()]);
        if (itens.isEmpty) throw StateError('O item já foi recuperado ou removido da lixeira.');
        await txn.delete('lixeira', where: 'id = ?', whereArgs: [id]);
      }
      final atuais = await _ler(txn, 'movimentacoes', depois.keys);
      final agenda = await _ler(txn, 'agenda', agendaDepois.keys);
      if (depois.keys.any((id) => !_iguais(depois[id], atuais[id])) ||
          agendaDepois.keys.any(
            (id) => !_iguais(agendaDepois[id], agenda[id]),
          )) {
        throw StateError(
          'Esses registros foram alterados novamente. Não é possível desfazer esta ação.',
        );
      }
      // Restaura todos os campos, incluindo a origem do extrato e vínculos.
      for (final id in antes.keys) {
        final linha = antes[id];
        if (linha == null || _iguais(linha, depois[id])) continue;
        for (final ref in {
          'conta_id': 'contas',
          'importacao_id': 'importacoes',
        }.entries) {
          if (linha[ref.key] != null &&
              (await txn.query(
                ref.value,
                where: 'id = ?',
                whereArgs: [linha[ref.key]],
              )).isEmpty) {
            throw StateError(
              'A conta ou importação original foi removida. Não é possível desfazer.',
            );
          }
        }
        if (depois[id] == null) {
          await txn.insert('movimentacoes', {
            ...linha,
            'transferencia_par': null,
          });
        }
      }
      for (final id in antes.keys) {
        final linha = antes[id];
        if (linha != null && !_iguais(linha, depois[id])) {
          await txn.update(
            'movimentacoes',
            linha,
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }
      for (final id in agendaAntes.keys) {
        if (!_iguais(agendaAntes[id], agendaDepois[id])) {
          await txn.update(
            'agenda',
            agendaAntes[id]!,
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }
      if (junto != null) await junto(txn);
    });
    _desfeita = true;
  }
}

class AvisoDesativadas extends StatelessWidget {
  const AvisoDesativadas({
    super.key,
    required this.quantidade,
    required this.onVer,
  });
  final int quantidade;
  final VoidCallback onVer;
  @override
  Widget build(BuildContext context) => quantidade == 0
      ? const SizedBox.shrink()
      : Card(
          child: ListTile(
            leading: const Icon(Icons.pause_circle_outline),
            title: Text(
              '$quantidade ${quantidade == 1 ? 'movimentação desativada' : 'movimentações desativadas'} neste período',
            ),
            subtitle: const Text('Fora dos totais. Toque para revisar.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onVer,
          ),
        );
}
