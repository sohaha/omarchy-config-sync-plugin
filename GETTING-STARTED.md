# 首次配置

本指南带你从一台全新的 Omarchy 机器开始，建立一个保存桌面配置的**私有** GitHub 仓库——快捷键、栏布局、插件、钩子与终端文件——让下一台机器可以一键套用同样的配置。

这件事只需要做**一次**。之后托盘图标就是「应用 / 发布」。

---

## 为什么仓库必须是私有的

这个插件同步的是你自己的文件，不是主题包。其中可能包含：

- 个人键位绑定与菜单自定义
- `~/.local/bin` 下的辅助脚本
- 开机或更新后运行的自动化钩子
- 能识别你身份的主机名、显示名称与路径

**公开**的 GitHub 仓库会被爬取、fork 和搜索。请让配置仓库保持 **Private**。你仍然可以在自己拥有的每台机器上克隆它。从私有起步是安全的默认选择；以后真想公开再改也不迟。

本插件自身的源码（`omarchy-config-sync-plugin`）保持公开即可——它和存放配置的仓库不是同一个。

---

## 你将创建什么

| 仓库 | 可见性 | 用途 |
| --- | --- | --- |
| `omarchy-config`（名字可自取） | **Private** | 你的 Hyprland + Omarchy 文件 |
| 本插件 | 公开即可 | 与该私有仓库通信的托盘应用 |

一个空的私有仓库就够了。**不需要**手工复制文件，插件会从本机初始化它。

---

## 第 1 步 —— 创建空的私有 GitHub 仓库

