import 'package:flutter_test/flutter_test.dart';
import 'package:financas_facil/main.dart';
import 'package:financas_facil/perfis.dart';

void main() {
  const pessoal = PerfilFinanceiro(id: 1, nome: 'Pessoal', tipo: 'pessoal');
  const empresa = PerfilFinanceiro(
    id: 2,
    nome: 'Minha empresa',
    tipo: 'profissional',
  );
  tearDown(() => CadastroPerfis.atual.value = pessoal);

  test(
    'O perfil original mantém exatamente o arquivo com os dados existentes',
    () {
      expect(pessoal.arquivoBanco, 'financas_facil.db');
      const renomeado = PerfilFinanceiro(id: 1, nome: 'Casa', tipo: 'pessoal');
      expect(renomeado.arquivoBanco, pessoal.arquivoBanco);
    },
  );

  test(
    'Perfis com o mesmo nome têm bancos diferentes; nomes não viram caminhos',
    () {
      const outro = PerfilFinanceiro(
        id: 3,
        nome: 'Minha empresa',
        tipo: 'profissional',
      );
      const nomeEspecial = PerfilFinanceiro(
        id: 2,
        nome: '../teste',
        tipo: 'pessoal',
      );
      expect(empresa.arquivoBanco, isNot(pessoal.arquivoBanco));
      expect(outro.arquivoBanco, isNot(empresa.arquivoBanco));
      expect(nomeEspecial.arquivoBanco, empresa.arquivoBanco);
    },
  );

  test(
    'Operações iniciadas em um perfil mantêm sua instância após a troca',
    () {
      CadastroPerfis.atual.value = pessoal;
      final bancoPessoal = BancoDados.instancia;
      CadastroPerfis.atual.value = empresa;
      final bancoEmpresa = BancoDados.instancia;
      expect(identical(bancoPessoal, bancoEmpresa), isFalse);
      expect(bancoPessoal.perfil.id, 1);
      expect(bancoEmpresa.perfil.id, 2);
      CadastroPerfis.atual.value = pessoal;
      expect(identical(BancoDados.instancia, bancoPessoal), isTrue);
    },
  );

  test('Nomes vazios são rejeitados e espaços são normalizados', () {
    expect(CadastroPerfis.validarNome(' \n '), isNotNull);
    expect(
      CadastroPerfis.normalizarNome('  Minha   empresa  '),
      'Minha empresa',
    );
    expect(CadastroPerfis.validarNome('Minha empresa'), isNull);
    expect(CadastroPerfis.validarNome(List.filled(41, 'a').join()), isNotNull);
  });
}
