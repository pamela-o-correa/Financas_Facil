# Desenvolvimento e publicação

## Ambiente

Use Flutter stable compatível com o lockfile, JDK 17 e Android SDK. A base
validada nesta revisão é Flutter 3.50.0 / Dart 3.14.0, AGP 9.1.1, Gradle 9.3.1,
Kotlin integrado, SDK/Build Tools 36, NDK 28.2.13676358 e CMake 3.22.1.
O SDK ainda recomenda versões futuras de Gradle/AGP: atualize o conjunto com
validação dos plugins, sem desativar verificações de compatibilidade.

Os widgets foram migrados para `material_ui` 1.0.0, equivalente à biblioteca
original, e as traduções usam os delegates do pacote. O lockfile deve ser
versionado; não use upgrades em massa para resolver avisos.

Para testes SQLite locais, instale/configure um Python com `sqlite3` e defina
`VALIDACAO_PYTHON` com o caminho real do executável. Consulte-o com
`python -c "import sys; print(sys.executable)"`. O atalho da Microsoft Store
pode existir mesmo sem apontar para o interpretador instalado.

## Validação

Na raiz Flutter:

```powershell
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --coverage
python tool/resumir_cobertura.py
flutter build apk --debug
flutter build apk --release
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tool\verificar_android_lint.ps1
```

O script de Lint normaliza o escape dos caminhos em `android/local.properties`,
que o Flutter regenera no Windows, e recalcula a análise. Nenhum diagnóstico
é suprimido. `-JdkPath` permite selecionar outro JDK instalado. A política de
execução de scripts vale só para o processo; o script restaura `JAVA_HOME`.

Para testes Kotlin: em `android`, execute `gradlew.bat :app:testDebugUnitTest`
com `JAVA_HOME` apontando para o JDK. Os testes de regras de lembretes são
independentes do Android. Migrações Dart usam SQLite do Python em memória,
incluindo schemas 1–14, integridade e rollback de falha intermediária.

Com um Android conectado:

```powershell
flutter devices
flutter test integration_test/persistencia_android_test.dart -d IDENTIFICADOR_ATUAL
flutter run -d IDENTIFICADOR_ATUAL
```

O teste de integração usa apenas SQLite `:memory:`. Depois, `flutter run`
reinstala o aplicativo normal com a mesma identidade de depuração, preservando
os bancos existentes. Nunca desinstale nem limpe dados para contornar falhas.

Cobertura global inclui telas grandes ainda acopladas a `main.dart`. A cobertura
do núcleo mede modelos, persistência, repositórios de contas, importadores,
exportadores e backup, excluindo arquivos de tela. O script mostra os arquivos
e os dois percentuais, sem substituir testes nem ocultar lacunas das telas.

## Windows e depuração por Wi-Fi

Use o SDK Flutter no PATH do seu terminal ou configure `dart.flutterSdkPath`
no VS Code. O workspace local pode definir Flutter, ADB, Python e
`VALIDACAO_PYTHON`, sem alterar o PATH permanente do Windows.

Após `flutter clean`, máquinas sem permissão de links simbólicos podem falhar
em `pub get` ao preparar plugins desktop. A alternativa local é:

```powershell
flutter pub get
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tool\preparar_plugins_windows.ps1
flutter pub get
```

O primeiro comando gera a lista de plugins mesmo quando a criação dos links
falha. O script cria junções apenas nas pastas geradas do projeto e não altera
o Windows, o cache dos pacotes nem destinos preexistentes.

Mantenha celular e computador na mesma rede, com depuração sem fio ativa.
Consulte `adb devices -l`; se necessário, execute `adb connect IP:PORTA` usando
a porta de conexão atual do celular, diferente da porta de pareamento. F5
inicia a depuração no dispositivo selecionado; `r` faz Hot Reload e `d`
desconecta mantendo o aplicativo aberto.

## Dados e backup

CSV, XLSX e PDF são relatórios. Reimportar um CSV não restaura flags, vínculos
ou preferências e não é uma recuperação integral.

Em Configurações → Gerenciar dados → Backup integral, o aplicativo cria um
arquivo `.ffbackup` com catálogo, todos os perfis cadastrados, estruturas SQL,
versões dos bancos, tabelas, IDs, sequências, estados de contabilização,
vínculos, agenda, lixeira e preferências armazenadas em SQLite.

