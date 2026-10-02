.pragma library

function repoName(url) {
  var raw = String(url || "").replace(/\/+$/, "")
  if (!raw) return "配置仓库"
  raw = raw.replace(/\.git$/, "")
  var slash = raw.lastIndexOf("/")
  if (slash !== -1) raw = raw.substring(slash + 1)
  var colon = raw.lastIndexOf(":")
  if (colon !== -1 && raw.indexOf("/") === -1) raw = raw.substring(colon + 1)
  return raw || "配置仓库"
}

function stateTitle(state) {
  switch (String(state || "")) {
    case "in-sync": return "已同步"
    case "ready": return "待应用"
    case "empty": return "空仓库 — 从本机初始化"
    case "local-ahead": return "本机有变更"
    case "remote-ahead": return "有传入更新"
    case "diverged": return "两侧均有改动"
    case "conflicts": return "合并冲突"
    case "invalid": return "不是 Omarchy 配置仓库"
    case "not-configured": return "未链接"
    default: return "Omarchy 配置同步"
  }
}

function stateHint(state, status) {
  var localN = status && status.local_changes ? Number(status.local_changes) : 0
  var repoN = status && status.repo_changes ? Number(status.repo_changes) : 0
  var bothN = status && status.both_changed ? Number(status.both_changed) : 0
  var differs = status && status.unknown_differs ? Number(status.unknown_differs) : 0
  switch (String(state || "")) {
    case "in-sync":
      return "本机与已链接的配置仓库一致。"
    case "empty":
      return "这个 GitHub 仓库是空的（或只有 README）。标签页显示本机内容。点击「发布本机」初始化私有仓库，然后在其他机器上使用「应用」。"
    case "ready":
      return "仓库内容是 Omarchy 配置。检查快捷键、插件与文件后点击「应用」同步到本机——若本机才是最新来源，则点「发布」。"
    case "local-ahead":
      return "本机有 " + localN + " 处变更尚未进入仓库，发布后其他机器即可同步。"
    case "remote-ahead":
      return "仓库中有本机尚未应用的配置，检查传入文件后点击「应用」。"
    case "diverged":
      return "本机与仓库都有改动。在「查看变更」中逐项选择保留哪一侧，或点「从仓库重新同步」让本机与 git 一致（第二台机器常用）。"
    case "conflicts":
      return "git 无法自动合并。请为每个冲突文件选择保留本机副本或采用传入副本。"
    case "invalid":
      return "链接的 git 仓库缺少 Hyprland / Omarchy 配置文件。"
    default:
      return "粘贴你的 omarchy-config 仓库 git URL 开始使用。"
  }
}

function fileStatusLabel(status, removal) {
  if (removal) {
    // The file is gone from one side. Syncing it deletes, it does not copy.
    switch (String(status || "")) {
      case "local":
      case "added-local": return "本机已删除"
      case "repo":
      case "added-repo": return "仓库已删除"
    }
  }
  switch (String(status || "")) {
    case "local": return "仅本机"
    case "added-local": return "本机新增"
    case "repo": return "传入"
    case "added-repo": return "仓库新增"
    case "both": return "两侧均已修改"
    case "differs": return "有差异"
    case "identical": return "已同步"
    case "machine": return "本机"
    default: return String(status || "")
  }
}

// Join a row's status label to its summary without saying the same thing twice.
// A bundle's summary comes from the backend already opening with its own status
// ("本机已删除 · 11 个文件"), so prefixing the label again renders as
// "本机已删除 · 本机已删除 · 11 个文件". A loose file's summary does not, and
// still wants the prefix.
function statusPrefix(statusLabel, summary) {
  var st = String(statusLabel || "")
  if (!st) return ""
  var sum = String(summary || "")
  // Nothing to separate the label from: return it bare rather than leaving a
  // dangling "本机已删除 · " on a row whose summary is empty.
  if (!sum) return st
  if (sum === st || sum.indexOf(st + " ") === 0) return ""
  return st + " · "
}

function filesByStatus(files, statuses) {
  var wanted = {}
  for (var i = 0; i < statuses.length; i++) wanted[statuses[i]] = true
  var out = []
  var list = files || []
  for (var j = 0; j < list.length; j++) {
    if (wanted[list[j].status]) out.push(list[j])
  }
  return out
}

function isBundledPath(path) {
  var p = String(path || "")
  return p.indexOf("plugins/") === 0
    || p.indexOf("omarchy/hooks/") === 0
    || p.indexOf("omarchy/agents/") === 0
    || p.indexOf("omarchy/branding/") === 0
    || p.indexOf("omarchy/extensions/") === 0
    || p.indexOf("bin/") === 0
}

