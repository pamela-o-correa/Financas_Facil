$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$metadata = Join-Path $projectRoot '.flutter-plugins-dependencies'
if (-not (Test-Path -LiteralPath $metadata)) {
    throw 'Execute flutter pub get uma vez para gerar a lista de plugins.'
}
$plugins = Get-Content -LiteralPath $metadata -Raw | ConvertFrom-Json
foreach ($platform in @('windows', 'linux')) {
    $links = Join-Path $projectRoot "$platform\flutter\ephemeral\.plugin_symlinks"
    if (-not (Test-Path -LiteralPath (Join-Path $projectRoot $platform))) { continue }
    New-Item -ItemType Directory -Path $links -Force | Out-Null
    foreach ($plugin in $plugins.plugins.$platform) {
        if ($plugin.name -notmatch '^[a-z0-9_]+$') { throw 'Nome de plugin invalido.' }
        $destination = [IO.Path]::GetFullPath((Join-Path $links $plugin.name))
        if (-not $destination.StartsWith($projectRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Destino fora do projeto.'
        }
        $target = [IO.Path]::GetFullPath($plugin.path)
        if (-not (Test-Path -LiteralPath $target -PathType Container)) { throw 'Plugin ausente no cache.' }
        # Juncoes locais dispensam alterar a politica de seguranca do Windows.
        # Nenhum destino e apagado, movido ou sobrescrito.
        if (-not (Test-Path -LiteralPath $destination)) {
            New-Item -ItemType Junction -Path $destination -Value $target | Out-Null
        }
    }
}
Write-Output 'Juncoes locais verificadas. Execute flutter pub get novamente.'
