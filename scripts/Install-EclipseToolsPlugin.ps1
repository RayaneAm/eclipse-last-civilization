[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$projectPath = Join-Path $repoRoot "plugin.project.json"
$pluginDirectory = Join-Path $env:LOCALAPPDATA "Roblox\Plugins"
$pluginPath = Join-Path $pluginDirectory "EclipseWorldBuilder.rbxm"
$temporaryBuild = Join-Path ([System.IO.Path]::GetTempPath()) ("EclipseWorldBuilder.{0}.rbxm" -f [guid]::NewGuid())

$rojoCommand = Get-Command rojo -ErrorAction SilentlyContinue
if (-not $rojoCommand) {
    throw "Rojo was not found on PATH. Install/activate Rojo before installing ECLIPSE TOOLS."
}

try {
    Write-Host "[ECLIPSE TOOLS] Building plugin from $projectPath"
    & $rojoCommand.Source build $projectPath --output $temporaryBuild
    if ($LASTEXITCODE -ne 0) {
        throw "Rojo plugin build failed with exit code $LASTEXITCODE."
    }
    if (-not (Test-Path -LiteralPath $temporaryBuild) -or (Get-Item -LiteralPath $temporaryBuild).Length -eq 0) {
        throw "Rojo did not produce a valid plugin model."
    }

    New-Item -ItemType Directory -Path $pluginDirectory -Force | Out-Null
    Copy-Item -LiteralPath $temporaryBuild -Destination $pluginPath -Force
    Write-Host "[ECLIPSE TOOLS] Installed only: $pluginPath"
    Write-Host "[ECLIPSE TOOLS] Restart Studio once to load this newly installed plugin. Future world-source edits do not require restarts."
}
finally {
    if (Test-Path -LiteralPath $temporaryBuild) {
        Remove-Item -LiteralPath $temporaryBuild -Force
    }
}