function reviewItem(kind, id, label, summary, status, typeLabel, both, changedCount, hidden, changes) {
  return {
    kind: kind,
    itemId: String(id || ""),
    label: String(label || ""),
    summary: String(summary || ""),
    status: status,
    typeLabel: typeLabel || "",
    both: !!both || String(status) === "both",
    changed_count: changedCount || 0,
    hidden: !!hidden,
    removal: false,
    // Rows with an action (Install/Update) are buttons, not Apply/Publish picks.
    pickable: true,
    action: "",
    changes: changes || []
  }
}

function unbundledFiles(files) {
  var out = []
  var list = files || []
  for (var i = 0; i < list.length; i++) {
    if (!isBundledPath(list[i].path)) out.push(list[i])
  }
  return out
}

function itemsOfKind(items, kind) {
  var out = []
  var list = items || []
  for (var i = 0; i < list.length; i++) {
    if (list[i].kind === kind) out.push(list[i])
  }
  return out
}

function categorizePath(path) {
  var p = String(path || "")
  if (p === "hypr/bindings.lua") return "shortcuts"
  if (p === "hypr/monitors.lua") return "displays"
  if (p.indexOf("hypr/") === 0) return "hyprland"
  if (p === "omarchy/theme.name" || p.indexOf("omarchy/themes/") === 0) return "theme"
  if (p.indexOf("plugins/") === 0) return "plugins"
  if (p === "omarchy/shell.json") return "shell"
  if (p.indexOf("terminals/") === 0) return "terminals"
  if (p.indexOf("omarchy/hooks/") === 0) return "hooks"
  if (p.indexOf("bin/") === 0) return "scripts"
  return "other"
}

function itemCategory(item) {
  if (!item) return "other"
  if (item.kind === "s") return "shortcuts"
  if (item.kind === "t") return "theme"
  if (item.kind === "p" || item.kind === "l") return "plugins"
  if (item.kind === "g") {
    var id = String(item.itemId || "")
    if (id.indexOf("plugin:") === 0) return "plugins"
    if (id.indexOf("hooks:") === 0) return "hooks"
    if (id === "bin") return "scripts"
    return "other"
  }
  return categorizePath(item.itemId || item.path)
}

function itemsForCategory(items, cat) {
  var out = []
  var list = items || []
  for (var i = 0; i < list.length; i++) {
    if (itemCategory(list[i]) === cat) out.push(list[i])
  }
  return out
}

function filesForCategory(files, cat) {
  var out = []
  var list = files || []
  for (var i = 0; i < list.length; i++) {
    if (categorizePath(list[i].path) === cat) out.push(list[i])
  }
  return out
}

function pickedInItems(items, picks) {
  var n = 0
  var list = items || []
  var map = picks || {}
  for (var i = 0; i < list.length; i++) {
    if (list[i].pickable === false) continue
    if (map[list[i].kind + ":" + list[i].itemId]) n++
  }
  return n
}

function isItemHidden(kind, id, hiddenMap, item) {
  if (item && item.hidden) return true
  if (!hiddenMap) return false
  var key = kind + ":" + id
  if (hiddenMap[key] || hiddenMap[id]) return true
  if (kind === "f") {
    var p = String(id || "")
    if (p.indexOf("plugins/") === 0) {
      var pid = p.split("/")[1] || ""
      if (pid && (hiddenMap["g:plugin:" + pid] || hiddenMap["p:" + pid] || hiddenMap["plugin:" + pid])) return true
    }
    if (p.indexOf("omarchy/hooks/") === 0) {
      var parts = p.split("/")
      if (parts.length >= 3) {
        var ev = parts[2].replace(".d", "")
        if (hiddenMap["g:hooks:" + ev] || hiddenMap["hooks:" + ev]) return true
      }
    }
    if (p.indexOf("omarchy/agents/") === 0 && (hiddenMap["g:agents"] || hiddenMap["agents"])) return true
    if (p.indexOf("omarchy/branding/") === 0 && (hiddenMap["g:branding"] || hiddenMap["branding"])) return true
    if (p.indexOf("omarchy/extensions/") === 0 && (hiddenMap["g:extensions"] || hiddenMap["extensions"])) return true
    if (p.indexOf("bin/") === 0 && (hiddenMap["g:bin"] || hiddenMap["bin"])) return true
    if ((p === "omarchy/theme.name" || p.indexOf("omarchy/themes/") === 0) && (hiddenMap["t:selected"] || hiddenMap["t:theme"] || hiddenMap["theme"])) return true
  } else if (kind === "g") {
    var raw = String(id || "")
    if (raw.indexOf("plugin:") === 0) {
      var gpid = raw.substring(7)
      if (hiddenMap["p:" + gpid] || hiddenMap[gpid]) return true
    }
  } else if (kind === "p") {
    if (hiddenMap["g:plugin:" + id] || hiddenMap["plugin:" + id]) return true
  }
  return false
}

