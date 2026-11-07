import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class PerfilFinanceiro {
  const PerfilFinanceiro({required this.id, required this.nome, required this.tipo});
  final int id;
  final String nome;
  final String tipo;
  String get arquivoBanco => id == 1 ? 'financas_facil.db' : 'financas_perfil_$id.db';
  factory PerfilFinanceiro.deMapa(Map<String, Object?> mapa) => PerfilFinanceiro(
    id: mapa['id'] as int, nome: mapa['nome'] as String, tipo: mapa['tipo'] as String);
}

class CadastroPerfis {
  static final atual = ValueNotifier<PerfilFinanceiro>(
    const PerfilFinanceiro(id: 1, nome: 'Pessoal', tipo: 'pessoal'));
  static Future<Database>? _abertura;
  static Future<Database> get database => _abertura ??= _abrir();

  static String normalizarNome(String nome) => nome.trim().replaceAll(RegExp(r'\s+'), ' ');
  static String? validarNome(String nome) {
    final limpo = normalizarNome(nome);
    if (limpo.isEmpty) return 'Informe o nome do perfil.';
    if (limpo.length > 40) return 'Use no máximo 40 caracteres.';
    return null;
  }

  static Future<Database> _abrir() async {
    try {
      return await openDatabase(p.join(await getDatabasesPath(), 'financas_perfis.db'),
        version: 1,
        onCreate: (db, version) async {
          await db.execute('CREATE TABLE perfis (id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'nome TEXT NOT NULL, nome_chave TEXT NOT NULL UNIQUE, tipo TEXT NOT NULL)');
          await db.execute('CREATE TABLE estado (chave TEXT PRIMARY KEY, valor INTEGER NOT NULL)');
          await db.insert('perfis', {'id': 1, 'nome': 'Pessoal', 'nome_chave': 'pessoal', 'tipo': 'pessoal'});
          await db.insert('estado', {'chave': 'ativo', 'valor': 1});
        });
    } catch (_) {
      _abertura = null;
      rethrow;
    }
  }

  static Future<List<PerfilFinanceiro>> listar() async =>
    (await (await database).query('perfis', orderBy: 'id')).map(PerfilFinanceiro.deMapa).toList();

  static Future<void> inicializar() async {
    final db = await database;
    final estado = await db.query('estado', where: 'chave = ?', whereArgs: ['ativo']);
    final id = estado.isEmpty ? 1 : estado.single['valor'];
    final perfis = await listar();
    atual.value = perfis.firstWhere((perfil) => perfil.id == id, orElse: () => perfis.first);
  }

  static Future<void> lembrar(PerfilFinanceiro perfil) async {
    final db = await database;
    final existe = await db.query('perfis', where: 'id = ?', whereArgs: [perfil.id]);
    if (existe.isEmpty) throw StateError('Perfil não encontrado.');
    await db.insert('estado', {'chave': 'ativo', 'valor': perfil.id}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> salvar(String nome, String tipo, {int? id}) async {
    final erro = validarNome(nome);
    if (erro != null) throw ArgumentError(erro);
    if (!['pessoal', 'profissional'].contains(tipo)) throw ArgumentError('Tipo inválido.');
    final limpo = normalizarNome(nome);
    final db = await database;
    await db.transaction((txn) async {
      final duplicados = await txn.query('perfis', where: 'nome_chave = ?', whereArgs: [limpo.toLowerCase()]);
      if (duplicados.any((p) => p['id'] != id)) throw ArgumentError('Já existe um perfil com esse nome.');
      final valores = {'nome': limpo, 'nome_chave': limpo.toLowerCase(), 'tipo': tipo};
      if (id == null) {
        await txn.insert('perfis', valores);
      } else {
        final alterados = await txn.update('perfis', valores, where: 'id = ?', whereArgs: [id]);
        if (alterados != 1) throw StateError('Perfil não encontrado.');
      }
    });
    if (id == atual.value.id) atual.value = PerfilFinanceiro(id: id!, nome: limpo, tipo: tipo);
  }
}

class TelaPerfis extends StatefulWidget {
  const TelaPerfis({super.key});
  @override
  State<TelaPerfis> createState() => _TelaPerfisState();
}

class _TelaPerfisState extends State<TelaPerfis> {
  late Future<List<PerfilFinanceiro>> _consulta;
  bool _ocupado = false;
  @override
  void initState() { super.initState(); _consulta = CadastroPerfis.listar(); }

  Future<void> _editar([PerfilFinanceiro? perfil]) async {
    if (_ocupado) return;
    final chave = GlobalKey<FormState>();
    var nome = perfil?.nome ?? '';
    var tipo = perfil?.tipo ?? 'profissional';
    final resultado = await showDialog<(String, String)>(context: context,
      builder: (context) => StatefulBuilder(builder: (context, atualizar) => AlertDialog(
        title: Text(perfil == null ? 'Novo perfil' : 'Editar perfil'),
        content: SingleChildScrollView(child: Form(key: chave, child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(initialValue: nome, autofocus: true, maxLength: 40,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nome', hintText: 'Ex.: Minha empresa'),
              onChanged: (valor) => nome = valor,
              validator: (valor) => CadastroPerfis.validarNome(valor ?? '')),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(initialValue: tipo,
              decoration: const InputDecoration(labelText: 'Uso do perfil'),
              items: const [DropdownMenuItem(value: 'pessoal', child: Text('Pessoal')),
                DropdownMenuItem(value: 'profissional', child: Text('Profissional'))],
              onChanged: (valor) => atualizar(() => tipo = valor!)),
          ],
        ))),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () {
            if (chave.currentState!.validate()) Navigator.pop(context, (nome, tipo));
          }, child: const Text('Salvar'))],
      )));
    if (!mounted || resultado == null) return;
    setState(() => _ocupado = true);
    try {
      await CadastroPerfis.salvar(resultado.$1, resultado.$2, id: perfil?.id);
      if (!mounted) return;
      setState(() => _consulta = CadastroPerfis.listar());
    } catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        erro is ArgumentError ? '${erro.message}' : 'Não foi possível salvar o perfil. Tente novamente.')));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Perfis')),
    body: FutureBuilder<List<PerfilFinanceiro>>(future: _consulta, builder: (context, snapshot) {
      if (snapshot.hasError) { return Center(child: TextButton(
        onPressed: () => setState(() => _consulta = CadastroPerfis.listar()), child: const Text('Tentar novamente'))); }
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      return ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Escolha o perfil que deseja usar. Cada perfil tem seus próprios dados financeiros.'),
        const SizedBox(height: 16),
        for (final perfil in snapshot.data!) Card(child: ListTile(
          enabled: !_ocupado,
          leading: Icon(perfil.tipo == 'pessoal' ? Icons.person_outline : Icons.business_outlined),
          title: Text(perfil.nome),
          subtitle: Text('${perfil.tipo == 'pessoal' ? 'Pessoal' : 'Profissional'}'
            '${perfil.id == CadastroPerfis.atual.value.id ? ' • Em uso' : ''}'),
          onTap: () => Navigator.pop(context, perfil),
          trailing: IconButton(tooltip: 'Editar perfil', onPressed: _ocupado ? null : () => _editar(perfil),
            icon: const Icon(Icons.edit_outlined)),
        )),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: _ocupado ? null : () => _editar(),
          icon: const Icon(Icons.add), label: const Text('Criar perfil')),
        if (_ocupado) const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
      ]);
    }),
  );
}
