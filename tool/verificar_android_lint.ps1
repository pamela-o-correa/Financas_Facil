param([string]$JdkPath = $env:JAVA_HOME)

$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
$androidPath = Join-Path $projectPath 'android'
$propertiesPath = Join-Path $androidPath 'local.properties'

if ([string]::IsNullOrWhiteSpace($JdkPath)) {
    $JdkPath = Join-Path $env:LOCALAPPDATA 'Android\jdk-17'
}
if (-not (Test-Path -LiteralPath (Join-Path $JdkPath 'bin\java.exe'))) {
    throw 'Informe um JDK instalado usando -JdkPath.'
}

# Flutter regenera estes caminhos sem escapar o separador da unidade Windows.
# Normaliza somente sdk.dir/flutter.sdk para o formato exigido pelo Android Lint.
# Os caminhos resolvidos e as demais propriedades permanecem iguais.
$properties = [System.IO.File]::ReadAllText($propertiesPath)
$normalized = [regex]::Replace(
    $properties, '(?m)^((?:flutter\.sdk|sdk\.dir)=[A-Za-z]):', '$1\:'
)
if ($normalized -cne $properties) {
    [System.IO.File]::WriteAllText(
        $propertiesPath, $normalized, [System.Text.UTF8Encoding]::new($false)
    )
}

$previousJavaHome = $env:JAVA_HOME
Push-Location $androidPath
try {
    $env:JAVA_HOME = $JdkPath
    # Recalcula a analise: local.properties nao invalida o cache do Lint.
    & .\gradlew.bat :app:lintAnalyzeDebug --rerun :app:lintDebug
    $lintExitCode = $LASTEXITCODE
} finally {
    $env:JAVA_HOME = $previousJavaHome
    Pop-Location
}
exit $lintExitCode
