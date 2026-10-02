import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "gladimdim.config-sync"
  ipcTarget: "gladimdim.config-sync"
  manageIpc: false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color accent: Color.accent
  readonly property color urgent: Color.urgent
  readonly property color muted: Color.muted
  readonly property color dim: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.65)
  readonly property color cardBg: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.05)
  readonly property color cardBorder: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.12)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string scriptPath: String(Qt.resolvedUrl("scripts/config_sync.py")).replace(/^file:\/\//, "")

  property bool busy: false
  property string lastError: ""
  property string lastMessage: ""
  property string pendingAction: ""
  property var pendingArgs: []
  property string pendingStdin: ""
  property string repoUrlInput: ""
  property int activeTab: 0
  property bool includeMachine: false
  property bool editingRepo: false
  property string confirmKind: ""
  property var bothPicks: ({})
  property var picks: ({})
  property var status: ({})
  property var inspect: null
  property var diffFiles: []
  property var shortcutDiffs: []
  property var pluginDiffs: []
  property var bundleDiffs: []
  property var pluginListDiffs: []
  property var themeDiff: null
  property bool openOnChanges: false
  property bool showingHidden: false

  readonly property bool configured: !!(status && status.configured)
  readonly property string reportedSyncState: String((status && status.sync_state) || (configured ? "in-sync" : "not-configured"))
  readonly property string syncState: {
    var raw = reportedSyncState
    // File-level "incoming" with nothing to review (comment-only bindings.lua,
    // hidden rows) must not keep the header on Incoming updates.
    if ((raw === "remote-ahead" || raw === "local-ahead") && !hasReviewable) {
      var ahead = Number((status && status.ahead) || 0)
      var behind = Number((status && status.behind) || 0)
      if (ahead === 0 && behind === 0)
        return "in-sync"
    }
    return raw
  }
  readonly property bool alarming: syncState === "conflicts" || syncState === "diverged" || syncState === "invalid"
  readonly property bool pending: syncState === "ready" || syncState === "empty" || syncState === "remote-ahead" || syncState === "local-ahead" || alarming
  readonly property color stateColor: alarming ? urgent : (pending ? accent : foreground)
  readonly property var tabs: [
    { name: "概览", icon: "󰘿" },
    { name: "变更", icon: "󰦓" },
    { name: "配置", icon: "󰒓" }
  ]
  readonly property var allReviewItems: incomingItems.concat(outgoingItems).concat(bothItems)
  // Deletions are opt-in, so they are only ever a surprise if the confirm step stays silent.
  function selectedRemovals(direction) {
    var _ = root.picks
    var items = direction === "apply" ? incomingItems : outgoingItems
    var out = []
    for (var i = 0; i < items.length; i++) {
      var it = items[i]
      if (it.removal && root.isPicked(it.kind, it.itemId)) out.push(it.label)
    }
    return out
  }

  readonly property var hiddenMap: {
    var map = {}
    var list = (status && status.hidden) ? status.hidden : []
    for (var i = 0; i < list.length; i++) {
      map[list[i]] = true
    }
    return map
  }

  readonly property var incomingFiles: Model.filesByStatus(otherFiles, ["repo", "added-repo"])
  readonly property var localFiles: Model.filesByStatus(otherFiles, ["local", "added-local"])
  readonly property var bothFiles: Model.filesByStatus(otherFiles, ["both"])
  readonly property var differsFiles: Model.filesByStatus(otherFiles, ["differs"])
  readonly property var conflictFiles: (status && status.conflicts) ? status.conflicts : []
  readonly property var otherFiles: {
    var out = []
    for (var i = 0; i < diffFiles.length; i++) {
      var f = diffFiles[i]
      if (f.status === "identical" || f.status === "machine") continue
      if (!includeMachine && !f.portable) continue
      if (Model.isBundledPath(f.path)) continue
      if (f.group === "theme" && f.path !== "omarchy/theme.name") continue
      // Per-shortcut rows replace the whole bindings.lua file. If the parser
      // found no bind-level drift (comments, or unbind-then-bind that used to
      // collapse), keep the file so Incoming/Outgoing is not an empty header.
      if (f.path === "hypr/bindings.lua" && Model.hasVisibleShortcutDiffs(shortcutDiffs, hiddenMap)) continue
      out.push(f)
    }
    return out
  }
  readonly property var incomingShortcuts: Model.filesByStatus(shortcutDiffs, ["repo", "added-repo"])
  readonly property var incomingAddedShortcuts: Model.filesByStatus(shortcutDiffs, ["added-repo"])
  readonly property var incomingChangedShortcuts: Model.filesByStatus(shortcutDiffs, ["repo"])
  readonly property var localShortcuts: Model.filesByStatus(shortcutDiffs, ["local", "added-local"])
  readonly property var localAddedShortcuts: Model.filesByStatus(shortcutDiffs, ["added-local"])
  readonly property var localChangedShortcuts: Model.filesByStatus(shortcutDiffs, ["local"])
  readonly property var bothShortcuts: Model.filesByStatus(shortcutDiffs, ["both"])
  readonly property var incomingPlugins: Model.filesByStatus(pluginDiffs, ["repo", "added-repo"])
  readonly property var localPlugins: Model.filesByStatus(pluginDiffs, ["local", "added-local"])
  readonly property var bothPlugins: Model.filesByStatus(pluginDiffs, ["both"])
  readonly property var differsPlugins: Model.filesByStatus(pluginDiffs, ["differs"])
  readonly property var incomingBundles: Model.filesByStatus(bundleDiffs, ["repo", "added-repo", "differs"])
  readonly property var localBundles: Model.filesByStatus(bundleDiffs, ["local", "added-local"])
  readonly property var bothBundles: Model.filesByStatus(bundleDiffs, ["both"])
  readonly property var incomingPluginList: Model.filesByStatus(pluginListDiffs, ["repo", "added-repo"])
  readonly property var outgoingPluginList: Model.filesByStatus(pluginListDiffs, ["local", "added-local"])
  readonly property var incomingTheme: {
    if (!themeDiff) return []
    var st = String(themeDiff.status)
    if (st === "repo" || st === "added-repo" || st === "differs") return [themeDiff]
    return []
  }
  readonly property var outgoingTheme: {
    if (!themeDiff) return []
    var st = String(themeDiff.status)
    if (st === "local" || st === "added-local") return [themeDiff]
    return []
  }
  readonly property var bothTheme: {
    if (!themeDiff) return []
    if (String(themeDiff.status) === "both") return [themeDiff]
    return []
  }
  readonly property var incomingItems: Model.buildIncomingItems(incomingTheme, incomingAddedShortcuts, incomingChangedShortcuts, incomingBundles, incomingFiles.concat(differsFiles), diffFiles, hiddenMap, incomingPluginList)
  readonly property var outgoingItems: Model.buildOutgoingItems(outgoingTheme, localAddedShortcuts, localChangedShortcuts, localBundles, localFiles, diffFiles, hiddenMap, outgoingPluginList)
  readonly property var bothItems: Model.buildBothItems(bothTheme, bothShortcuts, bothBundles, bothFiles, diffFiles, hiddenMap)
  readonly property var hiddenItems: Model.buildHiddenItems((themeDiff ? [themeDiff] : []), shortcutDiffs, bundleDiffs, diffFiles, diffFiles, hiddenMap, pluginListDiffs)
  readonly property int incomingCount: incomingItems.length
  readonly property int outgoingCount: outgoingItems.length
  readonly property int bothCount: bothItems.length
  readonly property int hiddenCount: hiddenItems.length
  readonly property int incomingPicked: {
    var _ = picks
    return Model.pickedInItems(incomingItems, picks)
  }
  readonly property int outgoingPicked: {
    var _ = picks
    return Model.pickedInItems(outgoingItems, picks)
  }
  readonly property int bothPicked: {
    var _ = picks
    return Model.pickedInItems(bothItems, picks)
  }
  readonly property bool hasReviewable: incomingCount + outgoingCount + bothCount + conflictFiles.length > 0
  readonly property int unresolvedBoth: {
    var n = 0
    var i
    for (i = 0; i < bothFiles.length; i++) {
      if (isPicked("f", bothFiles[i].path) && !bothPicks[bothFiles[i].path]) n++
    }
    for (i = 0; i < bothShortcuts.length; i++) {
      if (isPicked("s", bothShortcuts[i].keys) && !bothPicks["s:" + bothShortcuts[i].keys]) n++
    }
    for (i = 0; i < bothPlugins.length; i++) {
      // A plugin is only ever rendered as its plugin:<id> bundle row, so that
      // row's Keep local / Take repo pick is the one the user can actually
      // make. Gating on the p: key alone leaves Apply permanently blocked.
      if (isPicked("p", bothPlugins[i].id)
          && !bothPicks["p:" + bothPlugins[i].id]
          && !bothPicks["g:plugin:" + bothPlugins[i].id]) n++
    }
    for (i = 0; i < bothBundles.length; i++) {
      if (isPicked("g", bothBundles[i].id) && !bothPicks["g:" + bothBundles[i].id]) n++
    }
    if (themeDiff && themeDiff.status === "both" && isPicked("t", "selected") && !bothPicks["t:selected"]) n++
    return n
  }

  function hideItem(kind, id) {
    var key = pickId(kind, id)
    run(["hide", key])
  }

  function unhideItem(kind, id) {
    var key = pickId(kind, id)
    run(["unhide", key])
  }

  function unhideAll() {
    run(["unhide", "--all"])
  }

  function refresh(fetch) {
    run(["snapshot"].concat(fetch ? ["--fetch"] : []))
  }

  function connectRepo() {
    var url = String(repoUrlInput || "").trim()
    if (!url) {
      lastError = "粘贴你的 omarchy-config 仓库的 git URL 或本地路径。"
      return
    }
    lastError = ""
    run(["connect", "--stdin"], url)
  }

  function cloneMap(obj) {
    var next = {}
    var keys = Object.keys(obj || {})
    for (var i = 0; i < keys.length; i++) next[keys[i]] = obj[keys[i]]
    return next
  }

  function pickId(kind, id) { return kind + ":" + id }

  function isPicked(kind, id) { return !!picks[pickId(kind, id)] }

  function togglePick(kind, id) {
    var key = pickId(kind, id)
    var next = cloneMap(picks)
    next[key] = !next[key]
    picks = next
  }

  function setPicked(kind, id, on) {
    var next = cloneMap(picks)
    next[pickId(kind, id)] = on
    picks = next
  }

  function seedPicks() {
    var next = {}
    var i, key, item
    for (i = 0; i < otherFiles.length; i++) {
      item = otherFiles[i]
      key = pickId("f", item.path)
      next[key] = (key in picks) ? picks[key] : !!(item.default_apply || item.default_publish || item.status === "differs")
    }
    for (i = 0; i < shortcutDiffs.length; i++) {
      item = shortcutDiffs[i]
      key = pickId("s", item.keys)
      next[key] = (key in picks) ? picks[key] : !!(item.default_apply || item.default_publish)
    }
    for (i = 0; i < pluginDiffs.length; i++) {
      item = pluginDiffs[i]
      key = pickId("p", item.id)
      // Plugins run code: never default-check an incoming one, only ever an outgoing publish.
      next[key] = (key in picks) ? picks[key] : !!item.default_publish
    }
    for (i = 0; i < bundleDiffs.length; i++) {
      item = bundleDiffs[i]
      key = pickId("g", item.id)
      // Hooks/agents/branding/extensions/bin run code or steer an agent: same rule as plugins.
      next[key] = (key in picks) ? picks[key] : !!item.default_publish
    }
    for (i = 0; i < outgoingPluginList.length; i++) {
      item = outgoingPluginList[i]
      key = pickId("l", item.id)
      next[key] = (key in picks) ? picks[key] : !!item.default_publish
    }
    if (themeDiff) {
      key = pickId("t", "selected")
      next[key] = (key in picks) ? picks[key] : !!(themeDiff.default_apply || themeDiff.default_publish || themeDiff.status === "differs")
    }
    function seedReview(list) {
      var rows = list || []
      var ri, row, rkey, st
      for (ri = 0; ri < rows.length; ri++) {
        row = rows[ri]
        rkey = pickId(row.kind, row.itemId)
        if (rkey in next || row.pickable === false) continue
        st = String(row.status || "")
        next[rkey] = st === "repo" || st === "added-repo" || st === "differs" || st === "local" || st === "added-local" || st === "both"
      }
    }
    seedReview(incomingItems)
    seedReview(outgoingItems)
    seedReview(bothItems)
    picks = next
  }

  function reviewChanges() { activeTab = 1 }

  function shortcutDiffFor(keys) {
    var k = String(keys || "")
    for (var i = 0; i < shortcutDiffs.length; i++)
      if (String(shortcutDiffs[i].keys) === k) return shortcutDiffs[i]
    return null
  }

  function pluginDiffFor(id) {
    var k = String(id || "")
    for (var i = 0; i < pluginDiffs.length; i++)
      if (String(pluginDiffs[i].id) === k) return pluginDiffs[i]
    return null
  }

  function fileDiffFor(path) {
    var k = String(path || "")
    for (var i = 0; i < otherFiles.length; i++)
      if (String(otherFiles[i].path) === k) return otherFiles[i]
    return null
  }

  // Tick or untick every pickable row of one Change section.
  function pickItems(items, on) {
    var next = cloneMap(picks)
    for (var i = 0; i < (items || []).length; i++) {
      var row = items[i]
      if (row.pickable === false) continue
      next[pickId(row.kind, row.itemId)] = on
    }
    picks = next
  }

  function bulkPick(mode) {
    var next = cloneMap(picks)
    var keys = Object.keys(next)
    var i, k, on
    function sideOf(key) {
      if (key.indexOf("s:") === 0) {
        for (i = 0; i < shortcutDiffs.length; i++)
          if (pickId("s", shortcutDiffs[i].keys) === key)
            return shortcutDiffs[i].status
      } else if (key.indexOf("p:") === 0) {
        for (i = 0; i < pluginDiffs.length; i++)
          if (pickId("p", pluginDiffs[i].id) === key)
            return pluginDiffs[i].status
      } else if (key.indexOf("f:") === 0) {
        for (i = 0; i < otherFiles.length; i++)
          if (pickId("f", otherFiles[i].path) === key)
            return otherFiles[i].status
      } else if (key.indexOf("g:") === 0) {
        for (i = 0; i < bundleDiffs.length; i++)
          if (pickId("g", bundleDiffs[i].id) === key)
            return bundleDiffs[i].status
      } else if (key.indexOf("l:") === 0) {
        for (i = 0; i < outgoingPluginList.length; i++)
          if (pickId("l", outgoingPluginList[i].id) === key)
            return outgoingPluginList[i].status
      } else if (key === pickId("t", "selected") && themeDiff) {
        return themeDiff.status
      }
      return ""
    }
    for (var ki = 0; ki < keys.length; ki++) {
      k = keys[ki]
      var st = sideOf(k)
      if (mode === "all") on = true
      else if (mode === "none") on = false
      else if (mode === "in") on = st === "repo" || st === "added-repo" || st === "differs" || st === "both"
      else on = st === "local" || st === "added-local" || st === "differs" || st === "both"
      next[k] = on
    }
    picks = next
  }

  function selectedApplyFiles() {
    var out = []
    var i, f
    for (i = 0; i < otherFiles.length; i++) {
      f = otherFiles[i]
      if (!isPicked("f", f.path)) continue
      if (f.status === "both") {
        if (bothPicks[f.path] === "repo") out.push(f.path)
        continue
      }
      if (f.status === "repo" || f.status === "added-repo" || f.status === "differs") out.push(f.path)
    }
    return out
  }

  function selectedPublishFiles() {
    var out = []
    var i, f
    for (i = 0; i < otherFiles.length; i++) {
      f = otherFiles[i]
      if (!isPicked("f", f.path)) continue
      if (f.status === "both") {
        if (bothPicks[f.path] === "local") out.push(f.path)
        continue
      }
      if (f.status === "local" || f.status === "added-local" || f.status === "differs") out.push(f.path)
    }
    return out
  }

  function shortcutPortableFor(s, direction) {
    if (!s) return true
    if (s.status === "both")
      return direction === "apply" ? s.repo_portable !== false : s.local_portable !== false
    return s.portable !== false
  }

  function selectedApplyShortcuts() {
    var out = []
    var i, s
    for (i = 0; i < shortcutDiffs.length; i++) {
      s = shortcutDiffs[i]
      if (!isPicked("s", s.keys)) continue
      if (!shortcutPortableFor(s, "apply")) continue
      if (s.status === "both") {
        if (bothPicks["s:" + s.keys] === "repo") out.push(s.keys)
        continue
      }
      if (s.status === "added-repo" || s.status === "repo" || s.status === "differs") out.push(s.keys)
    }
    return out
  }

  function selectedPublishShortcuts() {
    var out = []
    var i, s
    for (i = 0; i < shortcutDiffs.length; i++) {
      s = shortcutDiffs[i]
      if (!isPicked("s", s.keys)) continue
      if (!shortcutPortableFor(s, "publish")) continue
      if (s.status === "both") {
        if (bothPicks["s:" + s.keys] === "local") out.push(s.keys)
        continue
      }
      if (s.status === "added-local" || s.status === "local") out.push(s.keys)
    }
    return out
  }

  function pluginIdFromBundle(id) {
    var raw = String(id || "")
    if (raw.indexOf("plugin:") === 0) return raw.substring(7)
    return raw
  }

  function selectedApplyPlugins() {
    var out = []
    var seen = {}
    var i, b, pid
    for (i = 0; i < bundleDiffs.length; i++) {
      b = bundleDiffs[i]
      if (b.kind !== "plugin" || !isPicked("g", b.id)) continue
      if (b.status === "both") {
        if (bothPicks["g:" + b.id] !== "repo") continue
      } else if (!(b.status === "added-repo" || b.status === "repo" || b.status === "differs")) {
        continue
      }
      pid = b.plugin_id || pluginIdFromBundle(b.id)
      if (pid && !seen[pid]) { seen[pid] = true; out.push(pid) }
    }
    for (i = 0; i < incomingItems.length; i++) {
      b = incomingItems[i]
      if (b.kind !== "g" || b.typeLabel !== "插件" || !isPicked("g", b.itemId)) continue
      pid = pluginIdFromBundle(b.itemId)
      if (pid && !seen[pid]) { seen[pid] = true; out.push(pid) }
    }
    return out
  }

  function selectedBundleFiles(direction) {
    var out = []
    var i, b, j
    for (i = 0; i < bundleDiffs.length; i++) {
      b = bundleDiffs[i]
      if (b.kind === "plugin") continue
      if (!isPicked("g", b.id)) continue
      if (b.status === "both") {
        if (direction === "apply" && bothPicks["g:" + b.id] !== "repo") continue
        if (direction === "publish" && bothPicks["g:" + b.id] !== "local") continue
      } else if (direction === "apply") {
        if (!(b.status === "added-repo" || b.status === "repo" || b.status === "differs")) continue
      } else if (!(b.status === "added-local" || b.status === "local" || b.status === "differs")) continue
      var list = b.files || []
      for (j = 0; j < list.length; j++) out.push(list[j])
    }
    return out
  }

  function selectedApplyTheme() {
    if (!themeDiff || !isPicked("t", "selected")) return false
    if (themeDiff.status === "both") return bothPicks["t:selected"] === "repo"
    return themeDiff.status === "added-repo" || themeDiff.status === "repo" || themeDiff.status === "differs"
  }

  function selectedPublishTheme() {
    if (!themeDiff || !isPicked("t", "selected")) return false
    if (themeDiff.status === "both") return bothPicks["t:selected"] === "local"
    return themeDiff.status === "added-local" || themeDiff.status === "local" || themeDiff.status === "differs"
  }

  function selectedPublishPlugins() {
    var out = []
    var seen = {}
    var i, b, pid
    for (i = 0; i < bundleDiffs.length; i++) {
      b = bundleDiffs[i]
      if (b.kind !== "plugin" || !isPicked("g", b.id)) continue
      if (b.status === "both") {
        if (bothPicks["g:" + b.id] !== "local") continue
      } else if (!(b.status === "added-local" || b.status === "local" || b.status === "differs")) {
        continue
      }
      pid = b.plugin_id || pluginIdFromBundle(b.id)
      if (pid && !seen[pid]) { seen[pid] = true; out.push(pid) }
    }
    for (i = 0; i < outgoingItems.length; i++) {
      b = outgoingItems[i]
      if (b.kind !== "g" || b.typeLabel !== "插件" || !isPicked("g", b.itemId)) continue
      pid = pluginIdFromBundle(b.itemId)
      if (pid && !seen[pid]) { seen[pid] = true; out.push(pid) }
    }
    return out
  }

  // Only outgoing rows are picks; installs and updates go through Omarchy.
  function selectedPublishListPlugins() {
    var out = []
    for (var i = 0; i < outgoingItems.length; i++) {
      var row = outgoingItems[i]
      if (row.kind === "l" && row.pickable !== false && isPicked("l", row.itemId)) out.push(row.itemId)
    }
    return out
  }

  function runPluginAction(action, id) {
    if (action === "install") run(["install-plugin", id])
    else if (action === "update") run(["update-plugin", id])
    else if (action === "reinstall") run(["reinstall-plugin", id])
  }

  function selectSide(kind, id, side) {
    setPick(kind === "f" ? id : (kind + ":" + id), side)
    setPicked(kind, id, true)
  }

  function requestApply() {
    if (unresolvedBoth > 0) {
      lastError = "对两侧都有改动的每个文件，选择「保留本机」或「采用仓库」。"
      activeTab = 1
      return
    }
    if (conflictFiles.length > 0) {
      lastError = "请先解决 git 合并冲突再应用。"
      activeTab = 1
      return
    }
    if (selectedApplyFiles().length + selectedApplyShortcuts().length + selectedApplyPlugins().length + selectedBundleFiles("apply").length === 0 && !selectedApplyTheme()) {
      lastError = "勾选要应用的传入快捷键、插件或文件。"
      activeTab = 1
      return
    }
    confirmKind = "apply"
  }

  function requestPublish() {
    if (unresolvedBoth > 0) {
      lastError = "对两侧都有改动的每个文件，选择「保留本机」或「采用仓库」。"
      activeTab = 1
      return
    }
    if (conflictFiles.length > 0) {
      lastError = "请先解决 git 合并冲突再发布。"
      activeTab = 1
      return
    }
    if (selectedPublishFiles().length + selectedPublishShortcuts().length + selectedPublishPlugins().length + selectedPublishListPlugins().length + selectedBundleFiles("publish").length === 0 && !selectedPublishTheme() && Number(status.ahead || 0) === 0) {
      lastError = "勾选要发布的本机快捷键、插件或文件。"
      activeTab = 1
      return
    }
    confirmKind = "publish"
  }

  function confirmCurrent() {
    var kind = confirmKind
    confirmKind = ""
    if (kind === "apply") {
      var files = selectedApplyFiles().concat(selectedBundleFiles("apply"))
      var args = ["apply", "--explicit", "--files", files.join(",")]
      if (includeMachine) args.push("--include-machine")
      var ashort = selectedApplyShortcuts()
      var aplugs = selectedApplyPlugins()
      var ai
      for (ai = 0; ai < ashort.length; ai++) args.push("--shortcut", ashort[ai])
      for (ai = 0; ai < aplugs.length; ai++) args.push("--plugin", aplugs[ai])
      if (selectedApplyTheme()) args.push("--theme")
      run(args)
    } else if (kind === "publish") {
      var pub = selectedPublishFiles().concat(selectedBundleFiles("publish"))
      var pargs = ["publish", "--push", "--explicit", "--files", pub.join(",")]
      if (includeMachine) pargs.push("--include-machine")
      var pshort = selectedPublishShortcuts()
      var pplugs = selectedPublishPlugins()
      var pi
      for (pi = 0; pi < pshort.length; pi++) pargs.push("--shortcut", pshort[pi])
      for (pi = 0; pi < pplugs.length; pi++) pargs.push("--plugin", pplugs[pi])
      var plist = selectedPublishListPlugins()
      for (pi = 0; pi < plist.length; pi++) pargs.push("--list-plugin", plist[pi])
      if (selectedPublishTheme()) pargs.push("--theme")
      run(pargs)
    } else if (kind === "disconnect") {
      run(["disconnect"])
      repoUrlInput = ""
      editingRepo = false
      bothPicks = ({})
    } else if (kind === "switch-repo") {
      editingRepo = false
      lastError = ""
      var targetUrl = String(repoUrlInput || "").trim()
      run(["connect", "--stdin"], targetUrl)
    } else if (kind === "resync-repo") {
      run(["resync", "--side", "repo"])
    } else if (kind === "resync-local") {
      run(["resync", "--side", "local"])
    }
  }

  function startEditRepo() {
    repoUrlInput = String((status && status.repo_url) || repoUrlInput || "")
    editingRepo = true
    activeTab = 0
    lastError = ""
  }

  function cancelEditRepo() {
    editingRepo = false
    repoUrlInput = String((status && status.repo_url) || "")
  }

  function saveEditRepo() {
    var url = String(repoUrlInput || "").trim()
    if (!url) {
      lastError = "粘贴配置仓库的 git URL 或本地路径。"
      return
    }
    var current = String((status && status.repo_url) || "").replace(/\/+$/, "").replace(/\.git$/, "")
    var next = url.replace(/\/+$/, "").replace(/\.git$/, "")
    if (current && (next === current || next === current + ".git" || current === next + ".git")) {
      editingRepo = false
      lastMessage = "已链接到该仓库。"
      return
    }
    confirmKind = "switch-repo"
  }

  function pullRemote() {
    run(["pull"])
  }

  function setPick(path, side) {
    var next = {}
    var keys = Object.keys(bothPicks)
    for (var i = 0; i < keys.length; i++) next[keys[i]] = bothPicks[keys[i]]
    next[path] = side
    bothPicks = next
  }

  function resolveConflict(path, side) {
    run(["resolve", path, "--side", side])
  }

  function openFile(path, localPath, repoPath) {
    var target = String(localPath || "").trim()
    if (!target) {
      target = String(repoPath || "").trim()
    }
    if (!target) {
      target = String(path || "").trim()
    }
    if (!target) return
    Quickshell.execDetached(["python3", root.scriptPath, "open", target])
  }

  function openTerminal(path, localPath, repoPath) {
    var target = String(localPath || "").trim()
    if (!target) {
      target = String(repoPath || "").trim()
    }
    if (!target) {
      target = String(path || "").trim()
    }
    if (!target) return
    Quickshell.execDetached(["python3", root.scriptPath, "terminal", target])
  }

  function applySnapshot(data) {
    status = data.status || {}
    inspect = data.inspect || null
    diffFiles = (data.diff && data.diff.files) ? data.diff.files : []
    shortcutDiffs = (data.diff && data.diff.shortcuts) ? data.diff.shortcuts : []
    pluginDiffs = (data.diff && data.diff.plugins) ? data.diff.plugins : []
    bundleDiffs = (data.diff && data.diff.bundles) ? data.diff.bundles : []
    pluginListDiffs = (data.diff && data.diff.plugin_list) ? data.diff.plugin_list : []
    themeDiff = (data.diff && data.diff.theme) ? data.diff.theme : null
    if (data.sync_state && status)
      status = Object.assign({}, status, { sync_state: data.sync_state })
    if (!editingRepo && status.repo_url)
      repoUrlInput = String(status.repo_url)
    Qt.callLater(function() {
      root.seedPicks()
      // An empty repo opens on Overview: the first-push card is the guide there.
      if (root.openOnChanges && root.syncState === "empty") {
        root.activeTab = 0
        root.openOnChanges = false
      } else if (root.openOnChanges && root.hasReviewable) {
        root.activeTab = 1
        root.openOnChanges = false
      } else {
        root.openOnChanges = false
      }
    })
  }

  function run(args, stdinData) {
    if (syncProc.running) {
      pendingArgs = args
      pendingStdin = String(stdinData || "")
      return
    }
    busy = true
    lastError = ""
    pendingAction = args[0] || ""
    syncProc.command = ["python3", "-u", root.scriptPath].concat(args)
    syncProc.running = true
    // The helper reads a line from stdin and we never close the pipe, so a
    // --stdin command must always get its newline — otherwise it blocks on a
    // read that never returns and the panel stays busy forever.
    if (stdinData || args.indexOf("--stdin") >= 0) {
      syncProc.write(String(stdinData || "") + "\n")
    }
  }

  function handleOutput(text) {
    busy = false
    var raw = String(text || "").trim()
    if (!raw) {
      lastError = "同步助手没有返回输出。"
      return
    }
    if (raw.length > 5 * 1024 * 1024) {
      lastError = "同步响应超出缓冲区上限（5MB）。"
      return
    }
    var data
    try {
      data = JSON.parse(raw)
    } catch (e) {
      lastError = "无法解析同步助手的输出。"
      return
    }
    if (!data.ok) {
      lastError = String(data.error || "同步失败。")
      if (data.both) activeTab = 1
      if (data.conflicts && data.conflicts.length > 0) {
        status = Object.assign({}, status, { conflicts: data.conflicts, sync_state: "conflicts", configured: true })
        activeTab = 1
      }
      return
    }
    lastMessage = String(data.message || "")
    if (data.connected)
      editingRepo = false
    if (data.status || data.configured === false || data.disconnected)
      applySnapshot(data)
    if (data.push_error)
      lastError = String(data.push_error)
    if (data.disconnected) {
      status = { configured: false, sync_state: "not-configured", plugin_version: (status && status.plugin_version) || "" }
      inspect = null
      diffFiles = []
      bothPicks = ({})
      activeTab = 0
    }
  }

  onOpenedChanged: {
    if (opened) {
      confirmKind = ""
      lastError = ""
      openOnChanges = true
      refresh(true)
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    }
  }

  Component.onCompleted: refresh(true)

  Timer {
    interval: 10 * 60 * 1000
    running: true
    repeat: true
    onTriggered: if (!root.busy) root.refresh(true)
  }

  Process {
    id: syncProc
    stdinEnabled: true
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.handleOutput(text)
        if (root.pendingArgs.length > 0) {
          var next = root.pendingArgs
          var nextStdin = root.pendingStdin
          root.pendingArgs = []
          root.pendingStdin = ""
          root.run(next, nextStdin)
        }
      }
    }
    stderr: StdioCollector { waitForEnd: true }
  }

  IpcHandler {
    target: "gladimdim.config-sync"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refresh(true); return "ok" }
    function setTab(tab: int): void { root.activeTab = tab }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰘿"
    tooltipText: configured
      ? ("配置同步 — " + Model.stateTitle(root.syncState))
      : "配置同步 — 链接你的 omarchy-config 仓库"
    onPressed: function(b) {
      if (b === Qt.RightButton) root.refresh(true)
      else root.toggle()
    }
  }

  Rectangle {
    visible: root.pending && !root.opened
    width: 7
    height: 7
    radius: 4
    color: root.stateColor
    border.width: 1
    border.color: root.bar ? root.bar.background : Color.background
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.rightMargin: 1
    anchors.topMargin: 3
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(560))
    contentHeight: panel.fittedContentHeight(Style.space(580))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: urlField.activeFocus || root.editingRepo || root.confirmKind !== ""

      onCloseRequested: {
        if (root.confirmKind !== "") root.confirmKind = ""
        else root.close()
      }
      onMoveRequested: function(dx, dy) {
        if (!root.configured) return
        if (dx !== 0) {
          var n = root.tabs.length
          root.activeTab = (root.activeTab + dx + n) % n
        }
      }
      onTextKey: function(t) {
        if (t === "r" || t === "R") root.refresh(true)
        else if (t === "a" || t === "A") root.requestApply()
        else if (t === "p" || t === "P") root.requestPublish()
        else if (t === "c" || t === "C") root.reviewChanges()
        else if (t >= "1" && t <= String(root.tabs.length)) root.activeTab = parseInt(t) - 1
      }

      Column {
        id: mainCol
        anchors.fill: parent
        spacing: Style.space(10)

        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroInfo.implicitHeight, heroActions.implicitHeight)

          Text {
            id: heroIcon
            textFormat: Text.PlainText
            text: root.busy ? "󰦖" : "󰘿"
            color: root.stateColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            id: heroInfo
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(12)
            anchors.right: heroActions.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Row {
              width: parent.width
              spacing: Style.space(6)

              Text {
                id: heroTitle
                textFormat: Text.PlainText
                text: root.configured ? Model.repoName(root.status.repo_url) : "配置同步"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
                elide: Text.ElideRight
                width: Math.min(implicitWidth, parent.width - heroVersion.implicitWidth - parent.spacing)
              }

              Text {
                id: heroVersion
                textFormat: Text.PlainText
                text: root.status && root.status.plugin_version ? "v" + root.status.plugin_version : ""
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                anchors.baseline: heroTitle.baseline
              }
            }

            Text {
              textFormat: Text.PlainText
              text: root.busy
                ? (root.pendingAction === "connect" ? "正在拉取并检查仓库…" : "处理中…")
                : Model.stateTitle(root.syncState)
              color: root.stateColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              width: parent.width
            }
          }

          Row {
            id: heroActions
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)
            height: Math.max(btnRefresh.implicitHeight, btnEdit.implicitHeight, btnClose.implicitHeight)

            Button {
              id: btnRefresh
              iconText: "󰑐"
              tooltipText: "刷新（r）"
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              anchors.verticalCenter: parent.verticalCenter
              height: parent.height
              enabled: !root.busy
              onClicked: root.refresh(true)
            }

            Button {
              id: btnEdit
              visible: root.configured
              text: "编辑"
              tooltipText: "使用其他 git 仓库"
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              anchors.verticalCenter: parent.verticalCenter
              height: parent.height
              enabled: !root.busy
              onClicked: root.startEditRepo()
            }

            Button {
              id: btnClose
              visible: root.configured
              iconText: "󰅖"
              tooltipText: "取消链接此仓库"
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              anchors.verticalCenter: parent.verticalCenter
              height: parent.height
              enabled: !root.busy
              onClicked: root.confirmKind = "disconnect"
            }
          }
        }

        Text {
          visible: root.lastError !== ""
          width: parent.width
          textFormat: Text.PlainText
          text: root.lastError
          color: root.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        Text {
          visible: root.lastError === "" && root.lastMessage !== ""
          width: parent.width
          textFormat: Text.PlainText
          text: root.lastMessage
          color: root.accent
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        // ---------------- SETUP ----------------
        Flickable {
          visible: !root.configured
          width: parent.width
          height: Math.max(80, panel.contentHeight - mainCol.spacing * 4 - heroInfo.implicitHeight - Style.space(36))
          contentWidth: width
          contentHeight: setupCol.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          flickableDirection: Flickable.VerticalFlick
          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

          Column {
            id: setupCol
            width: parent.width
            spacing: Style.space(12)

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: "首次使用：为你的 Omarchy 配置创建一个私有 GitHub 仓库，然后把 URL 粘贴到这里。插件不会把该仓库设为公开。"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }

            GuideStep {
              step: "1"
              title: "创建私有 GitHub 仓库"
              body: "github.com/new → 命名为 omarchy-config → 可见性选 Private → 不勾选 README / .gitignore / license → 创建仓库。私有可避免快捷键、钩子与脚本暴露到公网。"
            }

            Row {
              spacing: Style.space(8)
              Button {
                text: "打开 GitHub"
                iconText: "󰊤"
                foreground: root.foreground
                fontFamily: root.fontFamily
                bordered: true
                onClicked: Quickshell.execDetached(["xdg-open", "https://github.com/new"])
              }
              Button {
                text: "复制 gh auth login"
                tooltipText: "插件无法直接询问 GitHub 密码（会卡死状态栏）。请在终端中粘贴执行，完成浏览器登录后再点「连接」。"
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: {
                  Quickshell.execDetached(["wl-copy", "gh auth login"])
                  root.lastMessage = "已复制 gh auth login —— 请在终端中运行并完成浏览器登录，然后回来点击「连接」。"
                }
              }
            }

            GuideStep {
              step: "2"
              title: "粘贴仓库 URL"
              body: "支持 HTTPS（https://github.com/you/omarchy-config.git）、SSH 或 owner/repo。第一台机器需要空的私有仓库；下一台机器粘贴同一 URL 并点击「应用」。"
            }

            TextField {
              id: urlField
              width: parent.width
              placeholderText: "https://github.com/you/omarchy-config.git"
              text: root.repoUrlInput
              foreground: root.foreground
              font.family: root.fontFamily
              enabled: !root.busy
              onTextChanged: root.repoUrlInput = text
              onAccepted: root.connectRepo()
              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                  keyCatcher.forceActiveFocus()
                  event.accepted = true
                }
              }
            }

            Row {
              spacing: Style.space(8)
              Button {
                text: root.busy ? "连接中…" : "连接仓库"
                iconText: "󰓦"
                foreground: root.foreground
                fontFamily: root.fontFamily
                enabled: !root.busy && String(root.repoUrlInput).trim() !== ""
                bordered: true
                onClicked: root.connectRepo()
              }
              Button {
                text: "使用本机的克隆"
                tooltipText: "如果你的配置已放在 ~/Github/omarchy-config"
                foreground: root.foreground
                fontFamily: root.fontFamily
                enabled: !root.busy
                onClicked: {
                  root.repoUrlInput = Quickshell.env("HOME") + "/Github/omarchy-config"
                  urlField.text = root.repoUrlInput
                }
              }
            }

            GuideStep {
              step: "3"
              title: "检查后发布本机"
              body: "空仓库：标签页显示的是本机内容。发布会推送到 GitHub（仍为私有）。下一台机器：连接相同 URL 并点击「应用」。除非你主动启用，显示器布局默认跳过。"
            }
          }
        }

        // ---------------- CONFIGURED TABS ----------------
        Row {
          id: tabRow
          visible: root.configured
          width: parent.width
          spacing: Style.space(4)
          readonly property real tabWidth: (width - spacing * (root.tabs.length - 1)) / root.tabs.length

          Repeater {
            model: root.tabs
            Button {
              required property var modelData
              required property int index
              width: tabRow.tabWidth
              iconText: modelData.icon
              text: modelData.name
              fontSize: Style.font.caption
              foreground: root.foreground
              fontFamily: root.fontFamily
              selected: root.activeTab === index
              bordered: true
              horizontalPadding: Style.space(2)
              verticalPadding: Style.space(5)
              onClicked: root.activeTab = index
            }
          }
        }

        PanelSeparator {
          visible: root.configured
          foreground: root.foreground
        }

        Flickable {
          id: scrollArea
          visible: root.configured
          width: parent.width
          height: Math.max(80, parent.height - y - Style.space(16))
          contentWidth: width
          contentHeight: loader.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          flickableDirection: Flickable.VerticalFlick
          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

          Loader {
            id: loader
            width: parent.width
            sourceComponent: {
              if (root.activeTab === 1) return tabChangesComp
              if (root.activeTab === 2) return tabConfigsComp
              return tabOverviewComp
            }
          }
        }
      }

      // Confirm overlay
      Rectangle {
        anchors.fill: parent
        visible: root.confirmKind !== ""
        color: Qt.rgba(0, 0, 0, 0.45)

        MouseArea { anchors.fill: parent; onClicked: root.confirmKind = "" }

        BorderSurface {
          anchors.centerIn: parent
          width: Math.min(parent.width - Style.space(24), Style.space(360))
          implicitHeight: confirmCol.implicitHeight + Style.space(28)
          color: Color.popups.background
          borderSpec: Border.flat(root.accent, Style.normalBorderWidth)
          radius: Style.cornerRadius
          padding: Style.space(16)

          MouseArea { anchors.fill: parent; onClicked: {} }

          Column {
            id: confirmCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Style.space(16)
            anchors.rightMargin: Style.space(16)
            spacing: Style.space(12)

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: root.confirmKind === "apply"
                ? "将勾选的传入快捷键、插件与文件应用到本机？会先写入带时间戳的备份。"
                : root.confirmKind === "publish"
                  ? (root.syncState === "empty"
                    ? "用本机勾选的项初始化这个私有 GitHub 仓库并推送？请保持仓库私有，避免快捷键、钩子与脚本公开。"
                    : "将勾选的本机快捷键、插件与文件复制进仓库、提交并推送？")
                  : root.confirmKind === "switch-repo"
                    ? "将本机指向另一个 git 仓库？本地文件不会被删除，应用任何内容之前会先克隆并检查新仓库。"
                    : root.confirmKind === "resync-repo"
                      ? "让本机与 git 仓库一致？传入的插件、快捷键、主题与配置会覆盖本机副本。会先写入带时间戳的备份，仅存在于本机的额外文件保持不变。"
                      : root.confirmKind === "resync-local"
                        ? "用本机配置覆盖 git 仓库并推送？"
                        : "取消本机与配置仓库的链接？本地文件保持原样。"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
            }

            Text {
              width: parent.width
              textFormat: Text.PlainText
              visible: root.confirmKind === "apply" || root.confirmKind === "publish"
              text: {
                var names = root.selectedRemovals(root.confirmKind)
                if (names.length === 0) return ""
                var where = root.confirmKind === "apply" ? "从本机删除" : "从仓库中删除"
                var head = "以下 " + names.length + " 个条目将被" + where + "：\n"
                return head + names.slice(0, 8).join("、") + (names.length > 8 ? " 等共 " + names.length + " 个" : "")
              }
              color: root.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
            }

            Row {
              spacing: Style.space(8)
              layoutDirection: Qt.RightToLeft
              width: parent.width

              Button {
                text: root.confirmKind === "disconnect" ? "取消链接" : (root.confirmKind === "switch-repo" ? "切换仓库" : (root.confirmKind === "resync-repo" ? "采用仓库" : (root.confirmKind === "resync-local" ? "采用本机" : (root.confirmKind === "publish" ? (root.syncState === "empty" ? "初始化并推送" : "发布") : "应用"))))
                foreground: root.foreground
                fontFamily: root.fontFamily
                bordered: true
                onClicked: root.confirmCurrent()
              }
              Button {
                text: "取消"
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.confirmKind = ""
              }
            }
          }
        }
      }
    }
  }

  Component {
    id: tabOverviewComp
    Column {
      width: parent.width
      spacing: Style.space(12)

      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: Model.stateHint(root.syncState, root.status)
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WordWrap
      }

      Row {
        width: parent.width
        spacing: Style.space(8)
        readonly property real pillW: (width - spacing * 3) / 4

        QuickPill {
          width: parent.pillW
          icon: "󰌌"
          label: "快捷键"
          value: root.inspect && root.inspect.shortcuts ? String(root.inspect.shortcuts.length) : "—"
        }
        QuickPill {
          width: parent.pillW
          icon: "󰐱"
          label: "插件"
          value: root.inspect && root.inspect.plugins ? String(root.inspect.plugins.length) : "—"
        }
        QuickPill {
          width: parent.pillW
          icon: "󰅧"
          label: "传入"
          value: String(root.incomingCount)
          highlightColor: root.incomingCount > 0 ? root.accent : root.foreground
        }
        QuickPill {
          width: parent.pillW
          icon: "󰈸"
          label: "传出"
          value: String(root.outgoingCount)
          highlightColor: root.outgoingCount > 0 ? root.accent : root.foreground
        }
      }

      // First push. The generic action row below is hidden in this state so
      // there is exactly one obvious thing to press.
      CardBox {
        visible: root.syncState === "empty"
        border.width: 2
        border.color: root.accent

        GuideStep {
          step: "✓"
          title: "Repo linked"
          body: Model.repoName(root.status && root.status.repo_url) + " is connected and empty. Nothing has been pushed yet."
        }
        GuideStep {
          step: "2"
          title: "Check what goes up"
          body: root.outgoingPicked + " of " + root.outgoingCount + " items from this machine are ticked. Review list shows them. Display layout stays local unless you opt in."
        }
        GuideStep {
          step: "3"
          title: "Seed the repo"
          body: "Pushes the ticked items as the first commit. The repo stays private. On your next machine: Connect the same URL, then Apply."
        }
        Row {
          spacing: Style.space(8)
          Button {
            text: "Seed repo (" + root.outgoingPicked + " items)"
            iconText: "󰓂"
            tooltipText: "Push this machine's ticked items as the repo's first commit (p)"
            foreground: root.foreground
            fontFamily: root.fontFamily
            bordered: true
            selected: true
            enabled: !root.busy
            onClicked: root.requestPublish()
          }
          Button {
            text: "Review list"
            iconText: "󰦓"
            tooltipText: "Tick or untick items before seeding (c)"
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.reviewChanges()
          }
        }
      }

      Row {
        visible: root.syncState !== "empty"
        spacing: Style.space(8)

        Button {
          visible: root.syncState === "diverged" || root.syncState === "conflicts" || (root.incomingFiles.length + root.incomingBundles.length + root.incomingAddedShortcuts.length + root.incomingChangedShortcuts.length > 0 && root.localFiles.length + root.localBundles.length + root.localAddedShortcuts.length + root.localChangedShortcuts.length > 0)
          text: "从仓库重新同步"
          iconText: "󰁨"
          tooltipText: "让本机与 git 仓库保持一致。会先写入备份。"
          foreground: root.foreground
          fontFamily: root.fontFamily
          bordered: true
          enabled: !root.busy
          onClicked: root.confirmKind = "resync-repo"
        }
        Button {
          visible: root.hasReviewable
          text: "查看变更"
          iconText: "󰦓"
          tooltipText: "逐项挑选快捷键、插件与文件（c）"
          foreground: root.foreground
          fontFamily: root.fontFamily
          bordered: true
          onClicked: root.reviewChanges()
        }
        Button {
          visible: root.syncState !== "empty"
          text: "应用"
          iconText: "󰁨"
          tooltipText: "应用勾选的传入项（a）"
          foreground: root.foreground
          fontFamily: root.fontFamily
          bordered: true
          enabled: !root.busy
          onClicked: root.requestApply()
        }
        Button {
          text: "发布"
          iconText: "󰓂"
          tooltipText: "发布勾选的本机项（p）"
          foreground: root.foreground
          fontFamily: root.fontFamily
          bordered: true
          enabled: !root.busy
          onClicked: root.requestPublish()
        }
        Button {
          visible: root.status && Number(root.status.behind || 0) > 0
          text: "拉取"
          iconText: "󰁅"
          tooltipText: "将 origin 上的提交合并到本地克隆"
          foreground: root.foreground
          fontFamily: root.fontFamily
          bordered: true
          enabled: !root.busy
          onClicked: root.pullRemote()
        }
      }

      CardBox {
        Column {
          width: parent.width
          spacing: Style.space(6)

          Item {
            width: parent.width
            implicitHeight: Math.max(remoteLabel.implicitHeight, remoteVal.implicitHeight, editRepoBtn.implicitHeight)
            visible: !root.editingRepo

            Text {
              id: remoteLabel
              textFormat: Text.PlainText
              text: "远程"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              width: Math.min(Style.space(140), parent.width * 0.28)
            }
            Text {
              id: remoteVal
              textFormat: Text.PlainText
              text: String(root.status.repo_url || "—")
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideMiddle
              anchors.left: remoteLabel.right
              anchors.leftMargin: Style.space(8)
              anchors.right: editRepoBtn.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
            }
            Button {
              id: editRepoBtn
              text: "编辑"
              tooltipText: "使用其他 git 仓库"
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              enabled: !root.busy
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              onClicked: root.startEditRepo()
            }
          }

          Column {
            visible: root.editingRepo
            width: parent.width
            spacing: Style.space(8)
            onVisibleChanged: if (visible) repoEditField.forceActiveFocus()

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: "Git 仓库"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
            TextField {
              id: repoEditField
              width: parent.width
              placeholderText: "https://github.com/you/omarchy-config.git"
              text: root.repoUrlInput
              foreground: root.foreground
              font.family: root.fontFamily
              enabled: !root.busy
              onTextChanged: root.repoUrlInput = text
              onAccepted: root.saveEditRepo()
            }
            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: "支持 HTTPS、SSH、owner/repo 或本地路径。空的私有仓库可从本机初始化。"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
            Row {
              spacing: Style.space(8)
              Button {
                text: root.busy ? "切换中…" : "保存"
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                enabled: !root.busy && String(root.repoUrlInput).trim() !== ""
                onClicked: root.saveEditRepo()
              }
              Button {
                text: "取消"
                foreground: root.foreground
                fontFamily: root.fontFamily
                enabled: !root.busy
                onClicked: root.cancelEditRepo()
              }
            }
          }
        }
        TablePair { label: "分支"; value: String((root.status.branch || "—") + (root.status.head ? " @ " + root.status.head : "")) }
        TablePair { label: "领先 / 落后"; value: String(root.status.ahead || 0) + " / " + String(root.status.behind || 0) }
        TablePair { label: "上次应用"; value: Model.relativeAgo(root.status.last_apply_at) }
        TablePair { label: "上次发布"; value: Model.relativeAgo(root.status.last_publish_at) }
        TablePair { label: "插件"; value: "config-sync " + String((root.status && root.status.plugin_version) || "") }
        TablePair {
          label: "主题"
          value: {
            if (!root.inspect || !root.inspect.theme) return "—"
            var t = root.inspect.theme
            var name = t.display || t.slug || "—"
            return t.custom ? (name + "（自定义覆盖层）") : name
          }
        }
        TablePair { label: "栏位置"; value: root.inspect && root.inspect.bar ? String(root.inspect.bar.position || "—") : "—" }
        TablePair {
          label: "闲置锁定"
          value: root.inspect && root.inspect.idle && root.inspect.idle.lock
            ? (Number(root.inspect.idle.lock) / 60) + " 分钟"
            : "—"
        }
      }

      Text {
        visible: !!(root.status && root.status.fetch_error)
        width: parent.width
        textFormat: Text.PlainText
        text: "拉取：" + root.status.fetch_error
        color: root.urgent
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }

      Column {
        visible: root.hasReviewable
        width: parent.width
        spacing: Style.space(10)

        PanelSeparator { foreground: root.foreground }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: "传入来自 git（应用），传出发自本机（发布）。点击分组展开并逐项勾选。"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        ChangeSection {
          title: "传入"
          subtitle: "来自仓库 — 应用"
          mixed: true
          files: root.incomingItems
        }
        ChangeSection {
          title: "传出"
          subtitle: "本机 — 发布"
          mixed: true
          files: root.outgoingItems
        }
        ChangeSection {
          title: "两侧"
          subtitle: "在每行选择「保留本机」或「采用仓库」"
          mixed: true
          files: root.bothItems
          bulkPickable: false
        }
      }
    }
  }

  Component {
    id: tabChangesComp
    Column {
      width: parent.width
      spacing: Style.space(12)

      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: root.showingHidden
          ? "已隐藏的变更在同步时会被忽略。对任意条目点击「取消隐藏」即可恢复。"
          : "传入来自 git（应用），传出发自本机（发布）。分组默认折叠——点击展开后逐项勾选。开 = 同步该行，关 = 跳过。"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WordWrap
      }

      Text {
        visible: !root.showingHidden && root.unresolvedBoth > 0
        width: parent.width
        textFormat: Text.PlainText
        text: "两侧都有改动的勾选项，仍需选择「保留本机」或「采用仓库」。"
        color: root.urgent
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WordWrap
      }

      Row {
        spacing: Style.space(6)
        Button {
          text: "选择传入"
          fontSize: Style.font.caption
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: root.bulkPick("in")
        }
        Button {
          text: "选择本机"
          fontSize: Style.font.caption
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: root.bulkPick("out")
        }
        Button {
          text: "全选"
          fontSize: Style.font.caption
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: root.bulkPick("all")
        }
        Button {
          text: "清除"
          fontSize: Style.font.caption
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: root.bulkPick("none")
        }
        Button {
          text: root.showingHidden ? "进行中的变更" : ("已隐藏（" + root.hiddenCount + ")")
          iconText: root.showingHidden ? "󰦓" : "󰈉"
          fontSize: Style.font.caption
          foreground: root.foreground
          fontFamily: root.fontFamily
          selected: root.showingHidden
          bordered: true
          onClicked: root.showingHidden = !root.showingHidden
        }
      }

      Text {
        visible: !root.showingHidden && root.syncState === "empty"
        width: parent.width
        textFormat: Text.PlainText
        text: "First push: every ticked item under Outgoing becomes the repo's first commit. Untick anything you do not want on GitHub, then Seed repo."
        color: root.accent
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WordWrap
      }

      Row {
        visible: !root.showingHidden
        spacing: Style.space(8)
        Button {
          visible: root.syncState !== "empty"
          text: "应用所选"
          iconText: "󰁨"
          foreground: root.foreground
          fontFamily: root.fontFamily
          bordered: true
          enabled: !root.busy
          onClicked: root.requestApply()
        }
        Button {
          text: "发布所选"
          iconText: "󰓂"
          foreground: root.foreground
          fontFamily: root.fontFamily
          bordered: true
          enabled: !root.busy
          onClicked: root.requestPublish()
        }
      }

      Toggle {
        visible: !root.showingHidden
        width: parent.width
        label: "包含本机专属文件"
        description: "显示器布局（hypr/monitors.lua）与 .omarchy-config.json 中 machine_local 列出的额外路径会保留在本机，除非在此启用。"
        checked: root.includeMachine
        foreground: root.foreground
        accent: root.accent
        fontFamily: root.fontFamily
        titleSize: Style.font.body
        descriptionSize: Style.font.caption
        onClicked: {
          root.includeMachine = !root.includeMachine
          Qt.callLater(function() { root.seedPicks() })
        }
      }

      Column {
        visible: !root.showingHidden && root.conflictFiles.length > 0
        width: parent.width
        spacing: Style.space(6)
        PanelSectionHeader { text: "GIT 冲突"; foreground: root.foreground; fontFamily: root.fontFamily }
        Repeater {
          model: root.conflictFiles
          FileRow {
            required property var modelData
            width: parent.width
            pathLabel: String(modelData)
            summary: "未合并路径"
            statusLabel: "冲突"
            extra: conflictButtons
            property Component conflictButtons: Row {
              spacing: Style.space(4)
              Button {
                text: "保留本机"
                fontSize: Style.font.caption
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.resolveConflict(String(modelData), "ours")
              }
              Button {
                text: "采用传入"
                fontSize: Style.font.caption
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.resolveConflict(String(modelData), "theirs")
              }
            }
          }
        }
      }

      ChangeSection {
        visible: !root.showingHidden && root.incomingItems.length > 0
        title: "传入"
        subtitle: "来自仓库 — 应用"
        mixed: true
        files: root.incomingItems
      }
      ChangeSection {
        visible: !root.showingHidden && root.outgoingItems.length > 0
        title: "传出"
        subtitle: "本机 — 发布"
        mixed: true
        files: root.outgoingItems
      }
      ChangeSection {
        visible: !root.showingHidden && root.bothItems.length > 0
        title: "两侧"
        subtitle: "在每行选择「保留本机」或「采用仓库」"
        mixed: true
        files: root.bothItems
        bulkPickable: false
      }

      Column {
        visible: !root.showingHidden && !root.hasReviewable
        width: parent.width
        spacing: Style.space(8)
        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: root.hiddenCount > 0
            ? ("没有生效中的配置差异（" + root.hiddenCount + " 项已忽略）。")
            : "没有可移植的配置差异，本机与仓库一致。"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          horizontalAlignment: Text.AlignHCenter
        }
        Button {
          visible: root.hiddenCount > 0
          text: "查看已忽略的同步（" + root.hiddenCount + ")"
          iconText: "󰈉"
          foreground: root.foreground
          fontFamily: root.fontFamily
          fontSize: Style.font.caption
          bordered: true
          anchors.horizontalCenter: parent.horizontalCenter
          onClicked: root.showingHidden = true
        }
      }

      Column {
        visible: root.showingHidden
        width: parent.width
        spacing: Style.space(8)

        Row {
          width: parent.width
          spacing: Style.space(8)

          Item {
            width: parent.width - unhideAllBtn.width - parent.spacing
            implicitHeight: hiddenDescCol.implicitHeight
            anchors.verticalCenter: parent.verticalCenter
            Column {
              id: hiddenDescCol
              width: parent.width
              spacing: 2
              Text {
                textFormat: Text.PlainText
                text: "已隐藏的同步（" + root.hiddenCount + ")"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: "这些变更已被忽略，不会同步。"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }
            }
          }

          Button {
            id: unhideAllBtn
            text: "全部取消隐藏"
            iconText: "󰈈"
            fontSize: Style.font.caption
            foreground: root.foreground
            fontFamily: root.fontFamily
            enabled: !root.busy && root.hiddenCount > 0
            bordered: true
            anchors.verticalCenter: parent.verticalCenter
            onClicked: root.unhideAll()
          }
        }

        Text {
          visible: root.hiddenCount === 0
          width: parent.width
          textFormat: Text.PlainText
          text: "没有已隐藏的变更。对任意传入或传出变更点击「隐藏」即可忽略。"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          horizontalAlignment: Text.AlignHCenter
        }

        Repeater {
          model: root.hiddenItems
          Rectangle {
            id: hiddenRowBox
            required property var modelData
            width: parent.width
            implicitHeight: hiddenRowInner.implicitHeight + Style.space(16)
            radius: Style.cornerRadius
            color: root.cardBg
            border.width: 1
            border.color: root.cardBorder

            Row {
              id: hiddenRowInner
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(10)
              anchors.rightMargin: Style.space(10)
              spacing: Style.space(10)

              Column {
                width: parent.width - unhideRowBtn.width - parent.spacing
                spacing: 2
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  width: parent.width
                  textFormat: Text.PlainText
                  text: (hiddenRowBox.modelData.typeLabel ? hiddenRowBox.modelData.typeLabel + "  ·  " : "") + hiddenRowBox.modelData.label
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                  wrapMode: Text.WordWrap
                }
                Text {
                  width: parent.width
                  textFormat: Text.PlainText
                  text: {
                    var st = Model.fileStatusLabel(hiddenRowBox.modelData.status, hiddenRowBox.modelData.removal)
                    var sum = String(hiddenRowBox.modelData.summary || "")
                    return (st ? st + " · " : "") + sum + " · Ignored"
                  }
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.WordWrap
                }
              }

              Button {
                id: unhideRowBtn
                text: "取消隐藏"
                iconText: "󰈈"
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                anchors.verticalCenter: parent.verticalCenter
                enabled: !root.busy
                onClicked: root.unhideItem(hiddenRowBox.modelData.kind, hiddenRowBox.modelData.itemId)
              }
            }
          }
        }
      }
    }
  }

  Component {
    id: shortcutsExtraComp
    Column {
      width: parent.width
      spacing: Style.space(6)
      PanelSectionHeader { text: "键盘绑定（" + (root.inspect && root.inspect.shortcuts ? root.inspect.shortcuts.length : 0) + ")"; foreground: root.foreground; fontFamily: root.fontFamily }
      Text {
        textFormat: Text.PlainText
        visible: !root.inspect || !root.inspect.shortcuts || root.inspect.shortcuts.length === 0
        text: "hypr/bindings.lua 中未找到 o.bind() 快捷键。"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
      }
      Repeater {
        model: root.inspect && root.inspect.shortcuts ? root.inspect.shortcuts : []
        CardBox {
          required property var modelData
          Row {
            width: parent.width
            spacing: Style.space(8)
            Text {
              textFormat: Text.PlainText
              text: modelData.keys
              color: root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
              width: parent.width * 0.42
              wrapMode: Text.WordWrap
            }
            Text {
              textFormat: Text.PlainText
              text: modelData.label
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              width: parent.width * 0.38
              wrapMode: Text.WordWrap
            }
            Row {
              spacing: Style.space(4)
              anchors.verticalCenter: parent.verticalCenter
              Rectangle {
                width: Style.space(30)
                height: Style.space(28)
                radius: Style.cornerRadius > 0 ? Style.space(4) : 0
                color: scFmMa.containsMouse ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22) : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
                border.width: 1
                border.color: scFmMa.containsMouse ? root.accent : root.cardBorder
                Text {
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: "󰉋"
                  color: scFmMa.containsMouse ? root.accent : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }
                MouseArea {
                  id: scFmMa
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.openFile("hypr/bindings.lua", "", "")
                }
              }
              Rectangle {
                width: Style.space(30)
                height: Style.space(28)
                radius: Style.cornerRadius > 0 ? Style.space(4) : 0
                color: scTermMa.containsMouse ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22) : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
                border.width: 1
                border.color: scTermMa.containsMouse ? root.accent : root.cardBorder
                Text {
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: "󰞷"
                  color: scTermMa.containsMouse ? root.accent : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }
                MouseArea {
                  id: scTermMa
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.openTerminal("hypr/bindings.lua", "", "")
                }
              }
            }
          }
        }
      }
    }
  }

  Component {
    id: pluginsExtraComp
    Column {
      width: parent.width
      spacing: Style.space(6)
      PanelSectionHeader { text: "已安装插件（" + (root.inspect && root.inspect.plugins ? root.inspect.plugins.length : 0) + ")"; foreground: root.foreground; fontFamily: root.fontFamily }
      Text {
        textFormat: Text.PlainText
        visible: !root.inspect || !root.inspect.plugins || root.inspect.plugins.length === 0
        text: "plugins/ 中没有额外插件。"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
      }
      Repeater {
        model: root.inspect && root.inspect.plugins ? root.inspect.plugins : []
        CardBox {
          required property var modelData
          Column {
            width: parent.width
            spacing: Style.space(4)
            Row {
              width: parent.width
              spacing: Style.space(8)
              Text {
                textFormat: Text.PlainText
                text: modelData.name || modelData.id
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
                elide: Text.ElideRight
                width: parent.width - ver.implicitWidth - Style.space(74)
              }
              Text {
                id: ver
                textFormat: Text.PlainText
                text: modelData.version || ""
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                anchors.verticalCenter: parent.verticalCenter
              }
              Row {
                spacing: Style.space(4)
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                  width: Style.space(30)
                  height: Style.space(28)
                  radius: Style.cornerRadius > 0 ? Style.space(4) : 0
                  color: plFmMa.containsMouse ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22) : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
                  border.width: 1
                  border.color: plFmMa.containsMouse ? root.accent : root.cardBorder
                  Text {
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: "󰉋"
                    color: plFmMa.containsMouse ? root.accent : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                  }
                  MouseArea {
                    id: plFmMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openFile("plugins/" + modelData.id, "", "")
                  }
                }
                Rectangle {
                  width: Style.space(30)
                  height: Style.space(28)
                  radius: Style.cornerRadius > 0 ? Style.space(4) : 0
                  color: plTermMa.containsMouse ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22) : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
                  border.width: 1
                  border.color: plTermMa.containsMouse ? root.accent : root.cardBorder
                  Text {
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: "󰞷"
                    color: plTermMa.containsMouse ? root.accent : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                  }
                  MouseArea {
                    id: plTermMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openTerminal("plugins/" + modelData.id, "", "")
                  }
                }
              }
            }
            Text {
              visible: String(modelData.description || "") !== ""
              width: parent.width
              textFormat: Text.PlainText
              text: modelData.description
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: modelData.id + (modelData.git && modelData.source ? "  ·  git: " + modelData.source : "")
                + (modelData.git && !modelData.installed ? "  ·  not installed here" : "")
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WrapAnywhere
            }
            Button {
              visible: !!modelData.git && !modelData.installed && String(modelData.source || "") !== ""
              text: "Install"
              iconText: "󰏗"
              tooltipText: "Open Omarchy's plugin installer in a terminal"
              bordered: true
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              enabled: !root.busy
              onClicked: root.runPluginAction("install", String(modelData.id))
            }
          }
        }
      }

      PanelSectionHeader {
        visible: root.inspect && root.inspect.bar
        text: "栏布局"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }
      Repeater {
        model: ["left", "center", "right"]
        Column {
          required property var modelData
          width: parent.width
          spacing: Style.space(4)
          visible: root.inspect && root.inspect.bar && root.inspect.bar.widgets && (root.inspect.bar.widgets[modelData] || []).length > 0
          Text {
            textFormat: Text.PlainText
            text: modelData.toUpperCase()
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }
          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: root.inspect && root.inspect.bar && root.inspect.bar.widgets ? (root.inspect.bar.widgets[modelData] || []).join("  ·  ") : ""
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }

  Component {
    id: hooksExtraComp
    Column {
      width: parent.width
      spacing: Style.space(6)
      PanelSectionHeader { text: "钩子（" + (root.inspect && root.inspect.hooks ? root.inspect.hooks.length : 0) + ")"; foreground: root.foreground; fontFamily: root.fontFamily }
      Text {
        textFormat: Text.PlainText
        visible: !root.inspect || !root.inspect.hooks || root.inspect.hooks.length === 0
        text: "omarchy/hooks/ 中没有事件钩子。"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
      }
      Repeater {
        model: root.inspect && root.inspect.hooks ? root.inspect.hooks : []
        FileRow {
          required property var modelData
          width: parent.width
          pathLabel: modelData.event + "/" + modelData.name
          localPath: "~/.config/omarchy/hooks/" + modelData.event + ".d/" + modelData.name
          summary: modelData.sample ? "示例钩子脚本" : "当前启用的钩子脚本"
          statusLabel: modelData.sample ? "示例" : "钩子"
        }
      }
    }
  }

  Component {
    id: binsExtraComp
    Column {
      width: parent.width
      spacing: Style.space(6)
      PanelSectionHeader { text: "辅助脚本（" + (root.inspect && root.inspect.bins ? root.inspect.bins.length : 0) + ")"; foreground: root.foreground; fontFamily: root.fontFamily }
      Text {
        textFormat: Text.PlainText
        visible: !root.inspect || !root.inspect.bins || root.inspect.bins.length === 0
        text: "bin/ 中没有脚本。"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
      }
      Repeater {
        model: root.inspect && root.inspect.bins ? root.inspect.bins : []
        FileRow {
          required property var modelData
          width: parent.width
          pathLabel: "bin/" + String(modelData)
          localPath: "~/.local/bin/" + String(modelData)
          summary: "~/.local/bin/ 中的自定义脚本"
          statusLabel: "脚本"
        }
      }
    }
  }

  Component {
    id: tabConfigsComp
    Column {
      width: parent.width
      spacing: Style.space(12)

      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: "仓库与本机跟踪的全部配置区域，按类别分组。点击任意类别可查看变更并检查设置。"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WordWrap
      }

      CategorySection {
        categoryId: "shortcuts"
        iconText: "󰌌"
        title: "快捷键"
        subtitle: "键盘快捷键（hypr/bindings.lua）"
        changeItems: Model.itemsForCategory(root.allReviewItems, "shortcuts")
        files: Model.filesForCategory(root.diffFiles, "shortcuts")
        inspectItems: root.inspect ? root.inspect.shortcuts : []
        extraContent: shortcutsExtraComp
      }

      CategorySection {
        categoryId: "theme"
        iconText: "󰏘"
        title: "主题"
        subtitle: "当前主题与自定义主题样式（omarchy/theme.name）"
        changeItems: Model.itemsForCategory(root.allReviewItems, "theme")
        files: Model.filesForCategory(root.diffFiles, "theme")
      }

      CategorySection {
        categoryId: "plugins"
        iconText: "󰐱"
        title: "插件与栏"
        subtitle: "Shell 插件、小组件与栏布局（plugins/）"
        changeItems: Model.itemsForCategory(root.allReviewItems, "plugins")
        files: Model.filesForCategory(root.diffFiles, "plugins")
        inspectItems: root.inspect ? root.inspect.plugins : []
        extraContent: pluginsExtraComp
      }

      CategorySection {
        categoryId: "displays"
        iconText: "󰍹"
        title: "显示器"
        subtitle: "显示器布局与规则（hypr/monitors.lua）"
        changeItems: Model.itemsForCategory(root.allReviewItems, "displays")
        files: Model.filesForCategory(root.diffFiles, "displays")
      }

      CategorySection {
        categoryId: "hyprland"
        iconText: "󰒓"
        title: "Hyprland 配置"
        subtitle: "间距、动画、窗口规则、输入、自启动（hypr/）"
        changeItems: Model.itemsForCategory(root.allReviewItems, "hyprland")
        files: Model.filesForCategory(root.diffFiles, "hyprland")
      }

      CategorySection {
        categoryId: "shell"
        iconText: "󰘿"
        title: "Shell 与栏"
        subtitle: "栏布局、小组件与闲置设置（omarchy/shell.json）"
        changeItems: Model.itemsForCategory(root.allReviewItems, "shell")
        files: Model.filesForCategory(root.diffFiles, "shell")
      }

      CategorySection {
        categoryId: "terminals"
        iconText: "󰞷"
        title: "终端"
        subtitle: "Alacritty、Foot、Ghostty 与 Kitty 配置（terminals/）"
        changeItems: Model.itemsForCategory(root.allReviewItems, "terminals")
        files: Model.filesForCategory(root.diffFiles, "terminals")
      }

      CategorySection {
        categoryId: "hooks"
        iconText: "󰓢"
        title: "钩子"
        subtitle: "事件自动化脚本（omarchy/hooks/）"
        changeItems: Model.itemsForCategory(root.allReviewItems, "hooks")
        files: Model.filesForCategory(root.diffFiles, "hooks")
        inspectItems: root.inspect ? root.inspect.hooks : []
        extraContent: hooksExtraComp
      }

      CategorySection {
        categoryId: "scripts"
        iconText: "󰲋"
        title: "辅助脚本"
        subtitle: "~/.local/bin/ 中的自定义脚本（bin/）"
        changeItems: Model.itemsForCategory(root.allReviewItems, "scripts")
        files: Model.filesForCategory(root.diffFiles, "scripts")
        inspectItems: root.inspect ? root.inspect.bins : []
        extraContent: binsExtraComp
      }

      CategorySection {
        categoryId: "other"
        iconText: "󰉋"
        title: "其他配置"
        subtitle: "其他受跟踪的配置文件"
        changeItems: Model.itemsForCategory(root.allReviewItems, "other")
        files: Model.filesForCategory(root.diffFiles, "other")
      }
    }
  }

  component GuideStep: Row {
    property string step: ""
    property string title: ""
    property string body: ""
    width: parent ? parent.width : 100
    spacing: Style.space(10)

    Rectangle {
      width: Style.space(22)
      height: Style.space(22)
      radius: width / 2
      color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18)
      anchors.top: parent.top
      Text {
        textFormat: Text.PlainText
        anchors.centerIn: parent
        text: step
        color: root.accent
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }
    }

    Column {
      width: parent.width - Style.space(32)
      spacing: Style.space(3)
      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: title
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: true
        wrapMode: Text.WordWrap
      }
      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: body
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }
    }
  }

  component CategorySection: Column {
    id: catRoot
    property string categoryId: ""
    property string iconText: "󰒓"
    property string title: ""
    property string subtitle: ""
    property var changeItems: []
    property var files: []
    property var inspectItems: []
    property bool expanded: false
    property Component extraContent: null

    readonly property int totalCount: changeItems.length + files.length + (inspectItems ? inspectItems.length : 0)
    width: parent ? parent.width : 100
    spacing: Style.space(8)
    visible: totalCount > 0

    Rectangle {
      width: parent.width
      implicitHeight: catHeaderInner.implicitHeight + Style.space(14)
      radius: Style.cornerRadius
      color: catHeaderMa.containsMouse || catRoot.expanded
        ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.12)
        : root.cardBg
      border.width: catRoot.expanded ? 2 : 1
      border.color: catRoot.expanded ? root.accent : root.cardBorder

      Row {
        id: catHeaderInner
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Style.space(12)
        anchors.rightMargin: Style.space(12)
        spacing: Style.space(10)

        Text {
          textFormat: Text.PlainText
          text: catRoot.expanded ? "▼" : "▶"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(16)
        }

        Text {
          textFormat: Text.PlainText
          text: catRoot.iconText
          color: root.accent
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodyLarge
          anchors.verticalCenter: parent.verticalCenter
        }

        Column {
          width: parent.width - Style.space(16) - Style.space(24) - catCountCol.width - parent.spacing * 3
          spacing: 2
          anchors.verticalCenter: parent.verticalCenter
          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: catRoot.title
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            font.bold: true
            elide: Text.ElideRight
          }
          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: {
              var bits = []
              if (catRoot.subtitle) bits.push(catRoot.subtitle)
              if (catRoot.changeItems.length > 0)
                bits.push(catRoot.changeItems.length + (catRoot.changeItems.length === 1 ? " change" : " changes"))
              else
                bits.push("已同步")
              bits.push(catRoot.expanded ? "点击收起" : "点击展开")
              return bits.join(" · ")
            }
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }

        Column {
          id: catCountCol
          spacing: 0
          anchors.verticalCenter: parent.verticalCenter
          Text {
            textFormat: Text.PlainText
            text: catRoot.changeItems.length > 0 ? (String(catRoot.changeItems.length) + " 󰦓") : String(catRoot.totalCount)
            color: catRoot.changeItems.length > 0 ? root.accent : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            font.bold: true
            horizontalAlignment: Text.AlignRight
            anchors.right: parent.right
          }
          Text {
            textFormat: Text.PlainText
            text: catRoot.changeItems.length > 0 ? (catRoot.changeItems.length === 1 ? "处变更" : "处变更") : (catRoot.totalCount === 1 ? "个条目" : "个条目")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignRight
            anchors.right: parent.right
          }
        }
      }

      MouseArea {
        id: catHeaderMa
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: catRoot.expanded = !catRoot.expanded
      }
    }

    Column {
      visible: catRoot.expanded
      width: parent.width
      spacing: Style.space(8)

      // Pending changes section if any
      Column {
        visible: catRoot.changeItems.length > 0
        width: parent.width
        spacing: Style.space(6)
        PanelSectionHeader { text: "待处理变更（" + catRoot.changeItems.length + ")"; foreground: root.foreground; fontFamily: root.fontFamily }
        Repeater {
          model: catRoot.changeItems
          Rectangle {
            id: catRowBox
            required property var modelData
            required property int index

            readonly property string rowKind: String(modelData.kind || "f")
            readonly property string rowId: String(modelData.itemId || "")
            readonly property string rowLabel: String(modelData.label || "")
            readonly property string rowSummary: String(modelData.summary || "")
            readonly property bool rowBoth: !!modelData.both
            readonly property bool included: !!(root.picks[root.pickId(rowKind, rowId)])
            readonly property string bothKey: rowKind === "f" ? rowId : (rowKind + ":" + rowId)
            readonly property string typeLabel: String(modelData.typeLabel || "")
            readonly property bool pickable: modelData.pickable !== false
            readonly property string rowAction: String(modelData.action || "")

            width: catRoot.width
            implicitHeight: catRowInner.implicitHeight + Style.space(16)
            radius: Style.cornerRadius
            color: included ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.12) : root.cardBg
            border.width: 2
            border.color: included ? root.accent : root.foreground

            Row {
              id: catRowInner
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(10)
              anchors.rightMargin: Style.space(10)
              spacing: Style.space(10)

              Rectangle {
                width: 28
                height: 28
                radius: 4
                anchors.verticalCenter: parent.verticalCenter
                visible: catRowBox.pickable
                color: catRowBox.included ? root.accent : Color.background
                border.width: 2
                border.color: root.foreground

                Text {
                  textFormat: Text.PlainText
                  anchors.centerIn: parent
                  text: catRowBox.included ? "✓" : ""
                  color: Color.background
                  font.family: root.fontFamily
                  font.pixelSize: 18
                  font.bold: true
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.togglePick(catRowBox.rowKind, catRowBox.rowId)
                }
              }

              Column {
                width: parent.width - (catRowBox.pickable ? 28 + catIncludeBtn.width : 0) - (catActionBtn.visible ? catActionBtn.width : 0) - catHideBtn.width - (catRowBox.rowBoth ? 168 : 0) - parent.spacing * (1 + (catRowBox.pickable ? 2 : 0) + (catActionBtn.visible ? 1 : 0) + (catRowBox.rowBoth ? 1 : 0))
                spacing: 2
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  width: parent.width
                  textFormat: Text.PlainText
                  text: (catRowBox.typeLabel ? catRowBox.typeLabel + "  ·  " : "") + catRowBox.rowLabel
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                  wrapMode: Text.WordWrap
                }
                Text {
                  width: parent.width
                  textFormat: Text.PlainText
                  text: {
                    var st = Model.fileStatusLabel(catRowBox.modelData.status, catRowBox.modelData.removal)
                    var sum = catRowBox.rowSummary
                    var verb = catRowBox.modelData.removal ? " · 将删除" : " · 将同步"
                    if (!catRowBox.pickable) return Model.statusPrefix(st, sum) + sum
                    return Model.statusPrefix(st, sum) + sum + (catRowBox.included ? verb : " · 已跳过")
                  }
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.WordWrap
                }

                Flow {
                  visible: catRowBox.modelData && catRowBox.modelData.changes && catRowBox.modelData.changes.length > 0
                  width: parent.width
                  spacing: Style.space(4)
                  Repeater {
                    model: (catRowBox.modelData && catRowBox.modelData.changes) ? catRowBox.modelData.changes : []
                    Rectangle {
                      radius: Style.cornerRadius > 0 ? Style.space(4) : 2
                      color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.15)
                      border.width: 1
                      border.color: root.accent
                      implicitWidth: Math.min(parent.width, catChangeText.implicitWidth + Style.space(10))
                      implicitHeight: catChangeText.implicitHeight + Style.space(4)
                      Text {
                        id: catChangeText
                        anchors.centerIn: parent
                        width: Math.max(0, parent.width - Style.space(10))
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                        text: String(modelData)
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                      }
                    }
                  }
                }
              }

              Row {
                visible: catRowBox.rowBoth && catRowBox.pickable
                spacing: Style.space(4)
                anchors.verticalCenter: parent.verticalCenter
                Button {
                  text: "保留本机"
                  fontSize: Style.font.caption
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  selected: root.bothPicks[catRowBox.bothKey] === "local"
                  bordered: true
                  onClicked: root.selectSide(catRowBox.rowKind, catRowBox.rowId, "local")
                }
                Button {
                  text: "采用仓库"
                  fontSize: Style.font.caption
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  selected: root.bothPicks[catRowBox.bothKey] === "repo"
                  bordered: true
                  onClicked: root.selectSide(catRowBox.rowKind, catRowBox.rowId, "repo")
                }
              }

              Button {
                id: catActionBtn
                visible: catRowBox.rowAction !== ""
                text: Model.pluginActionLabel(catRowBox.rowAction)
                iconText: Model.pluginActionIcon(catRowBox.rowAction)
                tooltipText: Model.pluginActionTip(catRowBox.rowAction)
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                anchors.verticalCenter: parent.verticalCenter
                enabled: !root.busy
                onClicked: root.runPluginAction(catRowBox.rowAction, catRowBox.rowId)
              }

              Button {
                id: catIncludeBtn
                visible: catRowBox.pickable
                text: catRowBox.included ? "已包含" : "跳过"
                selected: catRowBox.included
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                anchors.verticalCenter: parent.verticalCenter
                onClicked: root.togglePick(catRowBox.rowKind, catRowBox.rowId)
              }

              Button {
                id: catHideBtn
                text: "隐藏"
                iconText: "󰈉"
                tooltipText: "隐藏此变更，不再提示"
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                anchors.verticalCenter: parent.verticalCenter
                enabled: !root.busy
                onClicked: root.hideItem(catRowBox.rowKind, catRowBox.rowId)
              }
            }

            MouseArea {
              z: -1
              anchors.fill: parent
              enabled: catRowBox.pickable
              cursorShape: Qt.PointingHandCursor
              onClicked: root.togglePick(catRowBox.rowKind, catRowBox.rowId)
            }
          }
        }
      }

      // Tracked files & settings
      Loader {
        visible: catRoot.extraContent !== null
        width: parent.width
        sourceComponent: catRoot.extraContent
      }

      Column {
        visible: catRoot.extraContent === null && catRoot.files.length > 0
        width: parent.width
        spacing: Style.space(6)
        PanelSectionHeader { text: "受跟踪文件（" + catRoot.files.length + ")"; foreground: root.foreground; fontFamily: root.fontFamily }
        Repeater {
          model: catRoot.files
          FileRow {
            required property var modelData
            width: parent.width
            pathLabel: modelData.path
            localPath: modelData.local_path || ""
            repoPath: modelData.repo_path || ""
            summary: modelData.summary
            statusLabel: Model.fileStatusLabel(modelData.status, modelData.removal) + (modelData.portable ? "" : " · 设备专属")
          }
        }
      }
    }
  }

  component ChangeSection: Column {
    id: sectionRoot
    property string title: ""
    property string subtitle: ""
    property var files: []
    property bool both: false
    property bool mixed: false
    property string kind: "f"
    property string idField: "path"
    property string labelField: "path"
    property string summaryField: "summary"
    property bool expanded: false
    property bool bulkPickable: true
    readonly property int includedCount: {
      var _ = root.picks
      return Model.pickedInItems(sectionRoot.mixed ? files : [], root.picks)
    }
    width: parent ? parent.width : 100
    spacing: Style.space(8)
    visible: files && files.length > 0

    Rectangle {
      width: parent.width
      implicitHeight: headerInner.implicitHeight + Style.space(14)
      radius: Style.cornerRadius
      color: headerMa.containsMouse || sectionRoot.expanded
        ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.12)
        : root.cardBg
      border.width: sectionRoot.expanded ? 2 : 1
      border.color: sectionRoot.expanded ? root.accent : root.cardBorder

      Row {
        id: headerInner
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Style.space(12)
        anchors.rightMargin: Style.space(12)
        spacing: Style.space(10)

        Text {
          textFormat: Text.PlainText
          text: sectionRoot.expanded ? "▼" : "▶"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(16)
        }

        Column {
          width: parent.width - Style.space(16) - countCol.width - parent.spacing * 2
          spacing: 2
          anchors.verticalCenter: parent.verticalCenter
          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: sectionRoot.title
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            font.bold: true
            elide: Text.ElideRight
          }
          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: {
              var bits = []
              if (sectionRoot.subtitle) bits.push(sectionRoot.subtitle)
              if (sectionRoot.mixed)
                bits.push(sectionRoot.includedCount + " 项已包含")
              bits.push(sectionRoot.expanded ? "点击收起" : "点击展开")
              return bits.join(" · ")
            }
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }

        Column {
          id: countCol
          spacing: 0
          anchors.verticalCenter: parent.verticalCenter
          Text {
            textFormat: Text.PlainText
            text: String(sectionRoot.files ? sectionRoot.files.length : 0)
            color: root.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            font.bold: true
            horizontalAlignment: Text.AlignRight
            anchors.right: parent.right
          }
          Text {
            textFormat: Text.PlainText
            text: (sectionRoot.files && sectionRoot.files.length === 1) ? "个条目" : "个条目"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignRight
            anchors.right: parent.right
          }
        }
      }

      MouseArea {
        id: headerMa
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: sectionRoot.expanded = !sectionRoot.expanded
      }
    }

    Row {
      visible: sectionRoot.expanded && sectionRoot.mixed && sectionRoot.bulkPickable
      spacing: Style.space(6)
      Button {
        text: "Select all"
        iconText: "󰒆"
        tooltipText: "Tick every item in " + sectionRoot.title
        fontSize: Style.font.caption
        foreground: root.foreground
        fontFamily: root.fontFamily
        bordered: true
        enabled: sectionRoot.includedCount < sectionRoot.files.length
        onClicked: root.pickItems(sectionRoot.files, true)
      }
      Button {
        text: "Select none"
        iconText: "󰒇"
        tooltipText: "Untick every item in " + sectionRoot.title
        fontSize: Style.font.caption
        foreground: root.foreground
        fontFamily: root.fontFamily
        bordered: true
        enabled: sectionRoot.includedCount > 0
        onClicked: root.pickItems(sectionRoot.files, false)
      }
    }

    Repeater {
      model: sectionRoot.expanded ? files : []

      Rectangle {
        id: rowBox
        required property var modelData
        required property int index

        readonly property string rowKind: sectionRoot.mixed ? String(modelData.kind || sectionRoot.kind) : sectionRoot.kind
        readonly property string rowId: sectionRoot.mixed ? String(modelData.itemId || "") : String(modelData[sectionRoot.idField] || "")
        readonly property string rowLabel: sectionRoot.mixed ? String(modelData.label || "") : String(modelData[sectionRoot.labelField] || "")
        readonly property string rowSummary: {
          if (sectionRoot.mixed) return String(modelData.summary || "")
          var sum = String(modelData[sectionRoot.summaryField] || "")
          if (sectionRoot.kind === "p")
            sum = sum + " · " + String(modelData.changed_count || 0) + " 个文件"
          return sum
        }
        readonly property bool rowBoth: sectionRoot.mixed ? !!modelData.both : sectionRoot.both
        readonly property bool included: !!(root.picks[root.pickId(rowKind, rowId)])
        readonly property string bothKey: rowKind === "f" ? rowId : (rowKind + ":" + rowId)
        readonly property string typeLabel: sectionRoot.mixed ? String(modelData.typeLabel || "") : ""
        readonly property bool pickable: modelData.pickable !== false
        readonly property string rowAction: String(modelData.action || "")

        width: sectionRoot.width
        implicitHeight: rowInner.implicitHeight + Style.space(16)
        radius: Style.cornerRadius
        color: included ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.12) : root.cardBg
        border.width: 2
        border.color: included ? root.accent : root.foreground

        Row {
          id: rowInner
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          spacing: Style.space(10)

          Rectangle {
            width: 28
            height: 28
            radius: 4
            anchors.verticalCenter: parent.verticalCenter
            visible: rowBox.pickable
            color: rowBox.included ? root.accent : Color.background
            border.width: 2
            border.color: root.foreground

            Text {
              textFormat: Text.PlainText
              anchors.centerIn: parent
              text: rowBox.included ? "✓" : ""
              color: Color.background
              font.family: root.fontFamily
              font.pixelSize: 18
              font.bold: true
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.togglePick(rowBox.rowKind, rowBox.rowId)
            }
          }

          Column {
            width: parent.width - (rowBox.pickable ? 28 + includeBtn.width : 0) - (actionBtn.visible ? actionBtn.width : 0) - hideBtn.width - (rowBox.rowBoth ? 168 : 0) - parent.spacing * (1 + (rowBox.pickable ? 2 : 0) + (actionBtn.visible ? 1 : 0) + (rowBox.rowBoth ? 1 : 0))
            spacing: 2
            anchors.verticalCenter: parent.verticalCenter

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: (rowBox.typeLabel ? rowBox.typeLabel + "  ·  " : "") + rowBox.rowLabel
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
              wrapMode: Text.WordWrap
            }
            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: {
                var st = Model.fileStatusLabel(rowBox.modelData.status, rowBox.modelData.removal)
                var sum = rowBox.rowSummary
                var verb = rowBox.modelData.removal ? " · 将删除" : " · 将同步"
                if (!rowBox.pickable) return Model.statusPrefix(st, sum) + sum
                return Model.statusPrefix(st, sum) + sum + (rowBox.included ? verb : " · 已跳过")
              }
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            Flow {
              visible: rowBox.modelData && rowBox.modelData.changes && rowBox.modelData.changes.length > 0
              width: parent.width
              spacing: Style.space(4)
              Repeater {
                model: (rowBox.modelData && rowBox.modelData.changes) ? rowBox.modelData.changes : []
                Rectangle {
                  radius: Style.cornerRadius > 0 ? Style.space(4) : 2
                  color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.15)
                  border.width: 1
                  border.color: root.accent
                  implicitWidth: Math.min(parent.width, changeText.implicitWidth + Style.space(10))
                  implicitHeight: changeText.implicitHeight + Style.space(4)
                  Text {
                    id: changeText
                    anchors.centerIn: parent
                    width: Math.max(0, parent.width - Style.space(10))
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                    text: String(modelData)
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }
              }
            }
          }

          Row {
            visible: rowBox.rowBoth && rowBox.pickable
            spacing: Style.space(4)
            anchors.verticalCenter: parent.verticalCenter
            Button {
              text: "保留本机"
              fontSize: Style.font.caption
              foreground: root.foreground
              fontFamily: root.fontFamily
              selected: root.bothPicks[rowBox.bothKey] === "local"
              bordered: true
              onClicked: root.selectSide(rowBox.rowKind, rowBox.rowId, "local")
            }
            Button {
              text: "采用仓库"
              fontSize: Style.font.caption
              foreground: root.foreground
              fontFamily: root.fontFamily
              selected: root.bothPicks[rowBox.bothKey] === "repo"
              bordered: true
              onClicked: root.selectSide(rowBox.rowKind, rowBox.rowId, "repo")
            }
          }

          Button {
            id: actionBtn
            visible: rowBox.rowAction !== ""
            text: Model.pluginActionLabel(rowBox.rowAction)
            iconText: Model.pluginActionIcon(rowBox.rowAction)
            tooltipText: Model.pluginActionTip(rowBox.rowAction)
            bordered: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            fontSize: Style.font.caption
            anchors.verticalCenter: parent.verticalCenter
            enabled: !root.busy
            onClicked: root.runPluginAction(rowBox.rowAction, rowBox.rowId)
          }

          Button {
            id: includeBtn
            visible: rowBox.pickable
            text: rowBox.included ? "已包含" : "跳过"
            selected: rowBox.included
            bordered: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            fontSize: Style.font.caption
            anchors.verticalCenter: parent.verticalCenter
            onClicked: root.togglePick(rowBox.rowKind, rowBox.rowId)
          }

          Button {
            id: hideBtn
            text: "隐藏"
            iconText: "󰈉"
            tooltipText: "隐藏此变更，不再提示"
            bordered: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            fontSize: Style.font.caption
            anchors.verticalCenter: parent.verticalCenter
            enabled: !root.busy
            onClicked: root.hideItem(rowBox.rowKind, rowBox.rowId)
          }
        }

        MouseArea {
          z: -1
          anchors.fill: parent
          enabled: rowBox.pickable
          cursorShape: Qt.PointingHandCursor
          onClicked: root.togglePick(rowBox.rowKind, rowBox.rowId)
        }
      }
    }
  }

  component PickRow: Rectangle {
    id: pickRoot
    property string kind: "f"
    property string itemId: ""
    property string pathLabel: ""
    property string summary: ""
    property string statusLabel: ""
    property bool both: false
    readonly property bool checked: root.isPicked(kind, itemId)
    readonly property string bothKey: kind === "f" ? itemId : (kind + ":" + itemId)
    readonly property string direction: {
      var s = String(statusLabel || "")
      if (s.indexOf("仓库") !== -1) return "in"
      if (s.indexOf("本机") !== -1 || s.indexOf("仅本机") !== -1) return "out"
      if (s.indexOf("两侧") !== -1) return "both"
      return ""
    }

    width: parent ? parent.width : 100
    implicitHeight: innerCol.implicitHeight + Style.space(14)
    radius: Style.cornerRadius
    color: checked ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.10) : root.cardBg
    border.width: 1
    border.color: checked ? root.accent : root.cardBorder

    Column {
      id: innerCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      anchors.topMargin: Style.space(8)
      spacing: Style.space(8)

      Row {
        width: parent.width
        spacing: Style.space(10)

        // Visible checkbox: 22px square, strong border, label beside it.
        Item {
          width: Style.space(22)
          height: Style.space(22)
          anchors.verticalCenter: parent.verticalCenter

          Rectangle {
            anchors.fill: parent
            radius: 4
            color: pickRoot.checked ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
            border.width: 2
            border.color: pickRoot.checked ? root.accent : root.foreground
          }
          Text {
            textFormat: Text.PlainText
            anchors.centerIn: parent
            text: pickRoot.checked ? "✓" : ""
            color: Color.background
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            font.bold: true
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.togglePick(pickRoot.kind, pickRoot.itemId)
          }
        }

        Column {
          width: parent.width - Style.space(22) - Style.space(10) - includeSwitch.width - Style.space(10)
          spacing: 2
          anchors.verticalCenter: parent.verticalCenter

          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: pickRoot.pathLabel
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: true
            wrapMode: Text.WordWrap
          }
          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: {
              var bits = []
              if (pickRoot.statusLabel) bits.push(pickRoot.statusLabel)
              if (pickRoot.summary) bits.push(pickRoot.summary)
              bits.push(pickRoot.checked ? "将同步" : "已跳过")
              return bits.join(" · ")
            }
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }

        Column {
          id: includeSwitch
          spacing: 2
          anchors.verticalCenter: parent.verticalCenter
          Text {
            textFormat: Text.PlainText
            text: pickRoot.checked ? "包含" : "跳过"
            color: pickRoot.checked ? root.accent : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            anchors.horizontalCenter: parent.horizontalCenter
          }
          ToggleSwitch {
            checked: pickRoot.checked
            foreground: root.foreground
            accent: root.accent
            onToggled: root.togglePick(pickRoot.kind, pickRoot.itemId)
          }
        }
      }

      Row {
        visible: pickRoot.both
        spacing: Style.space(6)
        Button {
          text: "保留本机"
          fontSize: Style.font.caption
          foreground: root.foreground
          fontFamily: root.fontFamily
          selected: root.bothPicks[pickRoot.bothKey] === "local"
          bordered: true
          onClicked: root.selectSide(pickRoot.kind, pickRoot.itemId, "local")
        }
        Button {
          text: "采用仓库"
          fontSize: Style.font.caption
          foreground: root.foreground
          fontFamily: root.fontFamily
          selected: root.bothPicks[pickRoot.bothKey] === "repo"
          bordered: true
          onClicked: root.selectSide(pickRoot.kind, pickRoot.itemId, "repo")
        }
      }
    }

    MouseArea {
      z: -1
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: root.togglePick(pickRoot.kind, pickRoot.itemId)
    }
  }

  component FileRow: Rectangle {
    id: fileRowRoot
    property string pathLabel: ""
    property string localPath: ""
    property string repoPath: ""
    property string summary: ""
    property string statusLabel: ""
    property Component extra: Item { width: 0; height: 1 }
    property bool clickable: true
    width: parent ? parent.width : 100
    implicitHeight: Math.max(fileCol.implicitHeight, extraLoader.implicitHeight) + Style.space(12)
    radius: Style.cornerRadius
    color: root.cardBg
    border.width: 1
    border.color: root.cardBorder

    Row {
      anchors.fill: parent
      anchors.leftMargin: Style.space(8)
      anchors.rightMargin: Style.space(8)
      spacing: Style.space(6)

      Column {
        id: fileCol
        width: parent.width - (extraLoader.item ? extraLoader.width + parent.spacing : 0) - (fileRowRoot.clickable ? actionButtons.width + parent.spacing : 0)
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: fileRowRoot.pathLabel
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          font.bold: true
          elide: Text.ElideMiddle
        }
        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: fileRowRoot.summary + (fileRowRoot.statusLabel ? " · " + fileRowRoot.statusLabel : "")
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      Loader {
        id: extraLoader
        anchors.verticalCenter: parent.verticalCenter
        sourceComponent: fileRowRoot.extra
      }

      Row {
        id: actionButtons
        visible: fileRowRoot.clickable
        spacing: Style.space(4)
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
          id: fmBtn
          width: Style.space(30)
          height: Style.space(28)
          radius: Style.cornerRadius > 0 ? Style.space(4) : 0
          color: fmMa.containsMouse ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22) : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
          border.width: 1
          border.color: fmMa.containsMouse ? root.accent : root.cardBorder

          Text {
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: "󰉋"
            color: fmMa.containsMouse ? root.accent : root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          MouseArea {
            id: fmMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openFile(fileRowRoot.pathLabel, fileRowRoot.localPath, fileRowRoot.repoPath)
          }
        }

        Rectangle {
          id: termBtn
          width: Style.space(30)
          height: Style.space(28)
          radius: Style.cornerRadius > 0 ? Style.space(4) : 0
          color: termMa.containsMouse ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22) : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
          border.width: 1
          border.color: termMa.containsMouse ? root.accent : root.cardBorder

          Text {
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: "󰞷"
            color: termMa.containsMouse ? root.accent : root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          MouseArea {
            id: termMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openTerminal(fileRowRoot.pathLabel, fileRowRoot.localPath, fileRowRoot.repoPath)
          }
        }
      }
    }
  }

  component QuickPill: Rectangle {
    property string icon: ""
    property string label: ""
    property string value: ""
    property color highlightColor: root.foreground
    implicitHeight: Style.space(42)
    radius: Style.cornerRadius
    color: root.cardBg
    border.width: 1
    border.color: root.cardBorder
    Column {
      anchors.centerIn: parent
      spacing: 1
      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(4)
        Text {
          textFormat: Text.PlainText
          text: icon
          color: highlightColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
        Text {
          textFormat: Text.PlainText
          text: value
          color: highlightColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }
      Text {
        textFormat: Text.PlainText
        anchors.horizontalCenter: parent.horizontalCenter
        text: label
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption - 2
      }
    }
  }

  component CardBox: Rectangle {
    default property alias content: innerCol.children
    width: parent.width
    implicitHeight: innerCol.implicitHeight + Style.space(16)
    radius: Style.cornerRadius
    color: root.cardBg
    border.width: 1
    border.color: root.cardBorder

    Column {
      id: innerCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Style.space(8)
      spacing: Style.space(6)
    }
  }

  component TablePair: Item {
    property string label: ""
    property string value: ""
    width: parent.width
    implicitHeight: Math.max(pairLabel.implicitHeight, pairVal.implicitHeight)
    Text {
      id: pairLabel
      textFormat: Text.PlainText
      text: label
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      anchors.left: parent.left
      anchors.top: parent.top
      width: Math.min(Style.space(140), parent.width * 0.34)
      wrapMode: Text.WordWrap
    }
    Text {
      id: pairVal
      textFormat: Text.PlainText
      text: value
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      anchors.left: pairLabel.right
      anchors.leftMargin: Style.space(8)
      anchors.right: parent.right
      wrapMode: Text.WordWrap
    }
  }
}
