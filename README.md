# Finanças Fácil

Aplicativo Flutter para finanças pessoais e profissionais, com dados locais em SQLite, perfis separados, receitas/despesas, recorrências, gráficos e relatórios.

## Desenvolvimento

Consulte [o guia de desenvolvimento e publicação](docs/desenvolvimento.md) para ambiente, testes, Android Lint, depuração por Wi-Fi, backup e assinatura de produção.

```powershell
flutter pub get
flutter analyze
flutter test --coverage
flutter run -d IDENTIFICADOR_ATUAL
```

Os testes de SQLite local precisam de `VALIDACAO_PYTHON` apontando para um Python real com `sqlite3`. O teste Android em `integration_test/` usa apenas banco em memória e não acessa os dados dos seus perfis.

## Backup e exportação

CSV, Excel e PDF são relatórios, não backups restauráveis. Em **Configurações → Gerenciar dados → Backup integral**, é possível criar uma cópia dos dados SQLite de todos os perfis, com verificação de integridade. A restauração ainda não está disponível; criar o arquivo não substitui nem apaga bancos.

## Publicação

Sem credenciais de produção, o APK release é gerado sem assinatura. Nenhuma chave ou senha deve ser adicionada ao Git. Veja a configuração segura no guia antes de distribuir.
