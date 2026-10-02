#!/usr/bin/env python3
"""Apply exact-literal Chinese translations to scripts/config_sync.py.

Matches Python string tokens in order: triple-double, triple-single,
double, single — so quote chars inside other literals can't misalign.
Only double-quoted literals whose content is in MAP are replaced.
"""
import re
from pathlib import Path

PATH = Path("/home/nm/Code/omarchy-config-sync-plugin/scripts/config_sync.py")

MAP = {
    "Already up to date with origin.": "已与 origin 保持同步。",
    "Bar transparency": "顶栏透明度",
    "Border": "边框",
    "Corners": "圆角",
    "Custom theme files": "自定义主题文件",
    "Dock Bar": "顶栏",
    "Dry run: nothing to publish.": "试运行：没有可发布的内容。",
    "Display layout (machine-specific)": "显示器布局（本机专属）",
    "Font": "字体",
    "Font base-size": "字体基准大小",
    "Font size": "字体大小",
    "Gaps": "间距",
    "Idle Lock": "闲置锁定",
    "Invalid theme slug": "无效的主题标识",
    "Keyboard": "键盘",
    "Menu extension": "菜单扩展",
    "Menu extensions": "菜单扩展",
    "Natural scroll": "自然滚动",
    "Night light": "夜光",
    "Omarchy config marker": "Omarchy 配置标记",
    "Omarchy config-sync backend": "Omarchy 配置同步后端",
    "Omarchy setting": "Omarchy 设置",
    "Tap-to-click": "轻触点击",
    "Terminal config": "终端配置",
    "terminal configs": "终端配置",
    "Unbound default": "默认解绑",
    "Workspace overview": "工作区概览",
    "Workspaces and window rules": "工作区与窗口规则",
    " widgets": " 小组件",
    "exceeds size cap": "超出大小上限",
    "new in repo": "仓库新增",
    "new on this machine": "本机新增",
    "not a portable binding": "不可移植的绑定",
    "not a regular file": "不是常规文件",
    "not found": "未找到",
    "local (ours)": "本机（ours）",
    "incoming (theirs)": "传入（theirs）",
    "config marker file": "配置标记文件",
    "apply/sync scripts": "apply/sync 脚本",
    "Remote repository was not found. Check the URL and that this machine can access it.":
        "找不到远程仓库。请检查 URL 以及本机是否有访问权限。",
    "references a local defined elsewhere in the file": "引用了文件中其他位置定义的 local",
    "command is not self-contained": "命令不是自包含的",
    "Make this machine match the repo, or publish this machine over the repo.":
        "让本机与仓库一致，或将本机发布覆盖到仓库。",
    "Merge conflicts. Keep local (ours) or take incoming (theirs) for each file.":
        "合并冲突。请为每个文件选择保留本机（ours）或采用传入（theirs）。",
    "No config repo is linked yet. Paste a git URL to get started.":
        "尚未链接配置仓库，粘贴 git URL 开始使用。",
    "No path provided to open.": "未提供要打开的路径。",
    "No path provided to open in terminal.": "未提供要在终端中打开的路径。",
    "Nothing from the repo to apply. This machine may already match.":
        "仓库没有可应用的内容，本机可能已是最新。",
    "Nothing local to publish.": "本机没有可发布的内容。",
    "Nothing new to commit, and push failed: ": "没有新内容可提交，且推送失败：",
    "Nothing to apply.": "没有可应用的内容。",
    "Nothing to publish.": "没有可发布的内容。",
    "\\n[output truncated: process exceeded its output limit and was stopped]":
        "\\n[输出已截断：进程超出输出限制并停止]",
    "\\n… truncated": "\\n… 已截断",
    "omarchy CLI not found; theme name was copied but not applied":
        "未找到 omarchy CLI；主题名已复制但未应用",
    "Side must be ours/local or theirs/repo.": "side 必须是 ours/local 或 theirs/repo。",
    "Some files changed on both this machine and the repo. Pick Keep local or Take repo for each, then Apply.":
        "部分文件在本机与仓库都有改动。请逐项选择「保留本机」或「采用仓库」，然后应用。",
    "Some files changed on both this machine and the repo. Pick Keep local or Take repo for each, then Publish.":
        "部分文件在本机与仓库都有改动。请逐项选择「保留本机」或「采用仓库」，然后发布。",
    "Sync response exceeded the maximum size (5MB); the repo has too much changed data to display safely.":
        "同步响应超出大小上限（5MB）；仓库变更过多，无法安全显示。",
    "That git repo is not an Omarchy config repo, and it is not empty either. ":
        "该 git 仓库不是 Omarchy 配置仓库，也不是空仓库。",
    "The clone has uncommitted changes, so origin could not be merged in. Open the clone and clean it up, then Apply.":
        "克隆中有未提交的改动，无法合并 origin。请打开克隆清理后再应用。",
    "The clone has uncommitted changes, so origin could not be merged in. Open the clone and clean it up, then Publish.":
        "克隆中有未提交的改动，无法合并 origin。请打开克隆清理后再发布。",
    "The git clone has merge conflicts. Resolve them before applying.":
        "git 克隆存在合并冲突，请先解决再应用。",
    "The git clone has merge conflicts. Resolve them before publishing.":
        "git 克隆存在合并冲突，请先解决再发布。",
    "this machine: {local_label} · repo: {repo_label}":
        "本机：{local_label} · 仓库：{repo_label}",
    "(this machine), then Publish to seed the repo. Keep it private.":
        "（本机），然后发布以初始化仓库。请保持私有。",
    "Unsafe characters in the credential store path.": "凭据存储路径包含不安全字符。",
    "Unknown command: {command}": "未知命令：{command}",
    "Use a private repo that is empty (to seed from this machine) or one that already ":
        "请使用空的私有仓库（从本机初始化），或已包含",
    "has hypr/ configs plus shell.json, plugins/, or apply.sh.":
        "hypr/ 配置及 shell.json、plugins/ 或 apply.sh 的仓库。",
    "Use https://github.com/you/omarchy-config.git or ~/Github/omarchy-config.":
        "例如 https://github.com/you/omarchy-config.git 或 ~/Github/omarchy-config。",
    "was: {local_label}": "原值：{local_label}",
    "repo has: {repo_label}": "仓库值：{repo_label}",
    "{what} selection totals {format_byte_limit(total)}, above the ":
        "{what} 所选合计 {format_byte_limit(total)}，超过",
    # f-strings / plurals (replace whole literal, drop the 's' plural trick)
    "Applied {len(applied)} file{'s' if len(applied) != 1 else ''} from the repo":
        "已从仓库应用 {len(applied)} 个文件",
    "Backup aborted: {src} grew past the size limit while it was being copied.":
        "备份已中止：{src} 在复制时超出了大小限制。",
    "Bar {path[2]}": "顶栏 {path[2]}",
    "Cannot create destination directory: {root / rel_parent}":
        "无法创建目标目录：{root / rel_parent}",
    "Cannot open destination directory: {root}": "无法打开目标目录：{root}",
    "Cannot open destination directory: {root / rel_parent}":
        "无法打开目标目录：{root / rel_parent}",
    "Custom config ({rel})": "自定义配置（{rel}）",
    "Custom theme files ({theme_display_name(slug)})":
        "自定义主题文件（{theme_display_name(slug)}）",
    "Dry run: would apply {len(applied)} file{'s' if len(applied) != 1 else ''}":
        "试运行：将应用 {len(applied)} 个文件",
    "Dry run: would publish {len(published)} file{'s' if len(published) != 1 else ''}":
        "试运行：将发布 {len(published)} 个文件",
    "{format_byte_limit(MAX_SYNC_TOTAL_BYTES)} per-operation size limit; select fewer files at a time.":
        "单次操作上限 {format_byte_limit(MAX_SYNC_TOTAL_BYTES)}，请减少一次勾选的文件数量。",
    "git {' '.join(args)} failed with exit {result.returncode}":
        "git {' '.join(args)} 失败，退出码 {result.returncode}",
    "git {' '.join(args)} timed out after {timeout}s":
        "git {' '.join(args)} 超时（{timeout} 秒）",
    "Hidden {len(keys)} item{'s' if len(keys) != 1 else ''}.":
        "已隐藏 {len(keys)} 项。",
    "{label}: local {old_val} vs repo {new_val}":
        "{label}：本机 {old_val} ↔ 仓库 {new_val}",
    "{label}: {old_val} (removed)": "{label}：{old_val}（已删除）",
    " (+{len(added)-2} more)": "（另有 +{len(added)-2} 条）",
    "{len(hypr_files)} Hyprland config files": "{len(hypr_files)} 个 Hyprland 配置文件",
    "{len(plugin_ids)} shell plugins": "{len(plugin_ids)} 个 shell 插件",
    " (-{len(removed)-2} more)": "（另有 -{len(removed)-2} 条）",
    " ({len(removed)} removed)": "（{len(removed)} 个已删除）",
    " ({len(removed)} removed from this machine)": "（{len(removed)} 个已从本机删除）",
    "Linked {clean_url}": "已链接 {clean_url}",
    "Linked repo has more than {MAX_INVENTORY_FILES} tracked files; ":
        "链接仓库的受跟踪文件超过 {MAX_INVENTORY_FILES} 个；",
    "Linked repo is missing on disk: {path}": "链接的仓库在磁盘上不存在：{path}",
    "Linked repo uses more than {format_byte_limit(MAX_REPO_DISK_BYTES)} on disk; ":
        "链接仓库磁盘占用超过 {format_byte_limit(MAX_REPO_DISK_BYTES)}；",
    "Missing source file: {src}": "源文件不存在：{src}",
    "New file ({len(lines)} lines)": "新文件（{len(lines)} 行）",
    "New on this machine · {n} file{'s' if n != 1 else ''}": "本机新增 · {n} 个文件",
    "New plugin · {n} file{'s' if n != 1 else ''}": "新插件 · {n} 个文件",
    "{n} file{'s' if n != 1 else ''}": "{n} 个文件",
    "{n} hook file{'s' if n != 1 else ''}": "{n} 个钩子文件",
    "\\n… {len(diff) - MAX_DIFF_LINES} more lines":
        "\\n… 省略 {len(diff) - MAX_DIFF_LINES} 行",
    "\\n- … {len(published) - 30} more": "\\n- … 其余 {len(published) - 30} 项",
    "Not a directory: {path}": "不是目录：{path}",
    "Not a local path, and not a git URL: {sanitize_url(src)}. ":
        "既不是本地路径也不是 git URL：{sanitize_url(src)}。",
    "\\n[repository exceeded its {format_byte_limit(max_disk_bytes or 0)} on-disk budget and was stopped]":
        "\\n[仓库超出磁盘限额 {format_byte_limit(max_disk_bytes or 0)}，已停止]",
    "Omarchy config-sync backup of {copied} files at {now_iso()}\\n":
        "Omarchy 配置同步备份：{now_iso()} 共 {copied} 个文件\\n",
    "omarchy theme set {slug} failed": "omarchy theme set {slug} 执行失败",
    "omarchy theme set {slug} timed out": "omarchy theme set {slug} 超时",
    "Origin set to {clean_url}": "origin 已设为 {clean_url}",
    "Plugin {name}": "插件 {name}",
    "Plugin updates · {n} file{'s' if n != 1 else ''}": "插件更新 · {n} 个文件",
    "Published {len(published)} file{'s' if len(published) != 1 else ''} to the repo":
        "已发布 {len(published)} 个文件到仓库",
    "Refusing to copy non-regular file: {src}": "拒绝复制非常规文件：{src}",
    "Refusing to copy oversized file: {src}": "拒绝复制超限文件：{src}",
    "Refusing to copy {src}: it grew past the size limit during the copy.":
        "拒绝复制 {src}：复制过程中超出大小限制。",
    "Refusing to copy symlink: {src}": "拒绝复制符号链接：{src}",
    " Skipped {n} shortcut{'s' if n != 1 else ''} ({reason}).":
        " 已跳过 {n} 个快捷键（{reason}）。",
    " · skipped — {skip_reason}": " · 已跳过 — {skip_reason}",
    "skipped — {skip_reason}": "已跳过 — {skip_reason}",
    "Sync config from {host}\\n\\n{listed}\\n": "同步 {host} 的配置\\n\\n{listed}\\n",
    " Theme set to {theme_display_name(slug)}.": " 主题已设置为 {theme_display_name(slug)}。",
    "Unhid all {count} item{'s' if count != 1 else ''}.": "已取消隐藏全部 {count} 项。",
    "Unhid {len(keys)} item{'s' if len(keys) != 1 else ''}.": "已取消隐藏 {len(keys)} 项。",
    "+{added_n}, -{removed_n} lines": "+{added_n}, -{removed_n} 行",
}

token_re = re.compile(
    r'"""(?:[^"\\]|\\.|"(?!""))*"""'      # triple-double
    r"|'''(?:[^'\\]|\\.|'(?!''))*'''"     # triple-single
    r'|"(?:[^"\\]|\\.)*"'                 # double
    r"|'(?:[^'\\]|\\.)*'",                # single
    re.DOTALL,
)

text = PATH.read_text(encoding="utf-8")
hits = {}

def repl(m: re.Match) -> str:
    tok = m.group(0)
    if tok.startswith('"') and not tok.startswith('"""'):
        lit = tok[1:-1]
        if lit in MAP:
            hits[lit] = hits.get(lit, 0) + 1
            return '"' + MAP[lit] + '"'
    return tok

text = token_re.sub(repl, text)
PATH.write_text(text, encoding="utf-8")
print(f"{sum(hits.values())} replacements")
for k in MAP:
    if k not in hits:
        print(f"MISS: {k!r}")