function hasVisibleShortcutDiffs(shortcuts, hiddenMap) {
  var list = shortcuts || []
  for (var i = 0; i < list.length; i++) {
    if (isItemHidden("s", list[i].keys, hiddenMap, list[i])) continue
    return true
  }
  return false
}

function appendThemes(out, list, hiddenMap) {
  var rows = list || []
  for (var i = 0; i < rows.length; i++) {
    var t = rows[i]
    var id = t.id || "selected"
    if (isItemHidden("t", id, hiddenMap, t)) continue
    out.push(reviewItem("t", id, t.display || t.slug, t.semantic_summary || t.slug, t.status, "主题", t.status === "both", 0, false, t.changes || []))
  }
}

function appendShortcuts(out, list, summaryField, both, hiddenMap) {
  var rows = list || []
  for (var i = 0; i < rows.length; i++) {
    var s = rows[i]
    if (isItemHidden("s", s.keys, hiddenMap, s)) continue
    var sum = (summaryField === "detail" || s.portable === false)
      ? (s.detail || s.skip_reason || s.label || "")
      : (s.label || "")
    var row = reviewItem("s", s.keys, s.keys, sum, s.status, "快捷键", both || s.status === "both", 0, false)
    // Non-portable binds depend on surrounding Lua declarations and cannot be
    // cherry-picked safely. Keep them visible as an explanation without
    // presenting an Include control that the backend would silently ignore.
    row.pickable = s.portable !== false
    out.push(row)
  }
}

function appendBundles(out, list, both, hiddenMap) {
  var rows = list || []
  for (var i = 0; i < rows.length; i++) {
    var b = rows[i]
    if (isItemHidden("g", b.id, hiddenMap, b)) continue
    var typeLabel = b.kind === "plugin" ? "插件" : "文件夹"
    var n = Number(b.changed_count || (b.files ? b.files.length : 0) || 0)
    var sum = b.summary || (n + (n === 1 ? " 个文件" : " 个文件"))
    var bundleRow = reviewItem("g", b.id, b.name || b.plugin_id || b.id, sum, b.status, typeLabel, both || b.status === "both", n, false)
    bundleRow.removal = !!b.removal
    out.push(bundleRow)
  }
}

// Git plugins from plugins.json. Outgoing rows publish list entries; incoming
// rows are never copied and only offer Omarchy's Install/Update flow.
function pluginListItem(p, hidden) {
  var row = reviewItem("l", p.id, p.name || p.id, p.summary || "", p.status, "Plugin", false, 0, hidden)
  row.removal = !!p.removal
  row.action = String(p.action || "")
  row.pickable = p.status === "local" || p.status === "added-local"
  return row
}

function appendPluginList(out, list, hiddenMap) {
  var rows = list || []
  for (var i = 0; i < rows.length; i++) {
    var p = rows[i]
    if (isItemHidden("l", p.id, hiddenMap, p)) continue
    out.push(pluginListItem(p, false))
  }
}

function appendLooseFiles(out, files, both, hiddenMap) {
  var rows = files || []
  for (var i = 0; i < rows.length; i++) {
    var f = rows[i]
    var p = String(f.path || "")
    if (!p || isBundledPath(p) || p.indexOf("plugins/gladimdim.config-sync") === 0) continue
    if (isItemHidden("f", p, hiddenMap, f)) continue
    var sum = f.semantic_summary || f.summary || ""
    var fileRow = reviewItem("f", p, p, sum, f.status, "文件", both || f.status === "both", 0, false, f.changes || [])
    fileRow.removal = !!f.removal
    out.push(fileRow)
  }
}

function buildIncomingItems(theme, addedShortcuts, changedShortcuts, bundles, files, allFiles, hiddenMap, pluginList) {
  var out = []
  appendThemes(out, theme, hiddenMap)
  appendShortcuts(out, addedShortcuts, "label", false, hiddenMap)
  appendShortcuts(out, changedShortcuts, "detail", false, hiddenMap)
  appendBundles(out, bundles, false, hiddenMap)
  appendPluginList(out, pluginList, hiddenMap)
  appendLooseFiles(out, files, false, hiddenMap)
  return out
}

function buildOutgoingItems(theme, addedShortcuts, changedShortcuts, bundles, files, allFiles, hiddenMap, pluginList) {
  var out = []
  appendThemes(out, theme, hiddenMap)
  appendShortcuts(out, addedShortcuts, "label", false, hiddenMap)
  appendShortcuts(out, changedShortcuts, "detail", false, hiddenMap)
  appendBundles(out, bundles, false, hiddenMap)
  appendPluginList(out, pluginList, hiddenMap)
  appendLooseFiles(out, files, false, hiddenMap)
  return out
}

