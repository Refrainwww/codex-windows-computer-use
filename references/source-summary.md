# Source Summary

Reference: <https://www.autoxb.com/article/112216>

The article describes a Windows Codex Desktop issue where Computer Use does not appear or remains unavailable after updates. The root cause is usually an incomplete `openai-bundled` plugin marketplace registration plus protected app package files under `WindowsApps`, which can produce `os error 6000` when Codex tries to install directly from the packaged source.

The documented repair is:

1. Back up `~/.codex/config.toml` and `~/.codex/codex-global-state.json`.
2. Find the Codex Desktop app package path and its `app/resources/plugins/openai-bundled` directory.
3. Copy the bundled plugin source into a normal user-writable path such as `~/.codex/plugins/sources/openai-bundled-fixed`.
4. Register that copied directory as the `openai-bundled` marketplace.
5. Install `chrome@openai-bundled` and `computer-use@openai-bundled`.
6. Verify with `codex plugin list --marketplace openai-bundled`, then restart Codex Desktop.
