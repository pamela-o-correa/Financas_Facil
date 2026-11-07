import 'regressoes_persistencia.dart';
import 'package:financas_facil/contas/lixeira_banco.dart';

import 'dart:async';

import 'dart:convert';

import 'dart:io';



import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:financas_facil/contas/contas_banco.dart';

import 'package:financas_facil/main.dart';

import 'package:financas_facil/perfis.dart';

import 'package:sqflite/sqflite.dart';



void main() {

  TestWidgetsFlutterBinding.ensureInitialized();

  databaseFactory = databaseFactorySqflitePlugin;

  test(

    'SQLite real: migração, vínculo, duplicatas e rollback atômico',

    () async {

      final python = Platform.environment['VALIDACAO_PYTHON'] ?? 'python';

      final process = await Process.start(python, ['test/sqlite_bridge.py']);

      final lines = StreamIterator(

        process.stdout.transform(utf8.decoder).transform(const LineSplitter()),

      );

      const canal = MethodChannel('com.tekartik.sqflite');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger

          .setMockMethodCallHandler(canal, (call) async {

            if (call.method == 'getDatabasesPath') {

              return Directory.systemTemp.path;

            }

            if (call.method == 'openDatabase') return {'id': 1};

            if (call.method == 'closeDatabase') return null;

            final args = Map<String, dynamic>.from(call.arguments as Map);

            process.stdin.writeln(jsonEncode({...args, 'method': call.method}));

            await process.stdin.flush();

            if (!await lines.moveNext()) throw StateError('SQLite finalizado');

            final response = jsonDecode(lines.current) as Map;

            if (response.containsKey('error')) {

              throw PlatformException(

                code: 'sqlite_error',

                message: response['error'],

              );

            }

            return response['result'];

          });

      addTearDown(() async {

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger

            .setMockMethodCallHandler(canal, null);

        await lines.cancel();

        process.kill();

      });

      final db = await openDatabase(

        inMemoryDatabasePath,

        singleInstance: false,

      );

      await db.execute('PRAGMA foreign_keys = ON');

      await db.execute(

        'CREATE TABLE movimentacoes (id INTEGER PRIMARY KEY, tipo TEXT NOT NULL, valor REAL NOT NULL, categoria TEXT NOT NULL, descricao TEXT NOT NULL, data TEXT NOT NULL, conta TEXT DEFAULT "", importacao_id INTEGER)',

      );

      await db.execute(

        'CREATE TABLE importacoes (id INTEGER PRIMARY KEY, nome_arquivo TEXT NOT NULL, importado_em TEXT NOT NULL, quantidade_original INTEGER NOT NULL)',

      );

      await db.insert('movimentacoes', {

        'id': 42,

        'tipo': 'receita',

        'valor': 10.0,

        'categoria': 'Outros',

        'descricao': 'Anterior',

        'data': '2026-01-01',

        'conta': 'Carteira antiga',

      });

      await ContasBanco.migrar(db);

      await ContasBanco.migrar(db);

      final antigo = (await db.query('movimentacoes')).single;

      expect(antigo['id'], 42);

      expect(antigo['conta'], 'Carteira antiga');

      expect(antigo['conta_id'], isNull);

      final repo = ContasBanco(Future.value(db));

      const conta = ContaOrigem(nome: 'Minha conta', bancoCodigo: '001');

      ItemExtrato item() => ItemExtrato(

        data: DateTime(2026, 9, 1),

        descricao: 'Pagamento teste',

        valor: 12.34,

        tipo: TipoMovimentacao.despesa,

        documento: 'ABC',

        linhaOrigem: 3,

        bancoCodigo: '001',

      );

      final id = await repo.importar(

        nomeArquivo: 'teste.csv',

        itens: [item()],

        conta: conta,

        bancoDetectado: '001',

      );

      final salvo = (await db.query(

        'movimentacoes',

        where: 'importacao_id = ?',

        whereArgs: [id],

      )).single;

      expect(salvo['conta_id'], (await repo.listar()).single.id);

      expect(salvo['documento_origem'], 'ABC');

      expect(salvo['linha_origem'], 3);

      expect(salvo['valor'], 12.34);

      final duplicata = item();

      await repo.identificarDuplicatas([duplicata], conta);

      expect(duplicata.possivelDuplicata, true);

      const outra = ContaOrigem(nome: 'Outra conta', bancoCodigo: '001');

      final diferente = item();

      await repo.identificarDuplicatas([diferente], outra);

      expect(diferente.possivelDuplicata, false);

      final dois = [item(), item()];

      await repo.identificarDuplicatas(dois, outra);

      expect(dois.last.possivelDuplicata, true);

      await repo.salvar(

        const ContaOrigem(nome: ' MINHA   CONTA ', bancoCodigo: '001'),

      );

      expect((await repo.listar()).length, 1);

      await db.execute(

        "CREATE TRIGGER falhar_importacao BEFORE INSERT ON movimentacoes BEGIN SELECT RAISE(ABORT, 'falha simulada'); END",

      );

      await expectLater(

        repo.importar(

          nomeArquivo: 'falha.csv',

          itens: [item()],

          conta: outra,

          bancoDetectado: '001',

        ),

        throwsA(isA<Exception>()),

      );

      expect((await db.query('importacoes')).length, 1);

      expect((await db.query('movimentacoes')).length, 2);

      expect((await repo.listar()).length, 1);

      await db.execute('DROP TRIGGER falhar_importacao');

      // Vários arquivos da mesma conta, nomes persistidos e relatório consolidado.

      const nubank = ContaOrigem(nome: 'Pessoal', bancoCodigo: '260');

      for (var arquivo = 0; arquivo < 4; arquivo++) {

        await repo.importar(

          nomeArquivo: 'nubank$arquivo.csv',

          itens: [item()],

          conta: nubank,

          bancoDetectado: 'generico',

        );

      }

      expect(

        (await repo.listar()).where((c) => c.bancoCodigo == '260').length,

        1,

      );

      const personalizado = ContaOrigem(

        nome: 'Pessoal',

        bancoCodigo: 'personalizado:banco local',

        nomeBanco: 'Banco Local',

      );

      await repo.salvar(personalizado);

      expect(

        (await repo.listarBancos())['personalizado:banco local'],

        'Banco Local',

      );

      expect(

        (await repo.listar())

            .firstWhere((c) => c.bancoCodigo == personalizado.bancoCodigo)

            .bancoNome,

        'Banco Local',

      );

      await repo.salvar(

        const ContaOrigem(nome: 'Segunda conta', bancoCodigo: '260'),

      );

      final origem = (await repo.listar()).firstWhere(

        (c) => c.bancoCodigo == '001',

      );

      final quantidadeAntes = (await db.query('movimentacoes')).length;

      await repo.reunir(origem.id!, nubank);

      expect((await db.query('movimentacoes')).length, quantidadeAntes);

      expect((await repo.listar()).any((c) => c.id == origem.id), false);

      final resumo = await repo.resumo(DateTime(2026, 9), DateTime(2026, 10));

      final nu = resumo.single;

      expect(nu['banco_nome'], 'Nubank');

      expect(nu['quantidade'], 5);

      expect(nu['saidas'] as num, closeTo(61.70, 0.001));

      expect(await repo.resumo(DateTime(2027), DateTime(2028)), isEmpty);

      final repetido = item();

      await repo.identificarDuplicatas([repetido], nubank);

      expect(repetido.possivelDuplicata, true);

      final paraEditar = (await repo.listar()).firstWhere(

        (c) => c.bancoCodigo == '260' && c.nome == 'Segunda conta',

      );

      await repo.editar(

        paraEditar.id!,

        const ContaOrigem(nome: 'Renomeada', bancoCodigo: '001'),

      );

      expect(

        (await repo.listar()).firstWhere((c) => c.id == paraEditar.id).nome,

        'Renomeada',

      );

      await expectLater(

        repo.editar(paraEditar.id!, nubank),

        throwsA(isA<StateError>()),

      );

      expect(

        (await repo.listar())

            .firstWhere((c) => c.id == paraEditar.id)

            .bancoCodigo,

        '001',

      );

      final contaNu = (await repo.listar()).firstWhere(

        (c) => c.bancoCodigo == '260' && c.nome == 'Pessoal',

      );

      expect(await repo.contarVinculos(contaNu.id!), (5, 5));

      await repo.editar(

        contaNu.id!,

        const ContaOrigem(nome: 'Atualizada', bancoCodigo: '260'),

      );

      expect(await repo.contarVinculos(contaNu.id!), (5, 5));

      await repo.excluir(contaNu.id!);

      expect((await db.query('movimentacoes')).length, quantidadeAntes);

      expect((await db.query('importacoes')).length, 5);

      expect(

        await db.query(

          'movimentacoes',

          where: 'conta_id = ?',

          whereArgs: [contaNu.id],

        ),

        isEmpty,

      );

      expect(

        await db.query(

          'importacoes',

          where: 'conta_id = ?',

          whereArgs: [contaNu.id],

        ),

        isEmpty,

      );

      await repo.importar(

        nomeArquivo: 'apagar.csv',

        itens: [item()],

        conta: nubank,

        bancoDetectado: 'generico',

      );

      final novaNu = (await repo.listar()).firstWhere(

        (c) => c.bancoCodigo == '260' && c.nome == 'Pessoal',

      );

      await db.execute(

        "CREATE TRIGGER impedir_exclusao BEFORE DELETE ON contas BEGIN SELECT RAISE(ABORT, 'falha simulada'); END",

      );

      await expectLater(

        repo.excluir(novaNu.id!, apagarDados: true),

        throwsA(isA<Exception>()),

      );

      expect(await repo.contarVinculos(novaNu.id!), (1, 1));

      await db.execute('DROP TRIGGER impedir_exclusao');

      await repo.excluir(novaNu.id!, apagarDados: true);

      expect((await db.query('movimentacoes')).length, quantidadeAntes);

      expect((await db.query('importacoes')).length, 5);

      expect(

        (await repo.listar()).any(

          (c) => c.bancoCodigo == personalizado.bancoCodigo,

        ),

        true,

      );

      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);

      // Executa também os callbacks reais de criação e atualização do aplicativo.

      for (final tabela in [

        'movimentacoes',

        'importacoes',

        'contas',

        'bancos',

      ]) {

        await db.execute('DROP TABLE $tabela');

      }

      await db.close();

      final bancoNovo = BancoDados.paraPerfil(

        const PerfilFinanceiro(id: 998, nome: 'Teste criação', tipo: 'pessoal'),

      );

      final novo = await bancoNovo.database;

      expect(await novo.getVersion(), 14);

      expect((await novo.query('bancos')).length, bancosImportacao.length);

      expect(await novo.query('contas'), isEmpty);

      await novo.insert('movimentacoes', {

        'id': 77,

        'tipo': 'receita',

        'valor': 45.67,

        'categoria': 'Outros',

        'descricao': 'Preservar na atualização',

        'data': '2026-09-01',

      });

      await novo.execute('DROP TRIGGER editar_par_transferencia');

      await novo.execute('DROP INDEX idx_movimentacoes_conta');

      await novo.execute('DROP INDEX IF EXISTS idx_importacoes_conta');

      for (final coluna in ['conta_id', 'documento_origem', 'linha_origem', 'ativa']) {

        await novo.execute('ALTER TABLE movimentacoes DROP COLUMN $coluna');

      }

      for (final coluna in ['conta_id', 'banco_detectado']) {

        await novo.execute('ALTER TABLE importacoes DROP COLUMN $coluna');

      }

      await novo.execute('DROP TABLE contas');

      await novo.execute('DROP TABLE bancos');

      await novo.setVersion(8);

      await novo.close();

      final bancoAntigo = BancoDados.paraPerfil(

        const PerfilFinanceiro(

          id: 999,

          nome: 'Teste atualização',

          tipo: 'pessoal',

        ),

      );

      final atualizado = await bancoAntigo.database;

      expect(await atualizado.getVersion(), 14);

      final preservado = (await atualizado.query('movimentacoes')).single;

      expect(preservado['id'], 77);

      expect(preservado['valor'], 45.67);

      expect(preservado['conta_id'], isNull);

      expect(

        (await atualizado.query('bancos')).length,

        bancosImportacao.length,

      );

      expect(await bancoAntigo.listarImportacoes(), isEmpty);

      final operacoes = OperacoesFinanceiras(Future.value(atualizado));

      final contasFinal = ContasBanco(Future.value(atualizado));

      await contasFinal.salvar(

        const ContaOrigem(nome: 'Saída', bancoCodigo: '001'),

      );

      await contasFinal.salvar(

        const ContaOrigem(nome: 'Entrada', bancoCodigo: '260'),

      );

      final contasIds = await contasFinal.listar();

      final origemFinal = contasIds.first.id!;

      final destino = contasIds.last.id!;

      final saidaId = await atualizado.insert('movimentacoes', {

        'tipo': 'despesa',

        'valor': 100.0,

        'categoria': 'Outros',

        'descricao': 'PIX teste',

        'data': '2026-09-30T00:00:00.000',

        'conta_id': origemFinal,

      });

      final entradaId = await atualizado.insert('movimentacoes', {

        'tipo': 'receita',

        'valor': 100.0,

        'categoria': 'Outros',

        'descricao': 'PIX recebido',

        'data': '2026-10-01T00:00:00.000',

        'conta_id': destino,

      });

      await operacoes.confirmarTransferencia(saidaId, entradaId);

      var movimentosFinal = await bancoAntigo.listar();

      expect(movimentosFinal.where((m) => m.transferencia).length, 2);

      expect(totaisCategorias(movimentosFinal), isEmpty);

      await expectLater(

        operacoes.confirmarTransferencia(saidaId, entradaId),

        throwsA(isA<StateError>()),

      );

      await operacoes.desfazerTransferencia(saidaId);

      expect((await bancoAntigo.listar()).any((m) => m.transferencia), false);

      await operacoes.confirmarTransferencia(saidaId, entradaId);

      await atualizado.update(

        'movimentacoes',

        {'valor': 90.0},

        where: 'id = ?',

        whereArgs: [entradaId],

      );

      expect((await bancoAntigo.listar()).any((m) => m.transferencia), false);

      await expectLater(

        operacoes.confirmarTransferencia(saidaId, entradaId),

        throwsA(isA<StateError>()),

      );

      await atualizado.update(

        'movimentacoes',

        {'valor': 100.0},

        where: 'id = ?',

        whereArgs: [entradaId],

      );

      await operacoes.confirmarTransferencia(saidaId, entradaId);

      await atualizado.delete(

        'movimentacoes',

        where: 'id = ?',

        whereArgs: [entradaId],

      );

      expect((await bancoAntigo.listar()).any((m) => m.transferencia), false);

      final categoria = (await bancoAntigo.listarCategorias()).firstWhere(

        (c) => c.tipo == TipoMovimentacao.despesa && c.nome != 'Outros',

      );

      await operacoes.categorizar([saidaId], categoria, regra: 'PIX teste');

      expect(

        (await bancoAntigo.listar())

            .firstWhere((m) => m.id == saidaId)

            .categoria,

        categoria.nome,

      );

      expect((await bancoAntigo.listarRegrasImportacao()).length, 1);

      await operacoes.categorizar(

        [saidaId],

        categoria,

        regra: '  PIX   teste ',

      );

      expect((await bancoAntigo.listarRegrasImportacao()).length, 1);

      final outraCategoria = (await bancoAntigo.listarCategorias()).firstWhere(

        (c) => c.tipo == TipoMovimentacao.despesa && c.id != categoria.id,

      );

      await expectLater(

        operacoes.categorizar([saidaId], outraCategoria, regra: 'PIX teste'),

        throwsA(isA<StateError>()),

      );

      expect(

        (await bancoAntigo.listar())

            .firstWhere((m) => m.id == saidaId)

            .categoria,

        categoria.nome,

      );

      await expectLater(

        operacoes.categorizar([saidaId, 77], outraCategoria),

        throwsA(isA<StateError>()),

      );

      expect(

        (await bancoAntigo.listar())

            .firstWhere((m) => m.id == saidaId)

            .categoria,

        categoria.nome,

      );

      final itemRegra = ItemExtrato(

        data: DateTime(2026, 10),

        descricao: 'PIX teste loja',

        valor: 10,

        tipo: TipoMovimentacao.despesa,

      );

      await bancoAntigo.aplicarRegrasImportacao([itemRegra]);

      expect(itemRegra.categoria, categoria.nome);

      await atualizado.close();

      final versaoOnze = BancoDados.paraPerfil(

        const PerfilFinanceiro(id: 1001, nome: 'Versão onze', tipo: 'pessoal'),

      );

      final dbOnze = await versaoOnze.database;

      await dbOnze.execute('DROP TRIGGER remover_par_transferencia');

      await dbOnze.execute('DROP TRIGGER editar_par_transferencia');

      await dbOnze.execute('DROP INDEX idx_transferencia_par');

      await dbOnze.execute(

        'ALTER TABLE movimentacoes DROP COLUMN transferencia_par',

      );

      final quantidadeOnze = (await dbOnze.query('movimentacoes')).length;

      await dbOnze.execute('ALTER TABLE movimentacoes DROP COLUMN ativa');

      await dbOnze.setVersion(11);

      await dbOnze.close();

      final versaoDoze = BancoDados.paraPerfil(

        const PerfilFinanceiro(

          id: 1002,

          nome: 'Atualização doze',

          tipo: 'pessoal',

        ),

      );

      final dbDoze = await versaoDoze.database;

      expect(await dbDoze.getVersion(), 14);

      expect((await versaoDoze.listar()).length, quantidadeOnze);

      expect((await versaoDoze.listar()).any((m) => m.transferencia), false);

      final antiga = (await versaoDoze.listar()).first;

      expect(antiga.ativa, true);

      await versaoDoze.atualizar(antiga.copyWith(ativa: false));

      expect((await versaoDoze.listar()).firstWhere((m) => m.id == antiga.id).ativa, false);

      await versaoDoze.atualizar(antiga.copyWith(ativa: true));

      expect((await versaoDoze.listar()).firstWhere((m) => m.id == antiga.id).ativa, true);

      final idUx = await versaoDoze.inserir(Movimentacao(tipo: TipoMovimentacao.despesa,

        valor: 120, categoria: 'Outros', descricao: 'UX original', data: DateTime(2026, 9, 9)));

      final idParUx = await versaoDoze.inserir(Movimentacao(tipo: TipoMovimentacao.receita,

        valor: 120, categoria: 'Outros', descricao: 'Par UX', data: DateTime(2026, 9, 9)));

      await dbDoze.update('movimentacoes', {'transferencia_par': idParUx, 'documento_origem': 'EXTRATO-123', 'linha_origem': 8}, where: 'id = ?', whereArgs: [idUx]);

      await dbDoze.update('movimentacoes', {'transferencia_par': idUx}, where: 'id = ?', whereArgs: [idParUx]);

      final agendaUx = await dbDoze.insert('agenda', {

        'serie': 'ux', 'titulo': 'UX original', 'tipo': 'despesa', 'centavos': 12000,

        'categoria': 'Outros', 'data': '2026-09-09', 'frequencia': 'unica', 'hora': 9, 'minuto': 0,

        'status': 'realizado', 'movimentacao_id': idUx,

      });

      final originalUx = (await dbDoze.query('movimentacoes', where: 'id = ?', whereArgs: [idUx])).single;

      final agendaOriginalUx = (await dbDoze.query('agenda', where: 'id = ?', whereArgs: [agendaUx])).single;

      final exclusao = await AlteracaoHistorico.executar(dbDoze, {idUx}, excluir: true);

      expect((await dbDoze.query('agenda', where: 'id = ?', whereArgs: [agendaUx])).single['status'], 'pendente');

      expect((await dbDoze.query('movimentacoes', where: 'id = ?', whereArgs: [idParUx])).single['transferencia_par'], isNull);

      await exclusao.desfazer();

      expect((await dbDoze.query('movimentacoes', where: 'id = ?', whereArgs: [idUx])).single, originalUx);

      expect((await dbDoze.query('agenda', where: 'id = ?', whereArgs: [agendaUx])).single, agendaOriginalUx);

      expect((await dbDoze.query('movimentacoes', where: 'id = ?', whereArgs: [idParUx])).single['transferencia_par'], idUx);

      final loteUx = await AlteracaoHistorico.executar(dbDoze, {idUx, idParUx}, ativa: false);

      expect((await versaoDoze.listar()).where((m) => {idUx, idParUx}.contains(m.id)).every((m) => !m.ativa), true);

      await loteUx.desfazer();

      expect((await versaoDoze.listar()).where((m) => {idUx, idParUx}.contains(m.id)).every((m) => m.ativa), true);

      final categoriaUx = (await versaoDoze.listarCategorias()).firstWhere((c) => c.tipo == TipoMovimentacao.despesa && c.nome != 'Outros');

      await expectLater(AlteracaoHistorico.executar(dbDoze, {idUx, idParUx}, categoria: categoriaUx), throwsStateError);

      final categorizacaoUx = await AlteracaoHistorico.executar(dbDoze, {idUx}, categoria: categoriaUx);

      expect((await dbDoze.query('agenda', where: 'id = ?', whereArgs: [agendaUx])).single['categoria'], categoriaUx.nome);

      await categorizacaoUx.desfazer();

      final conflitoUx = await AlteracaoHistorico.executar(dbDoze, {idUx}, ativa: false);

      await dbDoze.update('movimentacoes', {'descricao': 'Edição posterior'}, where: 'id = ?', whereArgs: [idUx]);

      await expectLater(conflitoUx.desfazer(), throwsStateError);

      expect((await dbDoze.query('movimentacoes', where: 'id = ?', whereArgs: [idUx])).single['descricao'], 'Edição posterior');

      final contaUx = ContaOrigem(nome: 'Importação UX', bancoCodigo: '260');

      final importacaoUx = await ContasBanco(Future.value(dbDoze)).importar(nomeArquivo: 'ux.csv', itens: [

        ItemExtrato(data: DateTime(2026, 9, 9), descricao: 'Aplicação RDB', valor: 5000,

          tipo: TipoMovimentacao.despesa, ativa: false),

      ], conta: contaUx, bancoDetectado: '260');

      expect((await dbDoze.query('movimentacoes', where: 'importacao_id = ?', whereArgs: [importacaoUx])).single['ativa'], 0);

      final preferenciasUx = PreferenciasContabilizacao(Future.value(dbDoze));

      final contaSalvaUx = (await ContasBanco(Future.value(dbDoze)).listar()).firstWhere((c) => c.nome == contaUx.nome);

      final regraUx = PreferenciaContabilizacao(contaId: contaSalvaUx.id!, tipo: TipoMovimentacao.despesa,

        descricao: 'Aplicação RDB', ativa: false);

      final mudancaUx = await preferenciasUx.salvar(regraUx);

      expect((await preferenciasUx.listar()).single.ativa, false);

      final sugestaoUx = ItemExtrato(data: DateTime(2026), descricao: ' APLICAÇÃO   RDB ', valor: 300,

        tipo: TipoMovimentacao.despesa);

      final outroTipoUx = ItemExtrato(data: DateTime(2026), descricao: 'Aplicação RDB', valor: 300,

        tipo: TipoMovimentacao.receita);

      final outraDescricaoUx = ItemExtrato(data: DateTime(2026), descricao: 'Aplicação RDB adicional', valor: 300,

        tipo: TipoMovimentacao.despesa);

      await preferenciasUx.sugerir([sugestaoUx, outroTipoUx, outraDescricaoUx], contaUx);

      expect(sugestaoUx.contabilizacaoSugerida, false);

      expect(sugestaoUx.ativa, true);

      expect(outroTipoUx.contabilizacaoSugerida, isNull);

      expect(outraDescricaoUx.contabilizacaoSugerida, isNull);

      await preferenciasUx.sugerir([sugestaoUx], const ContaOrigem(nome: 'Outra conta não cadastrada', bancoCodigo: '260'));

      expect(sugestaoUx.contabilizacaoSugerida, isNull);

      await preferenciasUx.salvar(regraUx.copiar(habilitada: false));

      await preferenciasUx.sugerir([sugestaoUx], contaUx);

      expect(sugestaoUx.contabilizacaoSugerida, isNull);

      await preferenciasUx.salvar(regraUx.copiar(ativa: true));

      expect((await preferenciasUx.listar()).length, 1);

      await preferenciasUx.sugerir([sugestaoUx], contaUx);

      expect(sugestaoUx.contabilizacaoSugerida, true);

      await preferenciasUx.excluir(regraUx);

      expect(await preferenciasUx.listar(), isEmpty);

      await preferenciasUx.salvar(regraUx);

      await dbDoze.transaction((txn) => mudancaUx.desfazer(txn));

      expect(await preferenciasUx.listar(), isEmpty);

      final mudancaComUndo = await preferenciasUx.salvar(regraUx);

      final movimentoComUndo = await AlteracaoHistorico.executar(dbDoze, {idUx}, ativa: true);

      await movimentoComUndo.desfazer(junto: mudancaComUndo.desfazer);

      expect(await preferenciasUx.listar(), isEmpty);

      final mudancaConflitante = await preferenciasUx.salvar(regraUx);

      final movimentoConflitante = await AlteracaoHistorico.executar(dbDoze, {idUx}, ativa: true);

      await preferenciasUx.salvar(regraUx.copiar(ativa: true));

      await expectLater(movimentoConflitante.desfazer(junto: mudancaConflitante.desfazer), throwsStateError);

      expect((await dbDoze.query('movimentacoes', where: 'id = ?', whereArgs: [idUx])).single['ativa'], 1);

      final lixo = LixeiraBanco(Future.value(dbDoze));

      await lixo.esvaziar();

      final apagada = await AlteracaoHistorico.executar(dbDoze, {idUx}, excluir: true);

      expect((await lixo.listar()).length, 1);

      await apagada.desfazer();

      expect(await lixo.listar(), isEmpty);

      final apagada2 = await AlteracaoHistorico.executar(dbDoze, {idUx}, excluir: true);

      await lixo.restaurar((await lixo.listar()).single['id'] as int);

      expect(await lixo.listar(), isEmpty);

      await expectLater(apagada2.desfazer(), throwsStateError);

      final recuperada = (await dbDoze.query('movimentacoes', where: 'descricao = ?', whereArgs: ['Edição posterior'])).single;

      expect(recuperada['ativa'], 0);

      expect(recuperada['transferencia_par'], isNull);

      expect(recuperada['documento_origem'], 'EXTRATO-123');

      expect((await dbDoze.query('agenda', where: 'id = ?', whereArgs: [agendaUx])).single['movimentacao_id'], recuperada['id']);

      await versaoDoze.excluir(recuperada['id'] as int);

      final itemLixo = (await lixo.listar()).single;
      final duplicataLixeira = Map<String, Object?>.from(recuperada)..remove('id');
      await dbDoze.insert('movimentacoes', duplicataLixeira);
      await expectLater(lixo.restaurar(itemLixo['id'] as int), throwsA(isA<DuplicataNaRecuperacao>()));
      expect((await lixo.listar()).length, 1);

      await dbDoze.update('lixeira', {'expira_em': DateTime.now().toUtc().subtract(const Duration(days: 1)).toIso8601String()});

      await expectLater(lixo.restaurar(itemLixo['id'] as int), throwsStateError);

      expect(await lixo.listar(), isEmpty);

      await verificarRegressoesPersistencia(versaoDoze);
      await dbDoze.close();

    },

    skip: Platform.environment['VALIDACAO_PYTHON'] == null

        ? 'Defina VALIDACAO_PYTHON com o executável Python para testar SQLite real.'

        : false,

  );

}

