param(
  [switch]$Apply,
  [string]$Source,
  [string]$Destination = (Join-Path $HOME ".codex\plugins\sources\openai-bundled-fixed")
)

$ErrorActionPreference = "Stop"

function Write-Step {
  param([string]$Message)
  Write-Host ""
  Write-Host "==> $Message" -ForegroundColor Cyan
}

function Invoke-CommandChecked {
  param([string[]]$Command)

  Write-Host ("$ " + ($Command -join " "))
  if ($Apply) {
    & $Command[0] @($Command | Select-Object -Skip 1)
    if ($LASTEXITCODE -ne 0) {
      throw "Command failed with exit code ${LASTEXITCODE}: $($Command -join ' ')"
    }
  }
}

function Find-OpenAIBundledSource {
  if ($Source) {
    $resolved = Resolve-Path -LiteralPath $Source -ErrorAction Stop
    return $resolved.Path
  }

  $processPath = Get-Process Codex -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty Path -First 1

  $candidateRoots = @()
  if ($processPath) {
    $dir = Split-Path -Parent $processPath
    while ($dir -and (Test-Path -LiteralPath $dir)) {
      $candidateRoots += $dir
      $parent = Split-Path -Parent $dir
      if ($parent -eq $dir) { break }
      $dir = $parent
    }
  }

  $candidateRoots += @(
    (Join-Path $env:LOCALAPPDATA "Programs"),
    "C:\Program Files",
    "C:\Program Files (x86)",
    "C:\WindowsApps",
    "D:\WindowsApps"
  )

  foreach ($root in ($candidateRoots | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique)) {
    $direct = Join-Path $root "app\resources\plugins\openai-bundled"
    if (Test-Path -LiteralPath $direct) {
      return (Resolve-Path -LiteralPath $direct).Path
    }

    $found = Get-ChildItem -LiteralPath $root -Recurse -Directory -Filter "openai-bundled" -ErrorAction SilentlyContinue |
      Where-Object { $_.FullName -like "*app\resources\plugins\openai-bundled" } |
      Select-Object -ExpandProperty FullName -First 1

    if ($found) {
      return (Resolve-Path -LiteralPath $found).Path
    }
  }

  throw "Could not find app\resources\plugins\openai-bundled. Pass -Source with the full path."
}

Write-Step "Checking Codex CLI"
$codex = Get-Command codex -ErrorAction Stop
Write-Host "Codex CLI: $($codex.Source)"
Invoke-CommandChecked @("codex", "plugin", "--help")

Write-Step "Locating bundled openai-bundled plugin source"
$src = Find-OpenAIBundledSource
Write-Host "Source: $src"
Write-Host "Destination: $Destination"

Write-Step "Backing up Codex config/state"
$backup = Join-Path $HOME ".codex\backups\plugin-repair-$(Get-Date -Format yyyyMMdd-HHmmss)"
Write-Host "Backup: $backup"
if ($Apply) {
  New-Item -ItemType Directory -Force $backup | Out-Null
  Copy-Item (Join-Path $HOME ".codex\config.toml") $backup -Force -ErrorAction SilentlyContinue
  Copy-Item (Join-Path $HOME ".codex\codex-global-state.json") $backup -Force -ErrorAction SilentlyContinue
}

Write-Step "Mirroring source outside protected WindowsApps storage"
if ($Apply) {
  if (Test-Path -LiteralPath $Destination) {
    Remove-Item -LiteralPath $Destination -Recurse -Force
  }
  New-Item -ItemType Directory -Force $Destination | Out-Null

  Get-ChildItem -LiteralPath $src -Recurse -Directory | ForEach-Object {
    $relative = $_.FullName.Substring($src.Length).TrimStart("\")
    New-Item -ItemType Directory -Force (Join-Path $Destination $relative) | Out-Null
  }

  Get-ChildItem -LiteralPath $src -Recurse -File | ForEach-Object {
    $relative = $_.FullName.Substring($src.Length).TrimStart("\")
    $target = Join-Path $Destination $relative
    New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
    [IO.File]::WriteAllBytes($target, [IO.File]::ReadAllBytes($_.FullName))
  }
} else {
  Write-Host "Dry run only. Pass -Apply to copy files."
}

Write-Step "Registering marketplace and installing plugins"
Invoke-CommandChecked @("codex", "plugin", "marketplace", "remove", "openai-bundled")
Invoke-CommandChecked @("codex", "plugin", "marketplace", "add", $Destination)
Invoke-CommandChecked @("codex", "plugin", "add", "chrome@openai-bundled")
Invoke-CommandChecked @("codex", "plugin", "add", "computer-use@openai-bundled")

Write-Step "Verifying marketplace"
if ($Apply) {
  codex plugin list --marketplace openai-bundled
  Write-Host ""
  Write-Host "Restart Codex Desktop, then confirm Chrome / Computer Use appear in Settings." -ForegroundColor Green
} else {
  Write-Host "Dry run complete. Rerun with -Apply to repair."
}
