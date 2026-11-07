import 'package:sqflite/sqflite.dart';

import 'dados_relatorio.dart';

class RepositorioRelatorio {
  RepositorioRelatorio(this.database, this.perfil);
  final Future<Database> database;
  final String perfil;
  Future<List<LinhaRelatorio>> carregar() async {
    final db = await database;
    return db.transaction((txn) async {
      final movimentos = await txn.rawQuery(
        '''SELECT m.*, c.nome AS conta_nome,
        b.nome AS banco_nome, i.nome_arquivo AS arquivo_origem
        FROM movimentacoes m LEFT JOIN contas c ON c.id=m.conta_id
        LEFT JOIN bancos b ON b.codigo=c.banco_codigo
        LEFT JOIN importacoes i ON i.id=m.importacao_id ORDER BY m.data,m.id''',
      );
      final agenda = await txn.query('agenda', orderBy: 'data,id');
      return [
        for (final m in movimentos) LinhaRelatorio(perfil: perfil, dados: m),
        for (final m in agenda)
          LinhaRelatorio(perfil: perfil, dados: m, prevista: true),
      ];
    });
  }
}
