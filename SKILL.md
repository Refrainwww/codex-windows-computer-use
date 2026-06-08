---
name: codex-windows-computer-use
description: Set up, diagnose, or repair Codex Desktop Computer Use on Windows. Use when Codex on Windows cannot show or use the Chrome / Computer Use plugins, reports os error 6000 from WindowsApps-protected plugin files, has a missing or broken openai-bundled marketplace, needs chrome@openai-bundled or computer-use@openai-bundled installed and enabled, or needs the bundled plugin source mirrored into the user Codex plugin cache.
---

# Codex Windows Computer Use

## Overview

Use this skill to restore Codex Desktop Computer Use support on Windows when the UI says the plugin is unavailable or the plugin marketplace/cache is incomplete.

The common failure mode is:

- `openai-bundled` is not registered correctly in the Codex plugin marketplace.
- `chrome@openai-bundled` or `computer-use@openai-bundled` is not installed and enabled.
- The Codex app package lives under `WindowsApps`, where protected files can trigger `os error 6000` if installed directly.
- The fix is to mirror `app/resources/plugins/openai-bundled` into the user's Codex directory, register that mirror as the marketplace, then install the Chrome and Computer Use plugins.

## Quick Workflow

1. Inspect the current state:

   ```powershell
   codex plugin marketplace list
   codex plugin list --marketplace openai-bundled
   codex plugin list
   ```

2. Prefer the bundled repair script for the standard WindowsApps problem:

   ```powershell
   powershell -ExecutionPolicy Bypass -File <skill>/scripts/repair-codex-windows-computer-use.ps1
   ```

   Review the printed plan. To apply changes:

   ```powershell
   powershell -ExecutionPolicy Bypass -File <skill>/scripts/repair-codex-windows-computer-use.ps1 -Apply
   ```

3. Restart Codex Desktop after a successful repair.

4. Verify that both plugins are listed as installed and enabled:

   ```powershell
   codex plugin list --marketplace openai-bundled
   ```

## Manual Repair

Use the manual path when the script cannot locate the Codex Desktop executable or when a user provides a custom install path.

Back up user Codex state:

```powershell
$backup = Join-Path $HOME ".codex\backups\plugin-repair-$(Get-Date -Format yyyyMMdd-HHmmss)"
New-Item -ItemType Directory -Force $backup | Out-Null
Copy-Item (Join-Path $HOME ".codex\config.toml") $backup -Force -ErrorAction SilentlyContinue
Copy-Item (Join-Path $HOME ".codex\codex-global-state.json") $backup -Force -ErrorAction SilentlyContinue
```

Find the bundled plugin source:

```powershell
Get-Process Codex -ErrorAction SilentlyContinue | Select-Object Path
```

From the Codex app directory, locate:

```text
app\resources\plugins\openai-bundled
```

Mirror that directory outside `WindowsApps`:

```powershell
$src = "D:\WindowsApps\OpenAI.Codex_<version>\app\resources\plugins\openai-bundled"
$dst = Join-Path $HOME ".codex\plugins\sources\openai-bundled-fixed"

New-Item -ItemType Directory -Force $dst | Out-Null
Get-ChildItem $src -Recurse -Directory | ForEach-Object {
  $relative = $_.FullName.Substring($src.Length).TrimStart('\')
  New-Item -ItemType Directory -Force (Join-Path $dst $relative) | Out-Null
}
Get-ChildItem $src -Recurse -File | ForEach-Object {
  $relative = $_.FullName.Substring($src.Length).TrimStart('\')
  $target = Join-Path $dst $relative
  New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
  [IO.File]::WriteAllBytes($target, [IO.File]::ReadAllBytes($_.FullName))
}
```

Register the mirrored marketplace and install the plugins:

```powershell
codex plugin marketplace remove openai-bundled
codex plugin marketplace add $dst
codex plugin add chrome@openai-bundled
codex plugin add computer-use@openai-bundled
```

## Validation Checklist

- `codex plugin list --marketplace openai-bundled` includes `chrome@openai-bundled`.
- `codex plugin list --marketplace openai-bundled` includes `computer-use@openai-bundled`.
- The installed plugin cache contains Chrome files such as `scripts/browser-client.mjs` and `extension-host.exe`.
- Codex Desktop has been restarted after repair.
- The Codex settings UI shows Chrome / Computer Use as available.

## Notes

- Do not try to fix `os error 6000` by changing permissions on `WindowsApps`.
- Prefer copying with byte APIs (`[IO.File]::ReadAllBytes` / `WriteAllBytes`) when mirroring protected app package files.
- If plugin commands fail because the CLI is too old or missing plugin support, update Codex Desktop first, then rerun the workflow.
- Source workflow reference: <https://www.autoxb.com/article/112216>
