# Codex Windows Computer Use Skill

这是一个给 Windows 版 Codex Desktop 使用的 Codex skill，用来诊断和修复 Chrome / Computer Use 插件不可用的问题。

它整理自这篇文章的流程：<https://www.autoxb.com/article/112216>

## 解决什么问题

当 Windows 上的 Codex Desktop 出现下面情况时，可以使用这个 skill：

- Codex 设置页里看不到 Chrome / Computer Use。
- Computer Use 显示不可用。
- `codex plugin list --marketplace openai-bundled` 找不到 `chrome@openai-bundled` 或 `computer-use@openai-bundled`。
- `openai-bundled` marketplace 没有正确注册。
- 从 `WindowsApps` 里的 Codex 应用包直接安装插件时报 `os error 6000`。
- 插件缓存不完整，例如 Chrome 插件缺少 `scripts/browser-client.mjs` 或 `extension-host.exe`。

常见根因是：Codex Desktop 自带的 `openai-bundled` 插件源没有正确进入 marketplace，而且 WindowsApps 目录下的应用包文件带有保护属性，直接读取或安装可能失败。这个 skill 会指导 Codex 将 bundled 插件源复制到用户目录，再注册这个镜像源并安装插件。

## 安装方式

### 方法一：复制到本地 skills 目录

在 PowerShell 中运行：

```powershell
git clone https://github.com/Refrainwww/codex-windows-computer-use.git "$HOME\.codex\skills\codex-windows-computer-use"
```

重启 Codex Desktop，或开启一个新的 Codex 对话，让 Codex 重新发现 skill。

### 方法二：手动下载

1. 打开仓库页面：<https://github.com/Refrainwww/codex-windows-computer-use>
2. 下载 ZIP。
3. 解压到：

   ```text
   %USERPROFILE%\.codex\skills\codex-windows-computer-use
   ```

4. 确认最终目录里能看到：

   ```text
   SKILL.md
   agents/openai.yaml
   scripts/repair-codex-windows-computer-use.ps1
   references/source-summary.md
   ```

## 在 Codex 里怎么用

安装后，在 Codex 中直接说类似下面的话：

```text
使用 codex-windows-computer-use 这个 skill，检查并修复这台 Windows 机器上的 Codex Desktop Computer Use 插件问题。
```

或者：

```text
我的 Windows Codex 看不到 Computer Use，帮我用 codex-windows-computer-use 修一下。
```

Codex 会读取 `SKILL.md`，按里面的流程先检查插件 marketplace 和插件安装状态，再决定是否运行修复脚本。

## 直接运行修复脚本

这个仓库自带 PowerShell 脚本：

```text
scripts/repair-codex-windows-computer-use.ps1
```

默认是 dry-run，只打印计划，不修改配置：

```powershell
powershell -ExecutionPolicy Bypass -File "$HOME\.codex\skills\codex-windows-computer-use\scripts\repair-codex-windows-computer-use.ps1"
```

确认输出没问题后，加 `-Apply` 真正执行修复：

```powershell
powershell -ExecutionPolicy Bypass -File "$HOME\.codex\skills\codex-windows-computer-use\scripts\repair-codex-windows-computer-use.ps1" -Apply
```

脚本会做这些事：

1. 检查 `codex` CLI 是否可用。
2. 寻找 Codex Desktop 自带的 `app\resources\plugins\openai-bundled`。
3. 备份 `~\.codex\config.toml` 和 `~\.codex\codex-global-state.json`。
4. 将 `openai-bundled` 插件源复制到：

   ```text
   %USERPROFILE%\.codex\plugins\sources\openai-bundled-fixed
   ```

5. 重新注册 marketplace：

   ```powershell
   codex plugin marketplace remove openai-bundled
   codex plugin marketplace add "$HOME\.codex\plugins\sources\openai-bundled-fixed"
   ```

6. 安装插件：

   ```powershell
   codex plugin add chrome@openai-bundled
   codex plugin add computer-use@openai-bundled
   ```

7. 打印验证结果。

## 指定 Codex bundled 插件源

如果脚本找不到 Codex Desktop 的安装位置，可以手动传入 `-Source`：

```powershell
powershell -ExecutionPolicy Bypass -File "$HOME\.codex\skills\codex-windows-computer-use\scripts\repair-codex-windows-computer-use.ps1" `
  -Source "C:\Program Files\WindowsApps\OpenAI.Codex_<version>_x64__2p2nqsd0c76g0\app\resources\plugins\openai-bundled" `
  -Apply
```

也可以自定义复制目标：

```powershell
powershell -ExecutionPolicy Bypass -File "$HOME\.codex\skills\codex-windows-computer-use\scripts\repair-codex-windows-computer-use.ps1" `
  -Destination "$HOME\.codex\plugins\sources\openai-bundled-fixed" `
  -Apply
```

## 验证是否修好

执行：

```powershell
codex plugin marketplace list
codex plugin list --marketplace openai-bundled
codex plugin list
```

你应该能看到：

```text
chrome@openai-bundled
computer-use@openai-bundled
```

并且它们处于 installed / enabled 状态。

之后重启 Codex Desktop，再去设置页确认 Chrome / Computer Use 是否可用。

## 常见问题

### 运行脚本前要不要关 Codex Desktop？

建议先关闭 Codex Desktop，再执行 `-Apply`。修复完成后重新打开 Codex Desktop。

### 为什么不直接改 WindowsApps 权限？

不要改。WindowsApps 是受保护的应用包目录，强行改权限容易带来额外问题。这个 skill 采用更稳妥的方式：把 bundled 插件源复制到用户目录，再让 Codex 使用这份镜像。

### 出现 `os error 6000` 怎么办？

这通常说明 Codex 正在直接读取受保护的应用包文件。使用本 skill 的修复流程，将 `openai-bundled` 复制到 `~\.codex\plugins\sources\openai-bundled-fixed` 后再注册 marketplace。

### `codex plugin` 命令不存在怎么办？

先更新 Codex Desktop。这个 skill 依赖 Codex CLI 的 plugin 子命令：

```powershell
codex plugin --help
```

如果这个命令不可用，说明当前 Codex 版本或 CLI 环境不满足要求。

### 修复后还是看不到 Computer Use 怎么办？

检查：

- 是否已经重启 Codex Desktop。
- `codex plugin list --marketplace openai-bundled` 是否能看到两个插件。
- 插件缓存里是否存在 Chrome 的 `scripts/browser-client.mjs` 和 `extension-host.exe`。
- Codex Desktop 是否是支持 Computer Use 的新版本。

## 仓库结构

```text
.
├── SKILL.md
├── agents/
│   └── openai.yaml
├── references/
│   └── source-summary.md
└── scripts/
    └── repair-codex-windows-computer-use.ps1
```

## 说明

这个 skill 会修改本机 Codex 的 plugin marketplace 和插件安装状态。脚本默认 dry-run，只有加 `-Apply` 才会执行修改。