function buildBothItems(theme, shortcuts, bundles, files, allFiles, hiddenMap) {
  var out = []
  appendThemes(out, theme, hiddenMap)
  appendShortcuts(out, shortcuts, "label", true, hiddenMap)
  appendBundles(out, bundles, true, hiddenMap)
  appendLooseFiles(out, files, true, hiddenMap)
  return out
}

function buildHiddenItems(theme, shortcuts, bundles, files, allFiles, hiddenMap, pluginList) {
  var out = []
  var seen = {}
  function addHidden(kind, id, label, summary, status, typeLabel, both, count, removal) {
    var key = kind + ":" + id
    if (seen[key]) return
    seen[key] = true
    var row = reviewItem(kind, id, label, summary, status, typeLabel, both, count, true)
    row.removal = !!removal
    out.push(row)
  }

  var tList = theme || []
  for (var ti = 0; ti < tList.length; ti++) {
    var t = tList[ti]
    var tid = t.id || "selected"
    if (isItemHidden("t", tid, hiddenMap, t)) {
      addHidden("t", tid, t.display || t.slug, t.slug, t.status, "主题", t.status === "both", 0)
    }
  }

  var sList = shortcuts || []
  for (var si = 0; si < sList.length; si++) {
    var s = sList[si]
    if (isItemHidden("s", s.keys, hiddenMap, s)) {
      addHidden("s", s.keys, s.keys, s.label || s.detail || "", s.status, "快捷键", s.status === "both", 0)
    }
  }

  var bList = bundles || []
  for (var bi = 0; bi < bList.length; bi++) {
    var b = bList[bi]
    if (isItemHidden("g", b.id, hiddenMap, b)) {
      var typeLabel = b.kind === "plugin" ? "插件" : "文件夹"
      var n = Number(b.changed_count || (b.files ? b.files.length : 0) || 0)
      var sum = b.summary || (n + (n === 1 ? " 个文件" : " 个文件"))
      addHidden("g", b.id, b.name || b.plugin_id || b.id, sum, b.status, typeLabel, b.status === "both", n, b.removal)
    }
  }

  var lList = pluginList || []
  for (var li = 0; li < lList.length; li++) {
    var lp = lList[li]
    var lkey = "l:" + lp.id
    if (seen[lkey] || !isItemHidden("l", lp.id, hiddenMap, lp)) continue
    seen[lkey] = true
    out.push(pluginListItem(lp, true))
  }

  var fList = files || []
  for (var fi = 0; fi < fList.length; fi++) {
    var f = fList[fi]
    var p = String(f.path || "")
    if (!p || f.status === "identical" || f.status === "machine") continue
    if (p.indexOf("plugins/gladimdim.config-sync") === 0) continue
    if (isItemHidden("f", p, hiddenMap, f)) {
      var parentHidden = false
      if (p.indexOf("plugins/") === 0) {
        var pid = p.split("/")[1] || ""
        if (pid && (isItemHidden("g", "plugin:" + pid, hiddenMap, null) || isItemHidden("p", pid, hiddenMap, null)))
          parentHidden = true
      }
      if (!parentHidden) {
        addHidden("f", p, p, f.summary || "", f.status, "文件", f.status === "both", 0, f.removal)
      }
    }
  }

  return out
}

function countBy(files, statuses) {
  return filesByStatus(files, statuses).length
}

function relativeAgo(iso) {
  if (!iso) return "从未"
  var then = Date.parse(iso)
  if (!isFinite(then)) return iso
  var seconds = Math.max(0, Math.floor((Date.now() - then) / 1000))
  if (seconds < 60) return "刚刚"
  if (seconds < 3600) return Math.floor(seconds / 60) + " 分钟前"
  if (seconds < 86400) return Math.floor(seconds / 3600) + " 小时前"
  return Math.floor(seconds / 86400) + " 天前"
}

function pluginActionLabel(action) {
  if (action === "update") return "Update"
  if (action === "reinstall") return "Reinstall"
  return "Install"
}

function pluginActionIcon(action) {
  if (action === "update") return "󰚰"
  if (action === "reinstall") return "󰑐"
  return "󰏗"
}

function pluginActionTip(action) {
  if (action === "update") return "Open Omarchy's plugin updater in a terminal"
  if (action === "reinstall") return "Move this plain copy to a backup and install it from git in a terminal"
  return "Open Omarchy's plugin installer in a terminal"
}