As conexões dos perfis são somente leitura e não invocam migrações, criação
de categorias ou expiração da lixeira. Perfis ainda sem banco são marcados
como não inicializados, sem criar arquivos. Cada banco é lido em transação;
não há garantia de snapshot simultâneo de bancos distintos contra gravadores
externos. Uma falha aborta o arquivo inteiro e fecha as conexões próprias.

O formato possui versão e SHA-256 para detectar corrupção acidental. O hash
não autentica a origem nem criptografa os dados. O arquivo deve ser guardado
em local seguro; o limite atual é 128 MB. Preferências Android transitórias de
entrega de notificações não fazem parte dos dados financeiros exportados.

Há validação do formato, mas **não há restauração implementada**. Uma futura
restauração precisa validar referências e schemas, usar cópias isoladas e
garantir rollback antes de substituir qualquer banco. Não execute SQL contido
em arquivos recebidos de terceiros. O botão de apagar dados de um perfil
continua sendo uma operação explícita separada do backup.

## Assinatura de produção

`release` não usa mais a chave de debug. Sem credenciais, o build de APK
produz um artefato **não assinado**, útil só para validar a compilação.
O bundle de distribuição exige a tarefa `validateProductionSigning`.

Forneça um keystore existente fora do repositório por `android/key.properties`
(use `android/key.properties.example` como referência), ou pelas variáveis:

| Campo | Variável |
| --- | --- |
| storeFile | FINANCAS_KEYSTORE_PATH |
| storePassword | FINANCAS_STORE_PASSWORD |
| keyAlias | FINANCAS_KEY_ALIAS |
| keyPassword | FINANCAS_KEY_PASSWORD |

As variáveis têm precedência. Configuração parcial ou caminho inexistente é
rejeitado. Não forneça senhas no histórico do terminal nem as publique.
Nenhuma chave é gerada pelo projeto. Em `android`, execute
`gradlew.bat validateProductionSigning` antes de distribuir.

O applicationId existente foi preservado para não separar instalações/dados.
Antes de publicar, defina a identidade definitiva, proteja a chave e prepare
a migração de instalações de teste: uma assinatura de produção diferente não
atualiza diretamente um APK assinado com a chave de debug. A ausência de
credenciais permanece uma pendência manual de publicação.

## Avisos e limitações mantidos

- Os ícones quadrados atuais podem gerar cinco avisos `IconLauncherShape`.
  Sua identidade visual foi preservada; adaptar a silhueta é uma decisão de design.
- O `SharedPreferences.commit()` dos lembretes é intencional: seu resultado
  booleano detecta falha de gravação. A extensão KTX sugerida retorna `Unit`,
  por isso não substitui essa checagem; um aviso `UseKtx` pode permanecer.
- O erro intermitente de atlas de texto do Impeller não tem gatilho confirmado.
  Não se desativou o motor permanentemente. Para investigar, registre percurso,
  tema/escala e logs do processo. A comparação Skia/Impeller anterior não prova
  que o driver seja a causa. Testes sem falha não equivalem a uma correção do motor.
- Arquitetura: serviços de backup, leitura limitada, análise CSV, dinheiro,
  datas e política de lembretes foram separados. A interface principal ainda
  é extensa; extrações futuras devem ser graduais e acompanhadas por testes.
- Alarme inexato pode atrasar em economia de bateria. Testes JVM não substituem
  validação de reboot, permissões e política de bateria no aparelho.

## Higiene do repositório

Não versione bancos, backups, chaves, senhas, builds ou logs. Use `.qa/` para
diagnósticos locais, `coverage/` para LCOV e `build/` para artefatos. Todos são
ignorados. Remova descartáveis individualmente; não use `git clean -fdx`.
Preserve `pubspec.lock`, migrações e testes. Os antigos relatórios de execução
na raiz foram substituídos por esta documentação de manutenção.

Referências oficiais: [Material UI](https://docs.flutter.dev/release/breaking-changes/material-ui-and-cupertino-ui),
[assinatura Android](https://developer.android.com/studio/publish/app-signing),
[backup Android](https://developer.android.com/identity/data/autobackup),
[Impeller](https://docs.flutter.dev/perf/impeller).
