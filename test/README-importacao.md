# Testes de importação

Execute `flutter test` para os testes do motor e das telas, junto aos testes existentes.

O teste `contas_sqlite_test.dart` usa SQLite real por meio da biblioteca padrão do Python, em memória. Ele valida criação e migração do banco, preservação de registros, conta de origem, duplicatas e reversão de falhas. Nenhum banco pessoal é aberto.

Para incluí-lo, defina `VALIDACAO_PYTHON` com o caminho completo de um executável Python 3 e execute `flutter test` novamente. Sem essa variável, somente esse teste é marcado como ignorado.

Na validação da implementação, os 38 testes foram executados, incluindo o SQLite.