1. 登录 GitHub，打开 **[github.com/new](https://github.com/new)**。
2. **Repository name:** `omarchy-config`（或任何你记得住的名字）。
3. **Visibility:** 选择 **Private**，不要留在 Public。
4. **Initialize this repository:** README、.gitignore、license 全部**不要勾选**。空仓库最理想；只有 README 的仓库也可以。
5. 点击 **Create repository**。
6. 在下一页复制克隆 URL：
   - HTTPS：`https://github.com/<you>/omarchy-config.git`
   - SSH：`git@github.com:<you>/omarchy-config.git`

记下这个 URL，稍后粘贴进插件。

---

## 第 2 步 —— 让本机可以访问 GitHub（不出现密码提示）

插件永远不会弹出用户名/密码输入框——弹窗会卡死状态栏，所以 git 被告知不要询问。请先**在终端里**配好凭据。

**最简单（HTTPS）：**

```bash
gh auth login
```

选择 GitHub.com → HTTPS → 用浏览器登录。这会保存一个 git 可用的 token。

**或者用 SSH：** 生成密钥，在 GitHub → Settings → SSH and GPG keys 中添加，并使用 `git@github.com:…` 形式的 URL。

**验证是否可用：**

```bash
git ls-remote https://github.com/<you>/omarchy-config.git
```

空仓库不会有任何输出并以 0 退出。如果报认证错误，先解决第 2 步再打开面板。

---

## 第 3 步 —— 安装配置同步（如果还没在栏上）

```bash
omarchy plugin add https://github.com/gladimdim/omarchy-config-sync-plugin --enable --yes
```

你应该能在 Omarchy 栏右侧看到云同步图标。如果没有：

```bash
omarchy plugin enable gladimdim.config-sync --section right
omarchy-shell shell rescanPlugins
```

---

## 第 4 步 —— 链接空仓库

1. 点击**云同步**图标。
2. 你会看到简短的引导：*创建私有仓库，然后粘贴 URL*。
3. 可选：如果跳过了第 1 步，「打开 GitHub」会直接打开 `github.com/new`。
4. 把第 1 步的 URL 粘贴进输入框。
5. 点击「连接仓库」。

插件会克隆仓库、发现它是空的，并**暂时不应用任何内容**。标题会显示**空仓库 — 从本机初始化**，概览标签页会出现一张高亮的**首次推送**卡片；快捷键、插件、配置标签页显示的是**本机**内容——也就是将要上传的东西，「变更」标签页的传出行也会列出**本机**。

如果克隆因认证消息失败，回到第 2 步。

---

## 第 5 步 —— 检查，然后发布

这是桌面布局上传到 GitHub 之前最后一次「确认无误？」。

打开**审查列表**（或「变更」标签页）并展开**传出行**，其中包含：

- **快捷键** —— 来自 `hypr/bindings.lua` 的绑定
- **插件** —— git 管理的插件以列表（`plugins.json`）形式传输；手工复制的以文件传输。本插件自身永远不会被包含
- **配置** —— Hyprland 文件、`shell.json`、钩子、终端以及当前主题（跳过图片和视频壁纸）

**本机专属文件**保留在本机：显示器布局（`hypr/monitors.lua`）以及 `.omarchy-config.json` 中 `machine_local` 列出的路径。`hypr/` 下名为 `*.local.lua` / `local.conf` 的覆盖文件完全不会同步。只有确认需要时，才在「变更」标签页打开「包含本机专属文件」。

内置目录之外的**额外配置文件**，可以在 `.omarchy-config.json` 的 `sync_paths` 中以 `repo` `↔` `local` 对的形式同步（见 [README.md](README.md)）。它们显示在「变更」标签页的**其他配置**下；`local` 必须位于 `$HOME` 内。

确认无误后，在概览卡片上点击**发布本机（N 项）**并确认。插件会把这些文件复制进私有仓库、提交并推送。

此时你的 GitHub 仓库应该包含 `hypr/`、`omarchy/`、`plugins/` 等——仍然是**私有**的。

---

## 第 6 步 —— 下一台机器

在新的 Omarchy 机器上：

1. 重复第 2 步（GitHub 认证）和第 3 步（安装插件）。
2. 点击图标，粘贴**同一个**私有仓库 URL，连接。
3. 这次仓库**不是**空的。检查传入的快捷键与插件。
4. 点击「应用」（不是发布）。会先写入带时间戳的备份到 `~/.config/omarchy-backup.*`。

之后的日常：

角标亮起时，「查看变更」（或按 `c`）会打开一份清单。你可以只应用或发布部分快捷键、某些插件、当前**主题**或部分配置文件；未勾选的项在该机器上保持原样。

当前 Omarchy 主题（`omarchy theme current`）也在清单里。官方主题只需同步名字。如果你在 `~/.config/omarchy/themes/<slug>/` 下自定义过主题，那些覆盖文件也会同步（壁纸与预览图会跳过以保持仓库小巧）。应用时会在另一台机器上执行 `omarchy theme set`。

两台机器需要**相同版本的配置同步插件**（「概览」会显示 `Plugin: config-sync` 加上 `manifest.json` 里的版本）。传入/传出分组、包含勾选框、重新同步等能力都取决于版本。更新用 `omarchy plugin update gladimdim.config-sync --yes`，或从已有当前版本的机器上复制 `~/.config/omarchy/plugins/gladimdim.config-sync/`，然后 `omarchy restart shell`。卸载插件也会忘掉已链接的仓库，重装后从「连接」重新开始。

| 你做了 | 打开图标会看到 | 按 |
| --- | --- | --- |
| 在本机添加了快捷键 / 插件 | 角标：本机有变更 | **发布** |
| 从另一台机器发布了 | 角标：有传入更新 | **应用** |
| 两台机器改了同一个文件 | 变更 → 两侧 | 保留本机或采用仓库，然后应用/发布 |

---

## 出问题了怎么办

**「git 无法通过远程认证」**  
状态栏不会向你询问密码。在终端运行 `gh auth login` 或修好 SSH，然后点击刷新（右键图标，或面板内按 `r`）。

**仓库被误建成 Public**  
GitHub → 该仓库 → Settings → Danger Zone → Change repository visibility → Private。尽量在第一次发布之前改掉。

**连接时提示不是 Omarchy 配置仓库**  
你指向了错误的 git URL（本插件仓库、别的项目或无关的非空树）。创建一个**新的空私有**仓库，改用它。

**我已经有 `~/Github/omarchy-config`**  
在设置界面用「使用本机的克隆」即可，不必再建第二个 GitHub 仓库。该文件夹必须已经是你的配置的 git 检出。

**密钥**  
不要把 API token、`.env` 文件或私钥放进同步树。如果某个钩子需要密钥，让它从仓库之外、只存在于本机的文件中读取。

---

## 设置过程中的快捷键

| 按键 | 作用 |
| --- | --- |
| URL 输入框中回车 | 连接 |
| `r` | 刷新 |
| `p` | 发布（初始化或后续更新） |
| `a` | 应用（第二台机器） |
| `Esc` | 关闭面板 |
