[![Built for Omarchy](https://raw.githubusercontent.com/tcballard/omarchy-badges/85f859029e236e784e7b05ada6dbe73506d07a91/badges/v1/built-for-omarchy.svg)](https://github.com/tcballard/omarchy-badges)

# Omarchy 配置同步（`gladimdim.config-sync`）

一个状态栏插件，通过私有 Git 仓库在你的多台机器之间无缝同步全部 Omarchy 配置、快捷键、主题与插件。

<p align="center">
  <img src="screenshot.png" alt="概览面板" width="270">
  &nbsp;
  <img src="screenshot-changes.png" alt="逐项审查变更" width="270">
  &nbsp;
  <img src="screenshot-configs.png" alt="按类别查看受跟踪配置" width="270">
</p>

**初次使用？** 请先阅读[首次配置指南](GETTING-STARTED.md)：创建一个空的**私有** GitHub 仓库，把 URL 粘贴到托盘图标里，检查本机内容，然后点击「发布本机」。请务必保持仓库私有，避免快捷键、钩子与脚本公开。

点击云同步托盘图标，粘贴配置仓库的 git URL，预览将落到本机的内容，然后点击「应用」。当你在本机新增快捷键或插件后，再次打开面板点击「发布」即可推送给下一台机器。

当出现差异时，「查看变更」会打开一份清单：传入与本机的**快捷键**（逐条按键绑定）、**插件**（整个插件）、**当前主题**以及其他配置文件。不想同步的取消勾选即可。「应用」与「发布」只处理勾选项。应用主题时会在本机执行 `omarchy theme set`。

## 功能特性

- **托盘图标**：位于 Omarchy 栏上；当本机与仓库出现差异时显示角标。
- **链接仓库**：支持 HTTPS、SSH、`owner/repo` 简写或本地 git 路径（例如 `~/Github/omarchy-config`）。
- **校验**：确认克隆确实是 Omarchy 配置树（`hypr/` 加 `omarchy/shell.json`、`plugins/` 或 `apply.sh`）。
- **应用前预览**：`hypr/bindings.lua` 中的快捷键、带版本的插件、栏布局、钩子、辅助脚本与终端配置。
- **应用**：仓库 → 本机（先写入带时间戳的备份到 `~/.config/omarchy-backup.<时间戳>/`），然后重载 Hyprland 并重新扫描 shell。即使传入的 `shell.json` 没有列出本插件，配置同步组件也会被保留在栏上。
- **发布**：本机 → 仓库，提交并推送，供下一台机器应用。
- **差异检测**：打开面板时（以及每 10 分钟）检测：仅本机的修改、仓库新增的文件、两侧都有改动的文件以及 git 合并冲突。
- **冲突处理**：对重叠改动逐文件选择「保留本机」/「采用仓库」；对 git 合并冲突选择「保留本机」/「采用传入」。显示器布局（`hypr/monitors.lua`）默认留在本机，除非你主动启用。

## 安装

```bash
omarchy plugin add https://github.com/gladimdim/omarchy-config-sync-plugin --enable --yes
```

从本地检出安装：

```bash
omarchy plugin add /home/$USER/Github/omarchy-config-sync-plugin --enable --yes
```

把它放到托盘旁边：

```bash
omarchy plugin enable gladimdim.config-sync --section right
```

## 第一台机器 vs 后续机器

| | 第一台机器 | 后续机器 |
| --- | --- | --- |
| GitHub 仓库 | 创建**空仓库 + 私有**（见 [GETTING-STARTED.md](GETTING-STARTED.md)） | 同一个 URL |
| 连接后 | 标签页显示**本机**内容 | 标签页显示**仓库**内容 |
| 主按钮 | **发布本机**（初始化并推送） | **应用**（先备份，再复制到本机） |

## 日常使用

1. **新机器** —— 点击图标，粘贴 `https://github.com/<you>/omarchy-config.git`（或本地克隆路径）。检查快捷键 / 插件 / 配置标签页，点击**应用**。
2. **本机有改动** —— 打开面板。角标与「变更」标签页会列出本机修改（新快捷键、插件等）。点击**发布**即可提交并推送。
3. **另一台机器发布了** —— 出现角标。打开面板，检查传入文件，点击**应用**。
4. **两侧改了同一个文件** —— 「变更」→「两侧均有改动」→ 对每个文件选择「保留本机」或「采用仓库」，然后再应用和/或发布。
5. **git 分叉**（两台机器都推送过而没先拉取）—— 点击**拉取**，解决未合并路径后继续。

状态保存在 `~/.local/share/omarchy-config-sync/`，因此应用 `shell.json` 不会断开仓库链接。卸载插件（`omarchy plugin remove gladimdim.config-sync`）会清除这些状态：重装后从「未链接」开始。面板中的「取消链接」效果相同但不删除插件。你直接指定的就地克隆（例如 `~/Github/omarchy-config`）永远不会被删除。

## 同步内容

| 仓库路径 | 本机位置 |
| --- | --- |
| `hypr/*.lua`、`hypr/*.conf` | `~/.config/hypr/` |
| `omarchy/shell.json` | `~/.config/omarchy/shell.json` |
| `omarchy/theme.name` | 当前主题（`omarchy theme set`）；`omarchy/themes/<slug>/` 下的自定义覆盖层（跳过图片） |
| `omarchy/{branding,extensions,hooks,agents}/` | `~/.config/omarchy/` 下同名目录 |
| `plugins.json` | 通过 git 安装的插件（`omarchy plugin add`）：id、版本、提交与来源 URL。绝不作为文件复制；见下文。 |
| `plugins/*` | `~/.config/omarchy/plugins/`，针对**非** git 检出的插件逐文件同步（跳过本插件；shebang/ELF 辅助程序保留执行位） |
| `bin/*` | `~/.local/bin/`（仓库中已有的脚本，以及被快捷键、钩子或插件引用的本机辅助程序） |
| `terminals/alacritty.toml` 等 | 对应的终端配置文件 |

### git 管理的插件

带有 `.git` 检出的插件目录在两个方向上都不会被复制，因此「应用」不会降级它，也不会让 `omarchy plugin update` 拒绝快进。相反，「发布本机」会把它记录到 `plugins.json`（来源 URL 中的凭据会被去除），在另一台机器上「变更」标签页会显示：

- 当列表中的插件缺失时显示**安装**。它会在浮动终端中打开 Omarchy 自带的插件安装器（`omarchy plugin add <source>`），让你看到 Omarchy 的警告并在那里确认。
- 当仓库列出了更新的版本或本检出未见过的提交时显示**更新**。它会打开 `omarchy plugin update <id>`，拉取插件的上游而不是配置仓库。
- 当本机领先，或你卸载了列表中的插件时显示一条传出行（默认不勾选）。

已经把 git 插件的文件副本放在 `plugins/<id>/` 下的仓库会停止应用这些文件。发布该插件的列表条目时会从仓库删除这些副本。没有 `.git` 的插件（你自己的或内置插件的克隆）仍会逐文件同步。

### 额外配置文件（`sync_paths`）

上述目录之外的内容也可以同步。在配置仓库的 `.omarchy-config.json` 中列出
仓库 `↔` 本机 的映射：

```json
{
  "format": "omarchy-config",
  "version": 1,
  "synced_by": "gladimdim.config-sync",
  "sync_paths": [
    { "repo": "configs/zkey", "local": "~/.config/zkey" },
    { "repo": "dotfiles/gitconfig", "local": "~/.gitconfig" }
  ]
}
```

- `repo` 是仓库内的相对文件或目录（范围尽量收窄；目录会在两侧递归遍历）。
- `local` 是绝对路径或以 `~/` 开头的路径。
- 每条映射会显示在「变更」标签页的**其他配置**分组下，应用 / 发布 /
  保留本机 / 采用仓库的行为与内置配置完全一致。
- 内置目录（`hypr/`、`omarchy/`、`plugins/`、`bin/`、`terminals/`）是保留的：
  映射不能覆盖它们，且 `local` 必须位于 `$HOME` 内。需要 root 权限的文件
  （例如 `/etc/keyd/default.conf`）仍需每台机器手动处理一次。

发布时插件会把 `sync_paths` 原样写进仓库，映射会跟随它所描述的配置一起传播。

本机专属文件**不会**被应用，除非你启用「包含本机专属文件」：

- `hypr/monitors.lua`（显示器布局）
- `.omarchy-config.json` 中 `machine_local` 列出的额外路径

按机器的 Hyprland 覆盖文件（`*.local.lua`、`local.conf`、`input.local.lua` 等）会被完全忽略，永远不会显示为传入项。插件文件如 `Local.qml` 仍会正常同步。夜光（`hypr/hyprsunset.conf`）保持可移植。

快捷键挑选每次只复制一条 `o.bind` / `o.rebind` / `hl.unbind`。命令是字符串、数字、`os.getenv(...)` 或 `hl.dsp.*` 时可移植。如果命令依赖 `bindings.lua` 中其他位置定义的 `local`（辅助函数、未定义的名字等），该快捷键会附带跳过原因列出，并**不会**被复制——直接应用会让另一台机器的 `require("hypr.bindings")` 中止。形如 `local snap = os.getenv("HOME") .. "/.local/bin/hypr-quarter-snap"` 的路径型 local 在发布时会被内联成自包含命令。这些绑定、钩子或插件引用的辅助脚本会列在**辅助脚本**下（`~/.local/bin` 的其余内容不受影响）。应用时会恢复插件 shebang 脚本与 ELF 二进制的执行位（`radio-fetch`、`scripts/audio-*` 等），以便 Qt/QML `Process` 能启动它们。主题脚本仍以不可执行方式落地。

## 快捷键

| 按键 | 作用 |
| --- | --- |
| 左键点击 | 打开/关闭面板 |
| 右键点击 | 刷新并拉取 |
| `1`–`5` 或 `←` `→` | 切换标签页 |
| `r` | 刷新 |
| `c` | 查看变更（逐项挑选） |
| `a` | 应用所选 |
| `p` | 发布所选 |
| `Esc` | 关闭 |

## 依赖

Omarchy 自带：`python3`、`git`。克隆/推送私有 GitHub 仓库需要 SSH 或 git 凭据助手。后端永远不会弹出密码提示（那会卡死状态栏），而是直接以消息形式失败。

## 开发

```bash
python3 -m unittest tests.test_config_sync -v
omarchy plugin validate .
```

面向最终用户的入门指南：[GETTING-STARTED.md](GETTING-STARTED.md)。

发布新版本 tag 后，需要针对确切的新 commit 重新验证 marketplace 列表。见 [AGENTS.md](AGENTS.md)。

## 许可证

MIT © 2026 Dmytro Gladkyi
