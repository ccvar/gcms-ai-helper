import AppKit

// 项目根目录 = App 所在目录（App 在项目根里）。这样整体迁移也能定位。
let projDir = (Bundle.main.bundlePath as NSString).deletingLastPathComponent
let appBuild = "版本 1.67 · ccvar"
let defaultAICmd = "claude -p \"$CCVAR_PROMPT\" --permission-mode default --allowedTools \"Bash(python3 ccvar.py:*)\" \"Read\" \"Write\" \"Edit\" \"Bash(ls:*)\" \"Bash(wc:*)\" \"Bash(find:*)\" \"Bash(grep:*)\" --output-format text"
let modelTitles = ["默认（跟随全局）", "Opus 4.8（最强）", "Opus 4.7", "Opus 4.6", "Sonnet 4.6（性价比）", "Haiku 4.5（最快）"]
let modelValues = ["", "claude-opus-4-8", "claude-opus-4-7", "claude-opus-4-6", "claude-sonnet-4-6", "claude-haiku-4-5"]
let modelAliasMap = ["opus": "claude-opus-4-8", "sonnet": "claude-sonnet-4-6", "haiku": "claude-haiku-4-5"]
let editorTitles = ["跟随写作模型", "Opus 4.8（最强）", "Opus 4.7", "Sonnet 4.6", "Haiku 4.5"]
let editorValues = ["", "claude-opus-4-8", "claude-opus-4-7", "claude-sonnet-4-6", "claude-haiku-4-5"]
let modeTitles = ["手动（只撰稿，你来发）", "半自动（审核+建议，你点发布）", "全自动（过审到点自动发）"]
let modeValues = ["manual", "semi", "auto"]
// 低频·按需能力（页面/链接）的发布模式：首项叫「无计划」更贴切（值仍是 manual/semi/auto）
let lfModeTitles = ["无计划（纯手动·不自动发）", "半自动（审后到点自动发）", "全自动（生成即发）"]
let langModeTitles = ["翻译生成（省额度）", "各语种独立撰写（更地道·更费额度）"]
let langModeValues = ["translate", "native"]
let engineTitles = ["Claude", "GPT (codex)"]
let engineValues = ["claude", "codex"]
let codexModelTitles = ["默认（codex 配置）", "gpt-5.5", "gpt-5-codex", "o3"]
let codexModelValues = ["", "gpt-5.5", "gpt-5-codex", "o3"]

// 统一的 SF Symbol（矢量原生图标，非 emoji）
func tsym(_ name: String) -> NSImage? {
    guard let img = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { return nil }
    let cfg = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
    let out = img.withSymbolConfiguration(cfg) ?? img
    out.isTemplate = true
    return out
}
// 大一号的模板图标（用于无边框图标按钮）
func bsym(_ name: String) -> NSImage? {
    guard let img = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { return nil }
    let out = img.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 10, weight: .regular)) ?? img
    out.isTemplate = true
    return out
}

func shq(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }

// 自定义菜单项视图：点击后【不关闭菜单】，并原地显示「处理中…」/「✓ 已撰稿」
final class ActionItemView: NSView {
    private let icon = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private let busy = NSImageView()        // 右侧运行图标：忙碌转圈 / 完成绿勾 / 空闲隐藏
    var onClick: (() -> Void)?
    private var hovering = false
    private var isBusy = false
    private var isDone = false
    private var angle: CGFloat = 0

    init(title: String, symbol: String) {
        super.init(frame: NSRect(x: 0, y: 0, width: 250, height: 22))
        autoresizingMask = [.width]   // 让菜单把本视图拉伸到整行宽，高亮才铺满
        icon.image = tsym(symbol)
        icon.frame = NSRect(x: 16, y: 3, width: 16, height: 16)
        addSubview(icon)
        label.stringValue = title
        label.font = NSFont.menuFont(ofSize: 0)
        label.frame = NSRect(x: 37, y: 2, width: 160, height: 17)
        addSubview(label)
        busy.frame = NSRect(x: 220, y: 3, width: 16, height: 16)
        busy.imageScaling = .scaleProportionallyDown
        busy.isHidden = true
        addSubview(busy)
    }
    required init?(coder: NSCoder) { return nil }

    // 菜单把本视图拉宽时，把右侧运行图标钉到行尾【内侧】，绝不溢出
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        busy.frame = NSRect(x: max(150, newSize.width - 30), y: 3, width: 16, height: 16)
    }

    // 整块都命中自己，保证点击与悬停都落到本视图（子视图不抢事件）
    override func hitTest(_ point: NSPoint) -> NSView? { frame.contains(point) ? self : nil }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard hovering else { return }
        NSColor.selectedContentBackgroundColor.setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 5, dy: 1), xRadius: 5, yRadius: 5).fill()
    }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil))
    }
    override func mouseEntered(with event: NSEvent) { hovering = true; recolor() }
    override func mouseExited(with event: NSEvent)  { hovering = false; recolor() }
    override func mouseUp(with event: NSEvent)      { onClick?() }

    private func recolor() {
        let primary: NSColor = hovering ? .white : .labelColor
        label.textColor = primary
        icon.contentTintColor = primary
        if isBusy { busy.contentTintColor = hovering ? .white : .secondaryLabelColor }
        else if isDone { busy.contentTintColor = hovering ? .white : .systemGreen }
        needsDisplay = true
    }
    func setBusy(_ b: Bool) {
        isBusy = b; isDone = false; angle = 0; busy.frameCenterRotation = 0
        busy.isHidden = !b
        if b { busy.image = tsym("arrow.triangle.2.circlepath") }
        recolor()
    }
    func tick() { guard isBusy else { return }; angle -= 30; busy.frameCenterRotation = angle; busy.needsDisplay = true }
    func setDone() {
        isBusy = false; isDone = true; angle = 0; busy.frameCenterRotation = 0
        busy.isHidden = false; busy.image = tsym("checkmark.circle.fill")
        recolor()
    }
}

// 待审草稿的图例：用真图标 + 短标签（和列表里的图标一致）
final class LegendView: NSView {
    init(_ pairs: [(NSImage?, String)]) {
        super.init(frame: NSRect(x: 0, y: 0, width: 360, height: 20))
        var x: CGFloat = 14   // 与下方标准菜单项图标左缘对齐
        for (img, text) in pairs {
            let iv = NSImageView(frame: NSRect(x: x, y: 3, width: 13, height: 13))
            iv.image = img; iv.imageScaling = .scaleProportionallyDown; addSubview(iv); x += 16
            let l = NSTextField(labelWithString: text); l.font = NSFont.menuFont(ofSize: 11); l.textColor = .secondaryLabelColor
            l.sizeToFit(); l.frame = NSRect(x: x, y: 2, width: l.frame.width, height: 15); addSubview(l); x += l.frame.width + 12
        }
        frame = NSRect(x: 0, y: 0, width: x, height: 20)
    }
    required init?(coder: NSCoder) { return nil }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }   // 纯展示，不拦截
}

enum RunState { case never, running, warn, idle }

// 撰稿状态行：小字、淡色、SF 图标（撰稿中沙漏逐帧动画，非 emoji）；可点开日志但不抢眼
final class StatusRowView: NSView {
    private let icon = NSImageView()
    private let label = NSTextField(labelWithString: "")
    var onClick: (() -> Void)?
    private var hovering = false
    private var clickable = false
    private var running = false
    private var angle: CGFloat = 0

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 20))
        autoresizingMask = [.width]
        icon.frame = NSRect(x: 16, y: 2, width: 16, height: 16)   // 与标准菜单项图标左缘对齐（14偏左/18偏右→取16）
        icon.imageScaling = .scaleProportionallyDown
        addSubview(icon)
        label.font = NSFont.menuFont(ofSize: 12)      // 比正文小一点
        label.textColor = .secondaryLabelColor          // 比正文淡
        label.lineBreakMode = .byTruncatingTail         // 太长就省略号，绝不硬切出菜单
        label.frame = NSRect(x: 37, y: 2, width: 220, height: 16)   // 与上下行文字左对齐
        addSubview(label)
    }
    required init?(coder: NSCoder) { return nil }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        label.frame = NSRect(x: 37, y: 2, width: max(120, newSize.width - 48), height: 16)
    }
    override func hitTest(_ point: NSPoint) -> NSView? { frame.contains(point) ? self : nil }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil))
    }
    override func mouseEntered(with event: NSEvent) { hovering = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent)  { hovering = false; needsDisplay = true }
    override func mouseUp(with event: NSEvent)      { if clickable { onClick?() } }
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard hovering && clickable else { return }
        NSColor.secondaryLabelColor.withAlphaComponent(0.10).setFill()   // 极淡，像“可瞄一眼”，不像按钮
        NSBezierPath(roundedRect: bounds.insetBy(dx: 5, dy: 1), xRadius: 5, yRadius: 5).fill()
    }

    // 平滑旋转：菜单计时器每 0.1s 调一次，仅撰稿中转动
    func spin(by deg: CGFloat) {
        guard running else { return }
        angle -= deg
        icon.frameCenterRotation = angle
        icon.needsDisplay = true; needsDisplay = true
    }
    func update(text: String, state: RunState, frame f: Int) {
        label.stringValue = text
        toolTip = text                     // 截断时悬停看全文
        running = (state == .running)
        if !running { angle = 0; icon.frameCenterRotation = 0 }   // 非撰稿态图标摆正
        switch state {
        case .running:
            icon.image = tsym("arrow.triangle.2.circlepath")     // 环形箭头：旋转=正在进行
            icon.contentTintColor = .secondaryLabelColor; label.textColor = .secondaryLabelColor; clickable = true
        case .warn:
            icon.image = tsym("exclamationmark.triangle.fill")
            icon.contentTintColor = .systemOrange; label.textColor = .systemOrange; clickable = true
        case .idle:
            icon.image = tsym("checkmark.circle")
            icon.contentTintColor = .secondaryLabelColor; label.textColor = .secondaryLabelColor; clickable = true
        case .never:
            icon.image = tsym("clock")
            icon.contentTintColor = .tertiaryLabelColor; label.textColor = .tertiaryLabelColor; clickable = false
        }
        needsDisplay = true
    }
}

// 无边框图标按钮：鼠标移上去显示淡灰圆角底（hover 反馈）
final class HoverIconButton: NSButton {
    private var hovering = false
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil))
    }
    override func mouseEntered(with e: NSEvent) { hovering = true; needsDisplay = true }
    override func mouseExited(with e: NSEvent)  { hovering = false; needsDisplay = true }
    override func draw(_ dirtyRect: NSRect) {
        if hovering {
            NSColor.secondaryLabelColor.withAlphaComponent(0.18).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 1), xRadius: 5, yRadius: 5).fill()
        }
        super.draw(dirtyRect)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    var logWindow: NSWindow?
    var logTextView: NSTextView?
    var logTimer: Timer?
    var previewHUD: NSPanel?
    var statusItem: NSStatusItem!
    var settingsWindow: NSWindow?
    var globalSettingsWindow: NSWindow?
    var siteSettingsWindow: NSWindow?
    var timePicker: NSDatePicker!
    var keyField: NSSecureTextField!
    var cliField: NSTextField!
    var modelPopup: NSPopUpButton!
    var tokenField: NSSecureTextField!
    var editorPopup: NSPopUpButton!
    var modePopup: NSPopUpButton!
    var vetoField: NSTextField!
    var catCheck: NSButton!
    var coverCheck: NSButton!
    var codeCheck: NSButton!
    var postWordsField: NSTextField!
    var pagesWordsField: NSTextField!
    var linksWordsField: NSTextField!
    var writeLangPopup: NSPopUpButton!
    var langModePopup: NSPopUpButton!
    var writerEnginePopup: NSPopUpButton!
    var editorEnginePopup: NSPopUpButton!
    var openaiField: NSSecureTextField!
    var gptStatusLabel: NSTextField!
    var claudeStatusLabel: NSTextField!
    var claudeDot: NSImageView!
    var gptDot: NSImageView!
    var claudeBtn: NSButton!
    var gptBtn: NSButton!
    var langChecks: [(code: String, btn: NSButton)] = []
    var langCodes: [String] = []
    var transHint: NSTextField!
    var pagesTextView: NSTextView!
    var pagesModePopup: NSPopUpButton!
    var linksTextView: NSTextView!
    var linksModePopup: NSPopUpButton!
    var linksCatCheck: NSButton!
    var linksCoverCheck: NSButton!
    var isDrafting = false
    var actSlug = ""; var actName = ""
    var sitesWindow: NSWindow?
    var siteNameField: NSTextField!; var siteSlugField: NSTextField!
    var siteBaseField: NSTextField!; var siteKeyField: NSSecureTextField!
    weak var draftItemView: ActionItemView?
    weak var statusRowView: StatusRowView?
    var menuTimer: Timer?
    var animFrame = 0
    var iconColored: NSImage?
    var iconGray: NSImage?
    var iconAnimTimer: Timer?
    var iconPhase: Double = 0
    var iconBaseOn = true                // 缓存的开/暂停态，避免高频调用 launchctl

    func applicationDidFinishLaunching(_ note: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        iconColored = loadIcon("favicon")        // 运行中：品牌红
        iconGray    = loadIcon("favicon-gray")   // 已暂停：灰
        refreshIcon()
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        // 每 20 秒同步一次开/暂停态（即使在外部用命令行改了也能跟上）
        Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in self?.refreshIcon() }
        // 撰稿中让菜单栏图标“呼吸”——独立计时器，菜单开/关都要动，故用 .common
        let at = Timer(timeInterval: 0.12, repeats: true) { [weak self] _ in self?.tickIcon() }
        RunLoop.main.add(at, forMode: .common)
        iconAnimTimer = at
    }

    // 是否“撰稿中”：菜单内触发(isDrafting) 或 当前站状态文件 RUNNING 且 30 分钟内（进程内读，廉价）
    func isBusyNow() -> Bool {
        if isDrafting { return true }
        let c = readStatusRaw().components(separatedBy: "\t")
        if c.count >= 3, c[0] == "RUNNING", let ts = Double(c[1]) {
            return Date().timeIntervalSince1970 - ts < 1800
        }
        return false
    }

    // 0.12s 一帧：撰稿中让【原图标】呼吸闪烁（只改透明度，绝不换图标）；空闲恢复不透明
    func tickIcon() {
        guard let btn = statusItem.button else { return }
        if isBusyNow() {
            iconPhase += 0.22
            btn.alphaValue = 0.35 + 0.65 * (0.5 + 0.5 * sin(iconPhase))   // 0.35–1.0 呼吸
        } else if btn.alphaValue != 1.0 {
            btn.alphaValue = 1.0
        }
    }

    // 菜单栏图标随开/暂停切换（始终是原品牌图标）；撰稿中的呼吸由 tickIcon 调透明度
    func refreshIcon() {
        iconBaseOn = isEnabled()
        statusItem.button?.image = (iconBaseOn ? iconColored : iconGray) ?? tsym("square.and.pencil")
        if !isBusyNow() { statusItem.button?.alphaValue = 1.0 }
    }

    func loadIcon(_ name: String) -> NSImage? {
        let paths = [Bundle.main.path(forResource: name, ofType: "svg"),
                     projDir + "/assets/\(name).svg"].compactMap { $0 }
        for p in paths {
            if let img = NSImage(contentsOfFile: p) {
                img.size = NSSize(width: 18, height: 18)
                img.isTemplate = false
                return img
            }
        }
        return nil
    }
    // 品牌 logo：从 assets/<name>.{svg,png,pdf} 读（svg 优先，小尺寸更清晰）；缺文件返回 nil（不显示、不报错）
    func brandLogo(_ name: String, _ side: CGFloat = 14) -> NSImage? {
        for ext in ["svg", "png", "pdf"] {
            let p = projDir + "/assets/\(name).\(ext)"
            if FileManager.default.fileExists(atPath: p), let img = NSImage(contentsOfFile: p) {
                img.size = NSSize(width: side, height: side); img.isTemplate = false; return img
            }
        }
        return nil
    }

    @discardableResult
    func sh(_ cmd: String) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = ["-c", cmd]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        do { try p.run() } catch { return "" }
        p.waitUntilExit()
        let d = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: d, encoding: .utf8) ?? ""
    }

    // 异步、不阻塞主线程：用于长任务或可能弹窗/卡住的命令（绝不冻结界面）
    func fire(_ cmd: String) {
        DispatchQueue.global(qos: .utility).async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/bash")
            p.arguments = ["-c", cmd]
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
            p.standardInput = FileHandle.nullDevice
            try? p.run()
            p.waitUntilExit()
        }
    }

    func isEnabled() -> Bool {
        sh("/bin/launchctl list 2>/dev/null | /usr/bin/grep -q com.ccvar.dailydraft && echo yes").contains("yes")
    }

    func notify(_ msg: String) {
        let safe = msg.replacingOccurrences(of: "\"", with: "'")
        fire("/usr/bin/osascript -e 'display notification \"\(safe)\" with title \"CCVAR 撰稿助手\"'")
    }

    // MARK: - 多站点
    func loadActive() {
        let p = sh("cd \(shq(projDir)) && /bin/bash automation/site-info.sh active")
                  .trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\t")
        if p.count >= 2 { actSlug = p[0]; actName = p[1] }
    }
    func sitesList() -> [(slug: String, name: String, active: Bool)] {
        let out = sh("cd \(shq(projDir)) && /bin/bash automation/site-info.sh list")
        return out.split(separator: "\n").compactMap {
            let c = $0.components(separatedBy: "\t"); return c.count >= 3 ? (c[0], c[1], c[2] == "1") : nil
        }
    }
    // 当前活动站的文件路径（所有站统一 sites/<slug>/，无根站特例）
    func aPath(_ kind: String) -> String {
        let base = "\(projDir)/sites/\(actSlug)"
        switch kind {
        case "queue": return "\(base)/review-queue.md"
        case "topics": return "\(base)/topics.md"
        case "recent": return "\(base)/.recent-published.tsv"
        case "publishing": return "\(base)/.publishing"
        case "pending": return "\(base)/pending-publish.tsv"
        case "config": return "\(base)/config.json"
        case "keyfile": return "\(base)/site.env"
        case "status": return "\(base)/.runstatus"
        case "pages": return "\(base)/pages.md"
        case "pagesqueue": return "\(base)/pages-review-queue.md"
        case "links": return "\(base)/links.md"
        case "linksqueue": return "\(base)/links-review-queue.md"
        default: return base
        }
    }
    @objc func switchSite(_ sender: NSMenuItem) {
        guard let slug = sender.representedObject as? String else { return }
        _ = sh("/bin/bash \(shq(projDir + "/automation/set-active.sh")) \(shq(slug))")   // 同步写，确保重弹时已生效
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.statusItem.button?.performClick(nil)   // 重新弹出菜单 → 视觉上"切换不消失"，并刷新成新站内容
        }
    }

    // 撰稿运行状态（读状态文件；健康可见，不靠通知）。直接读文件，便于菜单打开时高频刷新。
    func readStatusRaw() -> String {
        (try? String(contentsOfFile: aPath("status"), encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    func statusInfo() -> (text: String, state: RunState) {
        let c = readStatusRaw().components(separatedBy: "\t")
        guard c.count >= 3, let ts = Double(c[1]) else {
            return ("还没跑过 · 可点上面「立刻撰稿一篇」", .never)
        }
        let msg = clip(c[2], 22)
        if c[0] == "RUNNING" {
            let mins = Int(max(0, Date().timeIntervalSince1970 - ts) / 60)
            if mins > 30 { return ("已 \(mins) 分钟，可能卡住 · 点看日志", .warn) }
            return ("撰稿中 · 已 \(mins) 分钟 · \(msg)", .running)
        }
        let df = DateFormatter(); df.dateFormat = "HH:mm"
        return ("上次 \(df.string(from: Date(timeIntervalSince1970: ts))) · \(msg)", .idle)
    }
    func sectionHeader(_ menu: NSMenu, _ text: String) {
        let it = NSMenuItem(title: text, action: nil, keyEquivalent: ""); it.isEnabled = false
        it.attributedTitle = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold), .foregroundColor: NSColor.tertiaryLabelColor])
        menu.addItem(it)
    }

    func sitesFull() -> [(slug: String, name: String, base: String, active: Bool)] {
        let out = sh("cd \(shq(projDir)) && /bin/bash automation/site-info.sh full")
        return out.split(separator: "\n").compactMap {
            let c = $0.components(separatedBy: "\t")
            return c.count >= 4 ? (c[0], c[1], c[2], c[3] == "1") : nil
        }
    }

    @objc func manageSites() {
        if sitesWindow == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 580, height: 460),
                             styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.title = "站点管理"; w.isReleasedWhenClosed = false
            sitesWindow = w
        }
        populateSites()
        presentWindow(sitesWindow)
    }

    func populateSites() {
        guard let w = sitesWindow else { return }
        let sites = sitesFull()
        let W: CGFloat = 580, rowH: CGFloat = 34
        let H: CGFloat = CGFloat(max(sites.count, 1)) * rowH + 410
        w.setContentSize(NSSize(width: W, height: H))
        let v = NSView(frame: NSRect(x: 0, y: 0, width: W, height: H))
        func lab(_ s: String, _ x: CGFloat, _ y: CGFloat, _ wd: CGFloat, _ sz: CGFloat = 13, _ bold: Bool = false) {
            let l = NSTextField(labelWithString: s); l.frame = NSRect(x: x, y: y, width: wd, height: 18)
            l.font = bold ? .systemFont(ofSize: sz, weight: .semibold) : .systemFont(ofSize: sz)
            if sz <= 11 { l.textColor = .secondaryLabelColor }
            v.addSubview(l)
        }
        lab("站点管理", 22, H - 40, 300, 16, true)
        lab("撰稿/审核引擎与登录全站共享；每站各自的密钥、选题、发布策略。", 22, H - 60, 540, 11)
        var y = H - 98
        if sites.isEmpty {
            let l = NSTextField(labelWithString: "还没有任何站点 —— 在下面填表添加一个就能开始 ↓")
            l.frame = NSRect(x: 26, y: y, width: 520, height: 20)
            l.font = .systemFont(ofSize: 13, weight: .semibold); l.textColor = .systemOrange
            v.addSubview(l)
            y -= rowH
        }
        for s in sites {
            lab(s.active ? "● \(s.name)" : "  \(s.name)", 26, y, 170, 13, true)
            lab(s.base, 200, y, 190, 11)
            do {   // 各站平级，可全部删空（删到零站点会显示空状态引导）
                let ck = NSButton(title: "改密钥", target: self, action: #selector(changeKeyTapped(_:)))
                ck.frame = NSRect(x: 398, y: y - 4, width: 80, height: 26); ck.bezelStyle = .rounded
                ck.identifier = NSUserInterfaceItemIdentifier(s.slug); v.addSubview(ck)
                let rm = NSButton(title: "移除", target: self, action: #selector(removeSiteTapped(_:)))
                rm.frame = NSRect(x: 484, y: y - 4, width: 66, height: 26); rm.bezelStyle = .rounded
                rm.identifier = NSUserInterfaceItemIdentifier(s.slug); v.addSubview(rm)
            }
            y -= rowH
        }
        let sep = NSBox(frame: NSRect(x: 20, y: y + 4, width: W - 40, height: 1)); sep.boxType = .separator; v.addSubview(sep)
        y -= 24
        lab("添加新站点（同样是 GCMS/CCVAR 接口的站）", 22, y, 460, 13, true); y -= 34
        lab("名称", 22, y, 64); siteNameField = NSTextField(frame: NSRect(x: 96, y: y - 3, width: 300, height: 24)); siteNameField.placeholderString = "例如：我的博客"; v.addSubview(siteNameField); y -= 34
        lab("标识 slug", 22, y, 70); siteSlugField = NSTextField(frame: NSRect(x: 96, y: y - 3, width: 200, height: 24)); siteSlugField.placeholderString = "英文小写，留空自动生成"; v.addSubview(siteSlugField); y -= 34
        lab("API 域名", 22, y, 70); siteBaseField = NSTextField(frame: NSRect(x: 96, y: y - 3, width: 420, height: 24)); siteBaseField.placeholderString = "https://你的站.com/api/admin/v1"; v.addSubview(siteBaseField); y -= 34
        lab("API 密钥", 22, y, 70); siteKeyField = NSSecureTextField(frame: NSRect(x: 96, y: y - 3, width: 300, height: 24)); siteKeyField.placeholderString = "gcms_…（含 publish 权限才能发布）"; v.addSubview(siteKeyField); y -= 44
        let add = NSButton(title: "添加站点", target: self, action: #selector(addSiteTapped)); add.frame = NSRect(x: 96, y: y, width: 120, height: 30); add.bezelStyle = .rounded; add.keyEquivalent = "\r"; v.addSubview(add)
        let close = NSButton(title: "关闭", target: self, action: #selector(closeSites)); close.frame = NSRect(x: W - 110, y: 18, width: 90, height: 30); close.bezelStyle = .rounded; v.addSubview(close)
        w.contentView = v
    }

    @objc func addSiteTapped() {
        let name = siteNameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        var slug = siteSlugField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = siteBaseField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = siteKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !base.isEmpty else { alert("缺少信息", "请至少填「名称」和「API 域名」。"); return }
        if slug.isEmpty { slug = "site\(sitesFull().count + 1)" }
        notify("正在添加站点…")
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let out = self.sh("/bin/bash \(shq(projDir + "/automation/add-site.sh")) \(shq(slug)) \(shq(name)) \(shq(base)) \(shq(key))")
            DispatchQueue.main.async {
                if out.contains("ADDED") {
                    self.siteNameField.stringValue = ""; self.siteSlugField.stringValue = ""
                    self.siteBaseField.stringValue = ""; self.siteKeyField.stringValue = ""
                    self.populateSites(); self.notify("已添加站点：\(name)（菜单顶部可切换）")
                    self.offerCalibrate(slug, name)
                } else { self.alert("添加失败", out.isEmpty ? "未知错误" : out) }
            }
        }
    }
    // 加站后问一下要不要立刻校准【新站】的网站定位（针对该 slug，不影响当前活动站）
    func offerCalibrate(_ slug: String, _ name: String) {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = "设置「\(name)」的网站定位"
        a.informativeText = "网站定位决定 AI 以后写什么、什么调性。两种填法：\n\n· 站上【已有发布文章】→ 选「AI 校准」，自动读文章填好（约一两分钟，需引擎已登录）。\n· 【全新空站】没文章可读 → 选「手动填写」，照模板里的示例填网站定位和写作方向。\n\n只改本地选题库，不发布任何东西；以后也能在菜单改。"
        a.addButton(withTitle: "AI 校准"); a.addButton(withTitle: "手动填写"); a.addButton(withTitle: "以后再说")
        let r = a.runModal()
        if r == .alertFirstButtonReturn {
            notify("正在校准「\(name)」…（约一两分钟）")
            DispatchQueue.global(qos: .utility).async { [weak self] in
                guard let self = self else { return }
                _ = self.sh("CCVAR_SITE=\(shq(slug)) /bin/bash \(shq(projDir + "/automation/calibrate.sh"))")
                DispatchQueue.main.async { self.notify("「\(name)」校准完成 —— 点「编辑选题…」查看") }
            }
        } else if r == .alertSecondButtonReturn {
            fire("/usr/bin/open -t \(shq(projDir + "/sites/\(slug)/topics.md"))")   // 打开新站选题库，模板内有示例指引
        }
    }

    @objc func removeSiteTapped(_ sender: NSButton) {
        guard let slug = sender.identifier?.rawValue else { return }
        let a = NSAlert(); a.messageText = "移除这个站点？"
        a.informativeText = "只从站点列表移除「\(slug)」；它的数据文件会原样保留、不会删除（如需彻底删除请手动删对应目录）。"
        a.addButton(withTitle: "移除"); a.addButton(withTitle: "取消")
        guard a.runModal() == .alertFirstButtonReturn else { return }
        _ = sh("/bin/bash \(shq(projDir + "/automation/remove-site.sh")) \(shq(slug))")
        populateSites()
    }

    @objc func changeKeyTapped(_ sender: NSButton) {
        guard let slug = sender.identifier?.rawValue else { return }
        let a = NSAlert(); a.messageText = "修改「\(slug)」的 API 密钥"
        a.informativeText = "粘贴这个站的新密钥（gcms_…，需含 publish 权限才能发布）。"
        let tf = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24)); tf.placeholderString = "gcms_…"
        a.accessoryView = tf
        a.addButton(withTitle: "保存"); a.addButton(withTitle: "取消")
        guard a.runModal() == .alertFirstButtonReturn else { return }
        let key = tf.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        _ = sh("CCVAR_SITE=\(shq(slug)) /bin/bash \(shq(projDir + "/automation/set-key.sh")) \(shq(key))")
        notify("已更新「\(slug)」的密钥")
    }

    @objc func closeSites() { sitesWindow?.orderOut(nil) }

    func pendingDrafts() -> [(id: String, title: String, badge: String, detail: String)] {
        let out = sh("/usr/bin/grep -F -- '- [ ]' \(shq(aPath("queue"))) 2>/dev/null")
        return out.split(separator: "\n").compactMap { line in
            let s = String(line)
            let parts = s.components(separatedBy: " · ")
            guard parts.count >= 3 else { return nil }
            let id = parts[1].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
            let title = parts[2].trimmingCharacters(in: .whitespaces)
            var badge = ""
            let score = firstMatch(s, "·([0-9]+) —") ?? ""
            if s.contains("✓建议发布") { badge = "✓" + score }
            else if s.contains("⚠需你看") { badge = "⚠" }
            else if s.contains("✗不建议") { badge = "✗" }
            let detail = firstMatch(s, "〔(.+)〕") ?? ""
            return (id, title, badge, detail)
        }
    }
    func pendingPages() -> [(id: String, title: String)] {
        let out = sh("/usr/bin/grep -F -- '- [ ]' \(shq(aPath("pagesqueue"))) 2>/dev/null")
        return out.split(separator: "\n").compactMap { line in
            let parts = String(line).components(separatedBy: " · ")
            guard parts.count >= 3 else { return nil }
            let id = parts[1].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
            return (id, parts[2].trimmingCharacters(in: .whitespaces))
        }
    }
    func pendingLinks() -> [(id: String, title: String)] {
        let out = sh("/usr/bin/grep -F -- '- [ ]' \(shq(aPath("linksqueue"))) 2>/dev/null")
        return out.split(separator: "\n").compactMap { line in
            let parts = String(line).components(separatedBy: " · ")
            guard parts.count >= 3 else { return nil }
            let id = parts[1].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
            return (id, parts[2].trimmingCharacters(in: .whitespaces))
        }
    }

    func firstMatch(_ s: String, _ pattern: String) -> String? {
        guard let r = try? NSRegularExpression(pattern: pattern),
              let m = r.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              m.numberOfRanges > 1, let rg = Range(m.range(at: 1), in: s) else { return nil }
        return String(s[rg])
    }

    // 截断长标题（超出加省略号；完整标题放 toolTip 悬停可见）
    func clip(_ s: String, _ n: Int) -> String { s.count <= n ? s : String(s.prefix(n)) + "…" }
    // 彩色 SF 图标（非 emoji）
    func csym(_ name: String, _ color: NSColor) -> NSImage? {
        guard let img = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { return nil }
        let out = img.withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [color]))
        out?.isTemplate = false
        return out
    }
    // 正在发布中的草稿 id（菜单据此显示「正在发布上线…」）
    func publishingIds() -> Set<String> {
        let out = sh("/bin/cat \(shq(aPath("publishing"))) 2>/dev/null")
        return Set(out.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
    }

    // 全自动「待发布队列」：每行 <id>\t<可发布epoch>
    func pendingPublish() -> [(id: String, when: String)] {
        let out = sh("/bin/cat \(shq(aPath("pending"))) 2>/dev/null")
        let df = DateFormatter(); df.dateFormat = "M/d HH:mm"
        return out.split(separator: "\n").compactMap { line in
            let cols = line.components(separatedBy: "\t")
            guard cols.count >= 2, let at = Double(cols[1].trimmingCharacters(in: .whitespaces)) else { return nil }
            let id = cols[0].trimmingCharacters(in: .whitespaces)
            return (id, df.string(from: Date(timeIntervalSince1970: at)))
        }
    }

    // 菜单打开期间用 .common 模式定时刷新：实时更新状态行文字 + 沙漏动画 + 「处理中…」省略号
    func menuWillOpen(_ menu: NSMenu) {
        animFrame = 0
        // 双保险：显式把自定义行拉伸到菜单宽度（整行高亮 + 「处理中…」右对齐都依赖整行宽）
        let w = menu.size.width
        if w > 50 {
            if let dv = draftItemView { dv.setFrameSize(NSSize(width: w, height: dv.frame.height)) }
            if let sv = statusRowView { sv.setFrameSize(NSSize(width: w, height: sv.frame.height)) }
        }
        menuTimer?.invalidate()
        let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in self?.tickMenu() }
        RunLoop.current.add(t, forMode: .common)   // 关键：default 模式在菜单事件跟踪期间不触发
        menuTimer = t
    }
    func menuDidClose(_ menu: NSMenu) { menuTimer?.invalidate(); menuTimer = nil }
    func tickMenu() {
        animFrame &+= 1
        statusRowView?.spin(by: 30)                  // 每 0.1s 转 30°（≈1.2s 一圈），平滑
        if isDrafting { draftItemView?.tick() }       // 撰稿中运行图标也每 0.1s 平滑转
        if animFrame % 6 == 0 {                       // 约每 0.6s 刷新状态行文字/分钟数
            if let sv = statusRowView { let i = statusInfo(); sv.update(text: i.text, state: i.state, frame: animFrame) }
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let on = isEnabled()
        iconBaseOn = on
        statusItem.button?.image = (on ? iconColored : iconGray) ?? statusItem.button?.image

        let header = NSMenuItem(title: on ? "每日自动撰稿：运行中" : "每日自动撰稿：已暂停",
                                action: nil, keyEquivalent: "")
        header.isEnabled = false
        if let dot = NSImage(systemSymbolName: on ? "circle.fill" : "pause.circle.fill", accessibilityDescription: nil) {
            let cfg = NSImage.SymbolConfiguration(paletteColors: [on ? .systemGreen : .systemGray])
            let colored = dot.withSymbolConfiguration(cfg)
            colored?.isTemplate = false
            header.image = colored
        }
        menu.addItem(header)
        menu.addItem(.separator())

        // 站点切换器（多站时显示子菜单可切换；单站时只展示当前站名）
        loadActive()
        let sites = sitesList()
        if sites.isEmpty {
            // 零站点（正常 UI 到不了，仅手动改/损坏 sites.json 才会出现）：
            // 给清晰的空状态 + 恢复入口，不展示空壳的站内功能，避免“看着有站其实点了没反应”
            let empty = NSMenuItem(title: "还没有任何站点", action: nil, keyEquivalent: "")
            empty.isEnabled = false; empty.image = csym("exclamationmark.triangle.fill", .systemOrange)
            menu.addItem(empty)
            addItem(menu, "添加站点…（先建一个才能开始）", "plus.circle", #selector(manageSites))
        } else {
        let siteItem = NSMenuItem(title: "站点：\(actName)", action: nil, keyEquivalent: "")
        siteItem.image = tsym("globe")
        if sites.count > 1 {
            let ssub = NSMenu()
            for s in sites {
                let it = NSMenuItem(title: s.name, action: #selector(switchSite(_:)), keyEquivalent: "")
                it.target = self; it.representedObject = s.slug; it.state = s.active ? .on : .off
                ssub.addItem(it)
            }
            siteItem.submenu = ssub
        } else { siteItem.isEnabled = false }
        menu.addItem(siteItem)
        let stItem = NSMenuItem()
        let sv = StatusRowView()
        sv.onClick = { [weak self] in self?.showLogs() }
        let info = statusInfo(); sv.update(text: info.text, state: info.state, frame: 0)
        stItem.view = sv
        statusRowView = sv
        menu.addItem(stItem)
        menu.addItem(.separator())
        sectionHeader(menu, "　当前站点 · \(actName)")

        let draftItem = NSMenuItem()
        let dv = ActionItemView(title: "立刻撰稿一篇", symbol: "square.and.pencil")
        dv.onClick = { [weak self] in self?.draftNowTapped() }
        dv.setBusy(isDrafting)
        draftItem.view = dv
        draftItemView = dv
        menu.addItem(draftItem)

        let pending = pendingDrafts()
        let publishing = publishingIds()
        let review = NSMenuItem(title: "待审草稿（\(pending.count)）", action: nil, keyEquivalent: "")
        review.image = tsym("tray.full")
        let sub = NSMenu()
        if pending.isEmpty {
            let e = NSMenuItem(title: "暂无", action: nil, keyEquivalent: "")
            e.isEnabled = false
            sub.addItem(e)
        } else {
            let tip = NSMenuItem(title: "点开每篇 → 预览 或 发布", action: nil, keyEquivalent: "")
            tip.isEnabled = false
            sub.addItem(tip)
            let legend = NSMenuItem(); legend.isEnabled = false
            legend.view = LegendView([
                (csym("checkmark.seal.fill", .systemGreen), "荐发"),
                (csym("exclamationmark.triangle.fill", .systemOrange), "需看"),
                (csym("xmark.octagon.fill", .systemRed), "不建议"),
                (csym("doc.text", .secondaryLabelColor), "未审"),
            ])
            sub.addItem(legend)
            for d in pending.suffix(12) {           // 最多列最近 12 篇，避免上千条卡菜单
                if publishing.contains(d.id) {
                    let busy = NSMenuItem(title: "正在发布上线…  #\(d.id)  \(clip(d.title, 28))", action: nil, keyEquivalent: "")
                    busy.image = csym("arrow.triangle.2.circlepath", .systemGray)
                    busy.isEnabled = false; busy.toolTip = d.title; sub.addItem(busy); continue
                }
                var sym = "doc.text"; var col = NSColor.secondaryLabelColor; var scoreTag = ""
                if d.badge.hasPrefix("✓") { sym = "checkmark.seal.fill"; col = .systemGreen; scoreTag = String(d.badge.dropFirst()) }
                else if d.badge.hasPrefix("⚠") { sym = "exclamationmark.triangle.fill"; col = .systemOrange }
                else if d.badge.hasPrefix("✗") { sym = "xmark.octagon.fill"; col = .systemRed }
                let suffix = scoreTag.isEmpty ? "" : "  ·\(scoreTag)分"
                let it = NSMenuItem(title: "#\(d.id)  \(clip(d.title, 30))\(suffix)", action: nil, keyEquivalent: "")
                it.image = csym(sym, col)
                it.toolTip = d.detail.isEmpty ? d.title : "\(d.title)\n\(d.detail)"
                let dsub = NSMenu()
                let pv = NSMenuItem(title: "预览（浏览器看渲染效果，不发布）", action: #selector(previewDraft(_:)), keyEquivalent: "")
                pv.target = self; pv.representedObject = d.id; pv.image = tsym("eye"); dsub.addItem(pv)
                let pb = NSMenuItem(title: "确认发布上线", action: #selector(publishDraft(_:)), keyEquivalent: "")
                pb.target = self; pb.representedObject = [d.id, d.title]; pb.image = tsym("paperplane"); dsub.addItem(pb)
                it.submenu = dsub
                sub.addItem(it)
            }
            if pending.count > 12 {
                let more = NSMenuItem(title: "…共 \(pending.count) 篇，打开完整清单", action: #selector(openReviewQueue), keyEquivalent: "")
                more.target = self; more.image = tsym("ellipsis.circle"); sub.addItem(more)
            }
            sub.addItem(.separator())
            addItem(sub, "在浏览器打开站点", "safari", #selector(openSite))
        }
        review.submenu = sub
        menu.addItem(review)

        // 待审页面（起草好的页面）：预览/发布走 pages 类型；没有时不显示
        let pendPages = pendingPages()
        if !pendPages.isEmpty {
            let pr = NSMenuItem(title: "待审页面（\(pendPages.count)）", action: nil, keyEquivalent: "")
            pr.image = tsym("doc.richtext")
            let psub = NSMenu()
            let ptip = NSMenuItem(title: "点开每个 → 预览 或 发布", action: nil, keyEquivalent: ""); ptip.isEnabled = false; psub.addItem(ptip)
            for pg in pendPages.suffix(20) {
                if publishing.contains(pg.id) {
                    let busy = NSMenuItem(title: "正在发布上线…  #\(pg.id)  \(clip(pg.title, 28))", action: nil, keyEquivalent: "")
                    busy.image = csym("arrow.triangle.2.circlepath", .systemGray); busy.isEnabled = false; psub.addItem(busy); continue
                }
                let it = NSMenuItem(title: "#\(pg.id)  \(clip(pg.title, 30))", action: nil, keyEquivalent: "")
                it.image = csym("doc.richtext", .secondaryLabelColor); it.toolTip = pg.title
                let dsub = NSMenu()
                let pv = NSMenuItem(title: "预览（浏览器看渲染，不发布）", action: #selector(previewDraft(_:)), keyEquivalent: "")
                pv.target = self; pv.representedObject = [pg.id, "pages"]; pv.image = tsym("eye"); dsub.addItem(pv)
                let pb = NSMenuItem(title: "确认发布上线", action: #selector(publishDraft(_:)), keyEquivalent: "")
                pb.target = self; pb.representedObject = [pg.id, pg.title, "pages"]; pb.image = tsym("paperplane"); dsub.addItem(pb)
                it.submenu = dsub; psub.addItem(it)
            }
            pr.submenu = psub; menu.addItem(pr)
        }

        // 待审链接（收录好的链接）：预览/发布走 links 类型；没有时不显示
        let pendLinks = pendingLinks()
        if !pendLinks.isEmpty {
            let lr = NSMenuItem(title: "待审链接（\(pendLinks.count)）", action: nil, keyEquivalent: "")
            lr.image = tsym("link")
            let lsub = NSMenu()
            let ltip = NSMenuItem(title: "点开每个 → 预览 或 发布", action: nil, keyEquivalent: ""); ltip.isEnabled = false; lsub.addItem(ltip)
            for lk in pendLinks.suffix(20) {
                if publishing.contains(lk.id) {
                    let busy = NSMenuItem(title: "正在发布上线…  #\(lk.id)  \(clip(lk.title, 28))", action: nil, keyEquivalent: "")
                    busy.image = csym("arrow.triangle.2.circlepath", .systemGray); busy.isEnabled = false; lsub.addItem(busy); continue
                }
                let it = NSMenuItem(title: "#\(lk.id)  \(clip(lk.title, 30))", action: nil, keyEquivalent: "")
                it.image = csym("link", .secondaryLabelColor); it.toolTip = lk.title
                let dsub = NSMenu()
                let pv = NSMenuItem(title: "预览（浏览器看渲染，不发布）", action: #selector(previewDraft(_:)), keyEquivalent: "")
                pv.target = self; pv.representedObject = [lk.id, "links"]; pv.image = tsym("eye"); dsub.addItem(pv)
                let pb = NSMenuItem(title: "确认发布上线", action: #selector(publishDraft(_:)), keyEquivalent: "")
                pb.target = self; pb.representedObject = [lk.id, lk.title, "links"]; pb.image = tsym("paperplane"); dsub.addItem(pb)
                it.submenu = dsub; lsub.addItem(it)
            }
            lr.submenu = lsub; menu.addItem(lr)
        }

        let queued = pendingPublish()
        if !queued.isEmpty {
            let pubItem = NSMenuItem(title: "待发布·自动（\(queued.count)）", action: nil, keyEquivalent: "")
            pubItem.image = tsym("paperplane.circle")
            let psub = NSMenu()
            let ptip = NSMenuItem(title: "过审待发，到点自动发；点一条即取消（否决）", action: nil, keyEquivalent: "")
            ptip.isEnabled = false
            psub.addItem(ptip)
            for q in queued {
                let it = NSMenuItem(title: "取消 #\(q.id)  · 预计 \(q.when) 发", action: #selector(cancelAutoPublish(_:)), keyEquivalent: "")
                it.target = self
                it.representedObject = q.id
                it.image = tsym("xmark.circle")
                psub.addItem(it)
            }
            pubItem.submenu = psub
            menu.addItem(pubItem)
        }

        let pubd = recentPublished()
        let recent = NSMenuItem(title: "最近发布（\(pubd.count)）", action: nil, keyEquivalent: "")
        recent.image = tsym("checkmark.circle")
        let rsub = NSMenu()
        if pubd.isEmpty {
            let e = NSMenuItem(title: "暂无（或稍后自动刷新）", action: nil, keyEquivalent: ""); e.isEnabled = false; rsub.addItem(e)
        } else {
            let rtip = NSMenuItem(title: "已上线的文章 · 点开在站点查看", action: nil, keyEquivalent: ""); rtip.isEnabled = false; rsub.addItem(rtip)
            for r in pubd {
                let it = NSMenuItem(title: "#\(r.id)  \(clip(r.title, 34))", action: #selector(openPost(_:)), keyEquivalent: "")
                it.target = self; it.representedObject = r.url; it.image = tsym("doc.text"); it.toolTip = r.title
                rsub.addItem(it)
            }
            rsub.addItem(.separator())
            addItem(rsub, "在浏览器打开站点", "safari", #selector(openSite))
        }
        recent.submenu = rsub
        menu.addItem(recent)
        fire("/bin/bash \(shq(projDir + "/automation/refresh-published.sh"))")   // 异步刷新缓存，供下次打开

        addItem(menu, "编辑选题…", "list.bullet", #selector(editTopics))
        addItem(menu, "校准网站定位…", "scope", #selector(calibrateSite))
        addItem(menu, "本站设置…", "slider.horizontal.3", #selector(openSiteSettings))
        }   // end else（有站点才显示上面整段站内功能）

        menu.addItem(.separator())
        sectionHeader(menu, "　全局（所有站点共享）")
        if on {
            addItem(menu, "暂停每日自动撰稿", "pause.circle", #selector(togglePause))
        } else {
            addItem(menu, "恢复每日自动撰稿", "play.circle", #selector(togglePause))
        }
        addItem(menu, "全局设置…", "gearshape", #selector(openGlobalSettings))
        do {   // 站点管理：有站点时在后面补个淡色小字的数量
            let sm = NSMenuItem(title: "站点管理…", action: #selector(manageSites), keyEquivalent: "")
            sm.target = self; sm.image = tsym("rectangle.stack")
            if !sites.isEmpty {
                let att = NSMutableAttributedString(string: "站点管理…", attributes: [.font: NSFont.menuFont(ofSize: 0)])
                att.append(NSAttributedString(string: "   \(sites.count) 个站", attributes: [.font: NSFont.menuFont(ofSize: 11), .foregroundColor: NSColor.tertiaryLabelColor]))
                sm.attributedTitle = att
            }
            menu.addItem(sm)
        }
        addItem(menu, "最近运行日志…", "doc.plaintext", #selector(showLogs))
        addItem(menu, "使用帮助（新手必读）…", "questionmark.circle", #selector(openHelp))
        addItem(menu, "打开工作目录", "folder", #selector(openDir))
        addItem(menu, "退出助手", "power", #selector(quitApp))

        menu.addItem(.separator())
        let ver = NSMenuItem(title: appBuild, action: nil, keyEquivalent: "")
        ver.isEnabled = false
        menu.addItem(ver)
    }

    @objc func cancelAutoPublish(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        fire("/bin/bash \(shq(projDir + "/automation/unqueue-publish.sh")) \(shq(id))")
        notify("已取消 #\(id) 的自动发布")
    }

    // 最近发布（从本地缓存读，不阻塞 UI）
    func recentPublished() -> [(id: String, title: String, url: String)] {
        let out = sh("/bin/cat \(shq(aPath("recent"))) 2>/dev/null")
        return out.split(separator: "\n").compactMap { line in
            let c = line.components(separatedBy: "\t")
            guard c.count >= 3 else { return nil }
            return (c[0].trimmingCharacters(in: .whitespaces), c[1].trimmingCharacters(in: .whitespaces), c[2].trimmingCharacters(in: .whitespaces))
        }
    }

    @objc func openPost(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        let url = path.hasPrefix("http") ? path : "https://ccvar.com\(path)"
        fire("/usr/bin/open \(shq(url))")
    }

    // 预览草稿：用接口的 content_html 在本地生成渲染页并在浏览器打开（不发布）
    @objc func previewDraft(_ sender: NSMenuItem) {
        var id = "", type = "posts"
        if let s = sender.representedObject as? String { id = s }
        else if let a = sender.representedObject as? [String], let f = a.first { id = f; if a.count > 1 { type = a[1] } }
        guard !id.isEmpty else { return }
        showPreviewHUD(id)                       // 先弹「生成中」浮窗（带转圈），生成好再打开
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let path = self.sh("cd \(shq(projDir)) && /bin/bash automation/preview-draft.sh \(shq(id)) \(shq(type)) 2>/dev/null")
                         .trimmingCharacters(in: .whitespacesAndNewlines)
            DispatchQueue.main.async {
                self.hidePreviewHUD()
                if path.isEmpty { self.notify("没能生成 #\(id) 的预览") }
                else { self.fire("/usr/bin/open \(shq(path))") }
            }
        }
    }
    // 预览「生成中」浮窗：转圈 + 文案，生成好自动关闭再打开预览（防网络慢时无反馈）
    func showPreviewHUD(_ id: String) {
        hidePreviewHUD()
        let W: CGFloat = 300, H: CGFloat = 84
        let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: W, height: H),
                        styleMask: [.titled, .hudWindow, .nonactivatingPanel], backing: .buffered, defer: false)
        p.title = "预览"; p.isReleasedWhenClosed = false; p.level = .floating; p.hidesOnDeactivate = false
        let v = NSView(frame: NSRect(x: 0, y: 0, width: W, height: H))
        let sp = NSProgressIndicator(frame: NSRect(x: 24, y: H/2 - 13, width: 26, height: 26))   // 与文字同一垂直中心
        sp.style = .spinning; sp.isIndeterminate = true; sp.startAnimation(nil); v.addSubview(sp)
        let l = NSTextField(wrappingLabelWithString: "正在生成 #\(id) 预览…\n网络慢请稍候，生成好会自动打开")
        l.font = .systemFont(ofSize: 12)
        l.frame = NSRect(x: 62, y: H/2 - 17, width: W - 78, height: 34); v.addSubview(l)   // 高度恰好两行，中心对齐 H/2
        p.contentView = v
        p.center(); p.orderFrontRegardless()
        previewHUD = p
    }
    func hidePreviewHUD() { previewHUD?.orderOut(nil); previewHUD = nil }

    func addItem(_ menu: NSMenu, _ title: String, _ symbol: String, _ sel: Selector) {
        let it = NSMenuItem(title: title, action: sel, keyEquivalent: "")
        it.target = self
        it.image = tsym(symbol)
        menu.addItem(it)
    }

    func alert(_ title: String, _ body: String) {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = title
        a.informativeText = body.isEmpty ? "（空）" : body
        a.addButton(withTitle: "好")
        a.runModal()
    }

    // MARK: - 操作
    func draftNowTapped() {
        if isDrafting { return }            // 防重复点击
        isDrafting = true
        draftItemView?.setBusy(true)        // 原地显示「处理中…」，菜单不关
        notify("已开始撰稿（约数分钟）——菜单顶部「状态」行随时可看进度")
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/bash")
            p.arguments = ["-c", "cd \(shq(projDir)) && /bin/bash automation/run-daily.sh"]
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
            p.standardInput = FileHandle.nullDevice
            try? p.run()
            p.waitUntilExit()
            DispatchQueue.main.async {
                self.isDrafting = false
                self.draftItemView?.setDone()   // 完成后显示「✓ 已撰稿」
            }
        }
    }
    @objc func togglePause() {
        let action = isEnabled() ? "pause" : "resume"
        fire("/bin/bash \(shq(projDir + "/automation/manage.sh")) \(action)")
        notify(action == "pause" ? "已暂停每日自动撰稿" : "已恢复每日自动撰稿")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in self?.refreshIcon() }
    }
    @objc func showLogs() {
        let f = sh("ls -1t \(shq(projDir))/automation/logs/daily-*.log 2>/dev/null | head -1")
                  .trimmingCharacters(in: .whitespacesAndNewlines)
        if f.isEmpty { alert("最近运行日志", "还没有运行日志。"); return }
        if logWindow == nil { buildLogWindow() }
        refreshLog()
        presentWindow(logWindow)
        logTimer?.invalidate()
        let t = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in self?.refreshLog() }   // 实时刷新
        RunLoop.main.add(t, forMode: .common); logTimer = t
    }
    func buildLogWindow() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 460),
                         styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        w.title = "最近运行日志（实时刷新）"; w.isReleasedWhenClosed = false; w.delegate = self
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 720, height: 460))
        scroll.hasVerticalScroller = true; scroll.autoresizingMask = [.width, .height]
        let tv = NSTextView(frame: scroll.bounds)
        tv.isEditable = false; tv.isRichText = false; tv.autoresizingMask = [.width]
        tv.font = .monospacedSystemFont(ofSize: 12, weight: .regular); tv.textContainerInset = NSSize(width: 8, height: 8)
        scroll.documentView = tv; w.contentView = scroll
        logWindow = w; logTextView = tv
    }
    func refreshLog() {
        guard let tv = logTextView else { return }
        let f = sh("ls -1t \(shq(projDir))/automation/logs/daily-*.log 2>/dev/null | head -1")
                  .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !f.isEmpty else { return }
        let content = sh("tail -n 400 \(shq(f))")
        if tv.string != content { tv.string = content; tv.scrollToEndOfDocument(nil) }   // 有更新才刷，并滚到底
    }
    // 菜单栏(accessory)应用弹普通窗口时，临时切成 regular 才能成为 key 窗口、按钮才响应；
    // 全部受管窗口关闭后再切回 accessory（去掉 Dock 图标）。
    func presentWindow(_ w: NSWindow?) {
        guard let w = w else { return }
        if NSApp.activationPolicy() != .regular { NSApp.setActivationPolicy(.regular) }
        w.delegate = self
        w.center(); w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    func windowWillClose(_ note: Notification) {
        if (note.object as? NSWindow) === logWindow { logTimer?.invalidate(); logTimer = nil }
        DispatchQueue.main.async { [weak self] in            // 等窗口真正隐藏后再判断
            guard let self = self else { return }
            let managed = [self.globalSettingsWindow, self.siteSettingsWindow, self.sitesWindow, self.logWindow]
            if !managed.contains(where: { $0?.isVisible == true }) { NSApp.setActivationPolicy(.accessory) }
        }
    }
    @objc func editTopics() { fire("/usr/bin/open -t \(shq(aPath("topics")))") }
    @objc func openDir()   { fire("/usr/bin/open \(shq(projDir))") }
    @objc func openSite()  { fire("/usr/bin/open https://ccvar.com") }
    @objc func quitApp()   { NSApp.terminate(nil) }

    @objc func publishDraft(_ sender: NSMenuItem) {
        let arr = sender.representedObject as? [String]
        let id = arr?.first ?? (sender.representedObject as? String) ?? ""
        let title = (arr?.count ?? 0) > 1 ? arr![1] : "#\(id)"
        let type = (arr?.count ?? 0) > 2 ? arr![2] : "posts"
        guard !id.isEmpty else { return }
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = "发布这篇草稿？"
        a.informativeText = "\(title)\n\n发布后会立即公开上线，访客即可看到。"
        a.alertStyle = .warning
        a.addButton(withTitle: "发布")
        a.addButton(withTitle: "取消")
        guard a.runModal() == .alertFirstButtonReturn else { return }
        notify("正在发布 #\(id) 上线…")
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            // publish-now.sh：标记「正在发布」→ 发布 → 取消标记 → 刷新最近发布
            let out = self.sh("/bin/bash \(shq(projDir + "/automation/publish-now.sh")) \(shq(id)) \(shq(type))")
            let ok = out.contains("PUBLISH_OK")
            DispatchQueue.main.async {
                self.notify(ok ? "#\(id) 已上线：\(title)" : "发布失败（确认 Key 含 publish 权限）：\(title)")
            }
        }
    }

    @objc func openReviewQueue() { fire("/usr/bin/open \(shq(aPath("queue")))") }
    @objc func openHelp() { fire("/usr/bin/open \(shq(projDir + "/docs/help.html"))") }

    // 内容校准：AI 读站内已发布文章 → 更新选题库「网站定位」+ 补新选题
    @objc func calibrateSite() {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = "校准网站定位？"
        a.informativeText = "AI 会读取站内已发布文章，据此更新「选题库」的网站定位，并补几个贴合的新选题到待写队列。约一两分钟，完成后通知你。\n\n只改本地选题库，不会发布任何东西。"
        a.addButton(withTitle: "开始校准")
        a.addButton(withTitle: "取消")
        guard a.runModal() == .alertFirstButtonReturn else { return }
        notify("正在校准网站定位…（约一两分钟）")
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            _ = self.sh("/bin/bash \(shq(projDir + "/automation/calibrate.sh"))")
            DispatchQueue.main.async { self.notify("网站定位已校准 —— 点「编辑选题…」查看") }
        }
    }

    // MARK: - 设置（拆成「全局」和「本站」两个窗口，避免混淆）
    @objc func openGlobalSettings() {
        buildGlobalSettings(); loadGlobalSettings()
        presentWindow(globalSettingsWindow)
    }
    @objc func openSiteSettings() {
        loadActive(); buildSiteSettings(); loadSiteSettings()
        presentWindow(siteSettingsWindow)
    }

    func buildGlobalSettings() {
        let W: CGFloat = 480, H: CGFloat = 560
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: W, height: H), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "全局设置"; w.isReleasedWhenClosed = false
        let v = NSView(frame: NSRect(x: 0, y: 0, width: W, height: H))
        func sep(_ y: CGFloat) { let b = NSBox(frame: NSRect(x: 20, y: y, width: W - 40, height: 1)); b.boxType = .separator; v.addSubview(b) }
        func lab(_ s: String, _ y: CGFloat) { let l = NSTextField(labelWithString: s); l.alignment = .right; l.font = .systemFont(ofSize: 13); l.frame = NSRect(x: 12, y: y, width: 150, height: 18); v.addSubview(l) }
        let t = NSTextField(labelWithString: "全局设置"); t.font = .systemFont(ofSize: 15, weight: .semibold); t.frame = NSRect(x: 22, y: H - 42, width: 400, height: 20); v.addSubview(t)
        let s = NSTextField(labelWithString: "引擎 / 模型 / 登录 / 撰稿时间 —— 改这里影响【所有站点】"); s.font = .systemFont(ofSize: 11); s.textColor = .secondaryLabelColor; s.frame = NSRect(x: 22, y: H - 60, width: 450, height: 16); v.addSubview(s)
        sep(H - 72)
        let r1 = H - 104; lab("每日撰稿时间", r1)
        timePicker = NSDatePicker(frame: NSRect(x: 174, y: r1 - 4, width: 110, height: 26)); timePicker.datePickerStyle = .textFieldAndStepper; timePicker.datePickerElements = [.hourMinute]; v.addSubview(timePicker)
        let r2 = H - 142; lab("写作", r2)
        writerEnginePopup = NSPopUpButton(frame: NSRect(x: 172, y: r2 - 5, width: 112, height: 26)); writerEnginePopup.addItems(withTitles: engineTitles); writerEnginePopup.target = self; writerEnginePopup.action = #selector(engineChanged); v.addSubview(writerEnginePopup)
        modelPopup = NSPopUpButton(frame: NSRect(x: 290, y: r2 - 5, width: 172, height: 26)); modelPopup.addItems(withTitles: modelTitles); v.addSubview(modelPopup)
        let r3 = H - 180; lab("审核", r3)
        editorEnginePopup = NSPopUpButton(frame: NSRect(x: 172, y: r3 - 5, width: 112, height: 26)); editorEnginePopup.addItems(withTitles: engineTitles); editorEnginePopup.target = self; editorEnginePopup.action = #selector(engineChanged); v.addSubview(editorEnginePopup)
        editorPopup = NSPopUpButton(frame: NSRect(x: 290, y: r3 - 5, width: 172, height: 26)); editorPopup.addItems(withTitles: editorTitles); v.addSubview(editorPopup)
        let r4 = H - 220; lab("Claude 令牌", r4)
        tokenField = NSSecureTextField(frame: NSRect(x: 174, y: r4 - 3, width: 286, height: 24)); tokenField.placeholderString = "sk-ant-oat…（claude setup-token 生成）"; v.addSubview(tokenField)
        let r5 = H - 258; lab("OpenAI Key", r5)
        openaiField = NSSecureTextField(frame: NSRect(x: 174, y: r5 - 3, width: 286, height: 24)); openaiField.placeholderString = "可选；填了 GPT 按量计费，留空用 ChatGPT 登录"; v.addSubview(openaiField)
        let r6 = H - 296; lab("AI 命令（高级）", r6)
        cliField = NSTextField(frame: NSRect(x: 174, y: r6 - 3, width: 286, height: 24)); cliField.font = .monospacedSystemFont(ofSize: 11, weight: .regular); cliField.placeholderString = "默认 Claude；可改成 codex 等"; v.addSubview(cliField)
        let aiNote = NSTextField(wrappingLabelWithString: "留空就好：按上面选的「引擎 / 模型」自动写稿。\n填命令行则改用它生成草稿（高级逃生口·覆盖引擎，用于接自定义 AI CLI）。")
        aiNote.font = .systemFont(ofSize: 10); aiNote.textColor = .tertiaryLabelColor; aiNote.frame = NSRect(x: 174, y: 222, width: 292, height: 34); v.addSubview(aiNote)

        // 引擎登录状态指示灯（绿=已就绪 / 灰=未配置）+ 配置引导
        sep(212)
        let hdr = NSTextField(labelWithString: "AI 引擎"); hdr.font = .systemFont(ofSize: 12, weight: .semibold); hdr.frame = NSRect(x: 22, y: 188, width: 200, height: 16); v.addSubview(hdr)
        let recheck = iconBtn("arrow.clockwise", "重新检测", #selector(recheckEngines)); recheck.frame = NSRect(x: 438, y: 183, width: 30, height: 24); v.addSubview(recheck)
        func dot(_ y: CGFloat) -> NSImageView { let iv = NSImageView(frame: NSRect(x: 24, y: y, width: 12, height: 12)); iv.imageScaling = .scaleProportionallyDown; iv.image = csym("circle.fill", .systemGray); v.addSubview(iv); return iv }
        func logo(_ name: String, _ y: CGFloat) { let iv = NSImageView(frame: NSRect(x: 43, y: y, width: 12, height: 12)); iv.imageScaling = .scaleProportionallyDown; iv.image = brandLogo(name, 12); v.addSubview(iv) }
        claudeDot = dot(169)   // 比文本框中心高 2px，对齐文字视觉中心
        logo("claude", 169)
        claudeStatusLabel = NSTextField(labelWithString: "Claude：检测中…"); claudeStatusLabel.font = .systemFont(ofSize: 11); claudeStatusLabel.textColor = .secondaryLabelColor; claudeStatusLabel.frame = NSRect(x: 57, y: 165, width: 373, height: 16); v.addSubview(claudeStatusLabel)
        claudeBtn = iconBtn("key.fill", "登录…", #selector(loginClaude)); claudeBtn.frame = NSRect(x: 438, y: 160, width: 30, height: 24); v.addSubview(claudeBtn)
        gptDot = dot(145)   // 同上，上移 2px 对齐文字
        logo("openai", 145)
        gptStatusLabel = NSTextField(labelWithString: "GPT：检测中…"); gptStatusLabel.font = .systemFont(ofSize: 11); gptStatusLabel.textColor = .secondaryLabelColor; gptStatusLabel.frame = NSRect(x: 57, y: 141, width: 373, height: 16); v.addSubview(gptStatusLabel)
        gptBtn = iconBtn("key.fill", "登录…", #selector(loginCodex)); gptBtn.frame = NSRect(x: 438, y: 136, width: 30, height: 24); v.addSubview(gptBtn)
        let guide = NSTextField(wrappingLabelWithString: "配置方法（鼠标移到右侧图标上会显示说明）：\n· Claude：点登录图标授权后，把终端里打印的令牌复制，粘到上面「Claude 令牌」框。\n· GPT：点登录图标登录 ChatGPT 即可（免费额度），无需复制 key。完成后点刷新图标。")
        guide.font = .systemFont(ofSize: 11); guide.textColor = .tertiaryLabelColor; guide.frame = NSRect(x: 24, y: 56, width: W - 48, height: 78); v.addSubview(guide)
        sep(48)
        let save = NSButton(title: "保存", target: self, action: #selector(saveGlobalSettings)); save.frame = NSRect(x: W - 112, y: 16, width: 94, height: 30); save.bezelStyle = .rounded; save.keyEquivalent = "\r"; v.addSubview(save)
        let cancel = NSButton(title: "取消", target: self, action: #selector(closeGlobalSettings)); cancel.frame = NSRect(x: W - 210, y: 16, width: 94, height: 30); cancel.bezelStyle = .rounded; cancel.keyEquivalent = "\u{1b}"; v.addSubview(cancel)
        w.contentView = v; globalSettingsWindow = w
    }
    func loadGlobalSettings() {
        func g(_ k: String, _ d: String) -> String { sh("python3 -c 'import json;print(json.load(open(\"\(projDir)/config.json\")).get(\"\(k)\",\"\(d)\") or \"\(d)\")' 2>/dev/null").trimmingCharacters(in: .whitespacesAndNewlines) }
        let hh = Int(g("draft_hour", "8")) ?? 8, mm = Int(g("draft_minute", "0")) ?? 0
        var c = DateComponents(); c.hour = hh; c.minute = mm; timePicker.dateValue = Calendar.current.date(from: c) ?? Date()
        let model = g("model", ""), editor = g("editor_model", ""), cmodel = g("codex_model", "")
        let cmd = g("ai_cmd", ""); cliField.stringValue = cmd.isEmpty ? defaultAICmd : cmd
        tokenField.stringValue = sh("/usr/bin/grep '^CLAUDE_CODE_OAUTH_TOKEN=' \(shq(projDir + "/.claude-auth.env")) 2>/dev/null | cut -d= -f2-").trimmingCharacters(in: .whitespacesAndNewlines)
        openaiField.stringValue = sh("/usr/bin/grep '^OPENAI_API_KEY=' \(shq(projDir + "/.openai.env")) 2>/dev/null | cut -d= -f2-").trimmingCharacters(in: .whitespacesAndNewlines)
        let weng = g("writer_engine", "claude"), eeng = g("editor_engine", "claude")
        writerEnginePopup.selectItem(at: engineValues.firstIndex(of: weng) ?? 0)
        editorEnginePopup.selectItem(at: engineValues.firstIndex(of: eeng) ?? 0)
        engineChanged()
        if weng == "codex" { modelPopup.selectItem(at: codexModelValues.firstIndex(of: cmodel) ?? 0) } else { modelPopup.selectItem(at: modelValues.firstIndex(of: modelAliasMap[model] ?? model) ?? 0) }
        if eeng == "codex" { editorPopup.selectItem(at: codexModelValues.firstIndex(of: cmodel) ?? 0) } else { editorPopup.selectItem(at: editorValues.firstIndex(of: editor) ?? 0) }
        checkEngineStatus()
    }
    // 异步检测 Claude / GPT 是否配置可用，点亮全局设置面板的两盏指示灯
    func checkEngineStatus() {
        guard claudeDot != nil else { return }
        claudeStatusLabel.stringValue = "Claude：检测中…"; gptStatusLabel.stringValue = "GPT：检测中…"
        claudeDot.image = csym("circle.fill", .systemGray); gptDot.image = csym("circle.fill", .systemGray)
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let out = self.sh("/bin/bash \(shq(projDir + "/automation/engine-status.sh"))")
            var cState = "noauth", cMsg = "未配置", gState = "noauth", gMsg = "未配置"
            for line in out.split(separator: "\n") {
                let c = line.components(separatedBy: "\t"); guard c.count >= 3 else { continue }
                if c[0] == "claude" { cState = c[1]; cMsg = c[2] }
                if c[0] == "gpt"    { gState = c[1]; gMsg = c[2] }
            }
            DispatchQueue.main.async {
                guard self.claudeDot != nil else { return }
                self.applyEngine(cState, cMsg, "Claude", self.claudeDot, self.claudeStatusLabel, self.claudeBtn, #selector(self.loginClaude), #selector(self.installClaude))
                self.applyEngine(gState, gMsg, "GPT", self.gptDot, self.gptStatusLabel, self.gptBtn, #selector(self.loginCodex), #selector(self.installCodex))
            }
        }
    }
    // 按三态更新一行引擎：灯色 + 文字 + 按钮在「安装… / 登录… / 切换账号…」间切换
    func applyEngine(_ state: String, _ msg: String, _ name: String, _ dot: NSImageView, _ label: NSTextField, _ btn: NSButton, _ loginSel: Selector, _ installSel: Selector) {
        label.stringValue = "\(name)：\(msg)"
        switch state {
        case "ok":      // 已就绪：灯绿，图标降级为「切换账号」（不再误导成"去登录"）
            dot.image = csym("circle.fill", .systemGreen); label.textColor = .systemGreen
            btn.image = bsym("arrow.triangle.2.circlepath"); btn.toolTip = "切换账号…"; btn.action = loginSel
        case "missing": // 没装命令：灯橙，图标变「安装」（登录此时无意义）
            dot.image = csym("circle.fill", .systemOrange); label.textColor = .secondaryLabelColor
            btn.image = bsym("arrow.down.circle"); btn.toolTip = "安装…"; btn.action = installSel
        default:        // 装了没登录：灯灰，图标「登录」
            dot.image = csym("circle.fill", .systemGray); label.textColor = .secondaryLabelColor
            btn.image = bsym("key.fill"); btn.toolTip = "登录…"; btn.action = loginSel
        }
        btn.isEnabled = true
    }
    // 无边框图标按钮（imageOnly + 悬停提示），用于引擎行的安装/登录/切换/刷新
    func iconBtn(_ symbol: String, _ tip: String, _ sel: Selector) -> NSButton {
        let b = HoverIconButton(title: "", target: self, action: sel)
        b.isBordered = false; b.imagePosition = .imageOnly; b.imageScaling = .scaleProportionallyDown
        b.image = bsym(symbol); b.toolTip = tip; b.contentTintColor = .secondaryLabelColor
        return b
    }
    @objc func recheckEngines() { checkEngineStatus() }
    @objc func loginClaude() { _ = sh("/bin/bash \(shq(projDir + "/automation/engine-login.sh")) claude") }
    @objc func loginCodex()  { _ = sh("/bin/bash \(shq(projDir + "/automation/engine-login.sh")) gpt") }
    @objc func installClaude() { showInstall("Claude（claude 命令）", "npm install -g @anthropic-ai/claude-code", "https://www.npmjs.com/package/@anthropic-ai/claude-code") }
    @objc func installCodex()  { showInstall("GPT（codex 命令）", "npm install -g @openai/codex", "https://github.com/openai/codex") }
    func showInstall(_ name: String, _ cmd: String, _ url: String) {
        let a = NSAlert(); a.messageText = "还没安装 \(name)"
        a.informativeText = "这是个命令行工具，装一次即可。\n\n推荐用 npm 安装（需先装好 Node.js）：\n  \(cmd)\n\n装好后回到本面板点「重新检测」。"
        a.addButton(withTitle: "复制安装命令"); a.addButton(withTitle: "打开安装页"); a.addButton(withTitle: "好的")
        let r = a.runModal()
        if r == .alertFirstButtonReturn {
            NSPasteboard.general.clearContents(); NSPasteboard.general.setString(cmd, forType: .string)
            notify("已复制安装命令，去终端粘贴运行")
        } else if r == .alertSecondButtonReturn {
            _ = sh("/usr/bin/open \(shq(url))")
        }
    }
    @objc func saveGlobalSettings() {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: timePicker.dateValue)
        let hh = comps.hour ?? 8, mm = comps.minute ?? 0
        func pick(_ p: NSPopUpButton, _ vals: [String]) -> String { vals[min(max(p.indexOfSelectedItem, 0), vals.count - 1)] }
        func readCfg(_ k: String) -> String { sh("python3 -c 'import json;print(json.load(open(\"\(projDir)/config.json\")).get(\"\(k)\",\"\") or \"\")' 2>/dev/null").trimmingCharacters(in: .whitespacesAndNewlines) }
        let weng = pick(writerEnginePopup, engineValues), eeng = pick(editorEnginePopup, engineValues)
        let wIdx = max(modelPopup.indexOfSelectedItem, 0), eIdx = max(editorPopup.indexOfSelectedItem, 0)
        let model = (weng == "claude") ? modelValues[min(wIdx, modelValues.count - 1)] : readCfg("model")
        let editor = (eeng == "claude") ? editorValues[min(eIdx, editorValues.count - 1)] : readCfg("editor_model")
        var cxm = readCfg("codex_model")
        if weng == "codex" { cxm = codexModelValues[min(wIdx, codexModelValues.count - 1)] }
        if eeng == "codex" { cxm = codexModelValues[min(eIdx, codexModelValues.count - 1)] }
        let cli = cliField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let cliToSave = (cli.isEmpty || cli == defaultAICmd) ? "" : cli
        fire("/bin/bash \(shq(projDir + "/automation/apply-global-config.sh")) \(hh) \(mm) \(shq(model)) \(shq(cliToSave)) \(shq(editor)) \(shq(weng)) \(shq(eeng)) \(shq(cxm))")
        fire("/bin/bash \(shq(projDir + "/automation/set-token.sh")) \(shq(tokenField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)))")
        fire("/bin/bash \(shq(projDir + "/automation/set-openai-key.sh")) \(shq(openaiField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)))")
        closeGlobalSettings(); notify(String(format: "全局设置已保存（每天 %02d:%02d）", hh, mm))
    }
    @objc func closeGlobalSettings() { globalSettingsWindow?.orderOut(nil) }

    func buildSiteSettings() {
        let W: CGFloat = 480, H: CGFloat = 470
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: W, height: H), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "本站设置 · \(actName)"; w.isReleasedWhenClosed = false
        let v = NSView(frame: NSRect(x: 0, y: 0, width: W, height: H))
        let t = NSTextField(labelWithString: "本站设置 · \(actName)"); t.font = .systemFont(ofSize: 15, weight: .semibold); t.frame = NSRect(x: 22, y: H - 38, width: 440, height: 20); v.addSubview(t)
        let st = NSTextField(labelWithString: "每个能力各自配置、各自开关；密钥在「站点管理」里改"); st.font = .systemFont(ofSize: 11); st.textColor = .secondaryLabelColor; st.frame = NSRect(x: 22, y: H - 56, width: 460, height: 16); v.addSubview(st)
        let tabs = NSTabView(frame: NSRect(x: 12, y: 58, width: W - 24, height: H - 124)); v.addSubview(tabs)
        let p1 = NSView(frame: NSRect(x: 0, y: 0, width: W - 40, height: H - 160)); buildPostsTab(p1)
        let i1 = NSTabViewItem(identifier: "posts"); i1.label = "文章"; i1.view = p1; tabs.addTabViewItem(i1)
        let p3 = NSView(frame: NSRect(x: 0, y: 0, width: W - 40, height: H - 160)); buildLinksTab(p3)
        let i3 = NSTabViewItem(identifier: "links"); i3.label = "链接"; i3.view = p3; tabs.addTabViewItem(i3)
        let p2 = NSView(frame: NSRect(x: 0, y: 0, width: W - 40, height: H - 160)); buildPagesTab(p2)
        let i2 = NSTabViewItem(identifier: "pages"); i2.label = "页面"; i2.view = p2; tabs.addTabViewItem(i2)
        let save = NSButton(title: "保存", target: self, action: #selector(saveSiteSettings)); save.frame = NSRect(x: W - 112, y: 16, width: 94, height: 30); save.bezelStyle = .rounded; save.keyEquivalent = "\r"; v.addSubview(save)
        let cancel = NSButton(title: "取消", target: self, action: #selector(closeSiteSettings)); cancel.frame = NSRect(x: W - 210, y: 16, width: 94, height: 30); cancel.bezelStyle = .rounded; cancel.keyEquivalent = "\u{1b}"; v.addSubview(cancel)
        w.contentView = v; siteSettingsWindow = w
    }
    func placeholderTab(_ text: String) -> NSView {
        let pv = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 300))
        let l = NSTextField(wrappingLabelWithString: text); l.font = .systemFont(ofSize: 13); l.textColor = .secondaryLabelColor
        l.alignment = .center; l.frame = NSRect(x: 24, y: 110, width: 392, height: 150); pv.addSubview(l)
        return pv
    }
    // 文章 tab：原本站设置的全部控件（发布模式/否决/语种/增强），挪进 tab 内容视图
    func buildPostsTab(_ p: NSView) {
        func lab(_ s: String, _ y: CGFloat) { let l = NSTextField(labelWithString: s); l.alignment = .right; l.font = .systemFont(ofSize: 13); l.frame = NSRect(x: 4, y: y, width: 150, height: 18); p.addSubview(l) }
        func note(_ s: String, _ x: CGFloat, _ y: CGFloat, _ wd: CGFloat) { let l = NSTextField(labelWithString: s); l.font = .systemFont(ofSize: 10); l.textColor = .tertiaryLabelColor; l.frame = NSRect(x: x, y: y, width: wd, height: 14); p.addSubview(l) }
        let r1: CGFloat = 262; lab("发布模式", r1)
        modePopup = NSPopUpButton(frame: NSRect(x: 164, y: r1 - 5, width: 252, height: 26)); modePopup.addItems(withTitles: modeTitles); p.addSubview(modePopup)
        let r2: CGFloat = 226; lab("否决窗口", r2)
        vetoField = NSTextField(frame: NSRect(x: 166, y: r2 - 3, width: 46, height: 24)); p.addSubview(vetoField)
        note("小时后才自动发，期间你可拦（仅全自动）", 218, r2, 232)
        let langsRaw = sh("python3 -c 'import json;[print(c[\"code\"]+\"|\"+c[\"name\"]) for c in json.load(open(\"\(aPath("config"))\")).get(\"langs_cache\",[])]' 2>/dev/null").trimmingCharacters(in: .whitespacesAndNewlines)
        var langs: [(code: String, name: String)] = langsRaw.split(separator: "\n").compactMap { let pp = $0.components(separatedBy: "|"); return pp.count >= 2 ? (pp[0], pp[1]) : nil }
        if langs.isEmpty { langs = [("zh", "中文"), ("en", "English")] }
        langCodes = langs.map { $0.code }
        let r3: CGFloat = 188; lab("写作语种", r3)
        writeLangPopup = NSPopUpButton(frame: NSRect(x: 164, y: r3 - 5, width: 146, height: 26)); for l in langs { writeLangPopup.addItem(withTitle: "\(l.name)（\(l.code)）") }; writeLangPopup.target = self; writeLangPopup.action = #selector(writeLangChanged); p.addSubview(writeLangPopup)
        let twl = NSTextField(labelWithString: "目标字数"); twl.font = .systemFont(ofSize: 12); twl.textColor = .secondaryLabelColor; twl.frame = NSRect(x: 316, y: r3 - 1, width: 62, height: 18); p.addSubview(twl)
        postWordsField = NSTextField(frame: NSRect(x: 380, y: r3 - 4, width: 52, height: 24)); postWordsField.placeholderString = "默认"; p.addSubview(postWordsField)
        let r4: CGFloat = 150; lab("译文方式", r4)
        langModePopup = NSPopUpButton(frame: NSRect(x: 164, y: r4 - 5, width: 252, height: 26)); langModePopup.addItems(withTitles: langModeTitles); p.addSubview(langModePopup)
        let r5: CGFloat = 108; lab("译文语种", r5)
        langChecks = []; var cx: CGFloat = 164
        for l in langs { let cb = NSButton(checkboxWithTitle: l.name, target: self, action: #selector(transCheckChanged)); cb.sizeToFit(); var f = cb.frame; f.origin = NSPoint(x: cx, y: r5 - 2); cb.frame = f; p.addSubview(cb); langChecks.append((l.code, cb)); cx += cb.frame.width + 16 }
        transHint = NSTextField(labelWithString: ""); transHint.font = .systemFont(ofSize: 10); transHint.textColor = .tertiaryLabelColor; transHint.frame = NSRect(x: 164, y: r5 - 19, width: 320, height: 14); p.addSubview(transHint)
        let r6: CGFloat = 62; lab("增强", r6)
        catCheck = NSButton(checkboxWithTitle: "自动归类", target: nil, action: nil); catCheck.frame = NSRect(x: 164, y: r6 - 2, width: 86, height: 20); p.addSubview(catCheck)
        coverCheck = NSButton(checkboxWithTitle: "自动配图", target: nil, action: nil); coverCheck.frame = NSRect(x: 252, y: r6 - 2, width: 86, height: 20); p.addSubview(coverCheck)
        codeCheck = NSButton(checkboxWithTitle: "含代码示例", target: nil, action: nil); codeCheck.frame = NSRect(x: 340, y: r6 - 2, width: 100, height: 20); p.addSubview(codeCheck)
        note("译文·配图更费额度，默认关；归类建议开", 164, r6 - 19, 300)
    }
    // 页面 tab：填页面清单 + 发布模式 + 「起草这些页面」按钮
    func buildPagesTab(_ p: NSView) {
        let l = NSTextField(labelWithString: "要起草的页面（每行一个：标题 | 这页讲什么）"); l.font = .systemFont(ofSize: 12); l.frame = NSRect(x: 12, y: 270, width: 420, height: 18); p.addSubview(l)
        let scroll = NSScrollView(frame: NSRect(x: 12, y: 120, width: 416, height: 144)); scroll.hasVerticalScroller = true; scroll.borderType = .bezelBorder
        let tv = NSTextView(frame: scroll.bounds); tv.font = .systemFont(ofSize: 12); tv.isRichText = false; tv.textContainerInset = NSSize(width: 4, height: 4)
        tv.isAutomaticQuoteSubstitutionEnabled = false; tv.isAutomaticDashSubstitutionEnabled = false
        scroll.documentView = tv; p.addSubview(scroll); pagesTextView = tv
        let ml = NSTextField(labelWithString: "发布模式"); ml.alignment = .right; ml.font = .systemFont(ofSize: 13); ml.frame = NSRect(x: 0, y: 88, width: 150, height: 18); p.addSubview(ml)
        pagesModePopup = NSPopUpButton(frame: NSRect(x: 160, y: 83, width: 158, height: 26)); pagesModePopup.addItems(withTitles: lfModeTitles); p.addSubview(pagesModePopup)
        let pwl = NSTextField(labelWithString: "目标字数"); pwl.font = .systemFont(ofSize: 12); pwl.textColor = .secondaryLabelColor; pwl.frame = NSRect(x: 324, y: 87, width: 60, height: 18); p.addSubview(pwl)
        pagesWordsField = NSTextField(frame: NSRect(x: 384, y: 84, width: 48, height: 24)); pagesWordsField.placeholderString = "默认"; p.addSubview(pagesWordsField)
        let nt = NSTextField(wrappingLabelWithString: "页面是门面，建议「手动」——起草后到菜单「待审页面」预览、确认再发。只生成草稿。"); nt.font = .systemFont(ofSize: 10); nt.textColor = .tertiaryLabelColor; nt.frame = NSRect(x: 12, y: 42, width: 418, height: 30); p.addSubview(nt)
        let btn = NSButton(title: "起草这些页面", target: self, action: #selector(draftPagesTapped)); btn.frame = NSRect(x: 12, y: 10, width: 140, height: 30); btn.bezelStyle = .rounded; p.addSubview(btn)
    }
    func loadPagesConfig() {
        pagesTextView?.string = (try? String(contentsOfFile: aPath("pages"), encoding: .utf8)) ?? ""
        let m = sh("python3 -c 'import json;print(json.load(open(\"\(aPath("config"))\")).get(\"pages_publish_mode\",\"manual\") or \"manual\")' 2>/dev/null").trimmingCharacters(in: .whitespacesAndNewlines)
        pagesModePopup?.selectItem(at: modeValues.firstIndex(of: m) ?? 0)
        let tw = sh("python3 -c 'import json;print(json.load(open(\"\(aPath("config"))\")).get(\"pages_target_words\",0) or 0)' 2>/dev/null").trimmingCharacters(in: .whitespacesAndNewlines)
        pagesWordsField?.stringValue = (tw == "0" || tw.isEmpty) ? "" : tw
    }
    func savePagesConfig() {
        guard pagesTextView != nil else { return }
        try? pagesTextView.string.write(toFile: aPath("pages"), atomically: true, encoding: .utf8)
        let mode = modeValues[min(max(pagesModePopup.indexOfSelectedItem, 0), modeValues.count - 1)]
        let tw = max(0, Int(pagesWordsField.stringValue.trimmingCharacters(in: .whitespaces)) ?? 0)
        let py = "import json,os,sys;p=sys.argv[1];d=json.load(open(p)) if os.path.exists(p) else {};d['pages_publish_mode']=sys.argv[2];d['pages_target_words']=int(sys.argv[3]);json.dump(d,open(p,'w'),ensure_ascii=False,indent=2)"
        _ = sh("/usr/bin/python3 -c \(shq(py)) \(shq(aPath("config"))) \(shq(mode)) \(tw)")
    }
    @objc func draftPagesTapped() {
        savePagesConfig()
        let lines = pagesTextView.string.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty && !$0.hasPrefix("#") }
        guard !lines.isEmpty else { alert("没有页面", "请先在框里每行填一个：标题 | 这页讲什么"); return }
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert(); a.messageText = "起草这 \(lines.count) 个页面？"
        a.informativeText = "AI 会逐个写草稿（每个约一两分钟），只生成草稿、不发布。完成后到菜单「待审页面」预览、发布。"
        a.addButton(withTitle: "开始起草"); a.addButton(withTitle: "取消")
        guard a.runModal() == .alertFirstButtonReturn else { return }
        notify("正在起草 \(lines.count) 个页面…（每个约一两分钟，菜单状态行可看进度）")
        let slug = actSlug
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let out = self.sh("cd \(shq(projDir)) && CCVAR_SITE=\(shq(slug)) /bin/bash automation/draft-pages.sh 2>&1")
            let n = self.firstMatch(out, "PAGES_DRAFTED ([0-9]+)") ?? "?"
            DispatchQueue.main.async { self.notify("已起草 \(n) 个页面草稿 —— 去菜单「待审页面」查看") }
        }
    }
    // 链接 tab：贴网址 + 发布模式 + 「生成」按钮（脚本抓取→AI 写标题/描述/分类）
    func buildLinksTab(_ p: NSView) {
        let l = NSTextField(labelWithString: "要收录的链接（每行一个网址，可选：网址 | 提示）"); l.font = .systemFont(ofSize: 12); l.frame = NSRect(x: 12, y: 272, width: 420, height: 18); p.addSubview(l)
        let scroll = NSScrollView(frame: NSRect(x: 12, y: 132, width: 416, height: 134)); scroll.hasVerticalScroller = true; scroll.borderType = .bezelBorder
        let tv = NSTextView(frame: scroll.bounds); tv.font = .systemFont(ofSize: 12); tv.isRichText = false; tv.textContainerInset = NSSize(width: 4, height: 4)
        tv.isAutomaticQuoteSubstitutionEnabled = false; tv.isAutomaticDashSubstitutionEnabled = false; tv.isAutomaticLinkDetectionEnabled = false
        scroll.documentView = tv; p.addSubview(scroll); linksTextView = tv
        let ml = NSTextField(labelWithString: "发布模式"); ml.alignment = .right; ml.font = .systemFont(ofSize: 13); ml.frame = NSRect(x: 0, y: 102, width: 150, height: 18); p.addSubview(ml)
        linksModePopup = NSPopUpButton(frame: NSRect(x: 160, y: 97, width: 158, height: 26)); linksModePopup.addItems(withTitles: lfModeTitles); p.addSubview(linksModePopup)
        let lwl = NSTextField(labelWithString: "介绍字数"); lwl.font = .systemFont(ofSize: 12); lwl.textColor = .secondaryLabelColor; lwl.frame = NSRect(x: 324, y: 101, width: 60, height: 18); p.addSubview(lwl)
        linksWordsField = NSTextField(frame: NSRect(x: 384, y: 98, width: 48, height: 24)); linksWordsField.placeholderString = "默认"; p.addSubview(linksWordsField)
        let el = NSTextField(labelWithString: "增强"); el.alignment = .right; el.font = .systemFont(ofSize: 13); el.frame = NSRect(x: 0, y: 70, width: 150, height: 18); p.addSubview(el)
        linksCatCheck = NSButton(checkboxWithTitle: "自动归类", target: nil, action: nil); linksCatCheck.frame = NSRect(x: 160, y: 68, width: 100, height: 20); p.addSubview(linksCatCheck)
        linksCoverCheck = NSButton(checkboxWithTitle: "自动配图", target: nil, action: nil); linksCoverCheck.frame = NSRect(x: 268, y: 68, width: 100, height: 20); p.addSubview(linksCoverCheck)
        let nt = NSTextField(wrappingLabelWithString: "脚本抓取每个网址的标题/摘要，AI 据此写标题、详细介绍与摘要；归类=AI 选分类，配图=生成品牌封面（更费额度）。生成后到「待审链接」审/发。只生成草稿。"); nt.font = .systemFont(ofSize: 10); nt.textColor = .tertiaryLabelColor; nt.frame = NSRect(x: 12, y: 40, width: 418, height: 24); p.addSubview(nt)
        let btn = NSButton(title: "生成", target: self, action: #selector(draftLinksTapped)); btn.frame = NSRect(x: 12, y: 8, width: 120, height: 30); btn.bezelStyle = .rounded; p.addSubview(btn)
    }
    func loadLinksConfig() {
        linksTextView?.string = (try? String(contentsOfFile: aPath("links"), encoding: .utf8)) ?? ""
        let m = sh("python3 -c 'import json;print(json.load(open(\"\(aPath("config"))\")).get(\"links_publish_mode\",\"manual\") or \"manual\")' 2>/dev/null").trimmingCharacters(in: .whitespacesAndNewlines)
        linksModePopup?.selectItem(at: modeValues.firstIndex(of: m) ?? 0)
        func gb(_ k: String, _ d: String) -> Bool { sh("python3 -c 'import json;print(json.load(open(\"\(aPath("config"))\")).get(\"\(k)\",\(d)))' 2>/dev/null").trimmingCharacters(in: .whitespacesAndNewlines) == "True" }
        linksCatCheck?.state = gb("links_auto_category", "True") ? .on : .off
        linksCoverCheck?.state = gb("links_auto_cover", "False") ? .on : .off
        let tw = sh("python3 -c 'import json;print(json.load(open(\"\(aPath("config"))\")).get(\"links_target_words\",0) or 0)' 2>/dev/null").trimmingCharacters(in: .whitespacesAndNewlines)
        linksWordsField?.stringValue = (tw == "0" || tw.isEmpty) ? "" : tw
    }
    func saveLinksConfig() {
        guard linksTextView != nil else { return }
        try? linksTextView.string.write(toFile: aPath("links"), atomically: true, encoding: .utf8)
        let mode = modeValues[min(max(linksModePopup.indexOfSelectedItem, 0), modeValues.count - 1)]
        let cat = linksCatCheck.state == .on ? "True" : "False", cover = linksCoverCheck.state == .on ? "True" : "False"
        let tw = max(0, Int(linksWordsField.stringValue.trimmingCharacters(in: .whitespaces)) ?? 0)
        let py = "import json,os,sys;p=sys.argv[1];d=json.load(open(p)) if os.path.exists(p) else {};d['links_publish_mode']=sys.argv[2];d['links_auto_category']=(sys.argv[3]=='True');d['links_auto_cover']=(sys.argv[4]=='True');d['links_target_words']=int(sys.argv[5]);json.dump(d,open(p,'w'),ensure_ascii=False,indent=2)"
        _ = sh("/usr/bin/python3 -c \(shq(py)) \(shq(aPath("config"))) \(shq(mode)) \(shq(cat)) \(shq(cover)) \(tw)")
    }
    @objc func draftLinksTapped() {
        saveLinksConfig()
        let urls = linksTextView.string.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.hasPrefix("http") }
        guard !urls.isEmpty else { alert("没有网址", "请在框里每行贴一个网址（http/https 开头）。"); return }
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert(); a.messageText = "收录这 \(urls.count) 个链接？"
        a.informativeText = "脚本会逐个抓取网页、AI 写标题/描述/分类（每个约一两分钟），只生成草稿、不发布。完成后到菜单「待审链接」预览、发布。"
        a.addButton(withTitle: "开始生成"); a.addButton(withTitle: "取消")
        guard a.runModal() == .alertFirstButtonReturn else { return }
        notify("正在收录 \(urls.count) 个链接…（每个约一两分钟，菜单状态行可看进度）")
        let slug = actSlug
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let out = self.sh("cd \(shq(projDir)) && CCVAR_SITE=\(shq(slug)) /bin/bash automation/draft-links.sh 2>&1")
            let n = self.firstMatch(out, "LINKS_DRAFTED ([0-9]+)") ?? "?"
            DispatchQueue.main.async { self.notify("已收录 \(n) 个链接草稿 —— 去菜单「待审链接」查看") }
        }
    }
    func loadSiteSettings() {
        func sc(_ key: String, _ d: String) -> String { sh("python3 -c 'import json;print(json.load(open(\"\(aPath("config"))\")).get(\"\(key)\",\"\(d)\") or \"\(d)\")' 2>/dev/null").trimmingCharacters(in: .whitespacesAndNewlines) }
        modePopup.selectItem(at: modeValues.firstIndex(of: sc("publish_mode", "manual")) ?? 0)
        let veto = sh("python3 -c 'import json;print(json.load(open(\"\(aPath("config"))\")).get(\"veto_hours\",6))' 2>/dev/null").trimmingCharacters(in: .whitespacesAndNewlines)
        vetoField.stringValue = veto.isEmpty ? "6" : veto
        func cfgBool(_ key: String, _ d: String) -> Bool { sh("python3 -c 'import json;print(json.load(open(\"\(aPath("config"))\")).get(\"\(key)\",\(d)))' 2>/dev/null").trimmingCharacters(in: .whitespacesAndNewlines) == "True" }
        catCheck.state = cfgBool("auto_category", "True") ? .on : .off
        coverCheck.state = cfgBool("auto_cover", "False") ? .on : .off
        codeCheck.state = cfgBool("include_code", "True") ? .on : .off
        let twv = sh("python3 -c 'import json;print(json.load(open(\"\(aPath("config"))\")).get(\"target_words\",0) or 0)' 2>/dev/null").trimmingCharacters(in: .whitespacesAndNewlines)
        postWordsField.stringValue = (twv == "0" || twv.isEmpty) ? "" : twv
        let wl = sc("write_lang", "zh"); if let idx = langCodes.firstIndex(of: wl) { writeLangPopup.selectItem(at: idx) }
        let tl = sh("python3 -c 'import json;print(\" \".join(json.load(open(\"\(aPath("config"))\")).get(\"translate_langs\",[])))' 2>/dev/null").trimmingCharacters(in: .whitespacesAndNewlines)
        let tlset = Set(tl.split(separator: " ").map(String.init)); for (code, btn) in langChecks { btn.state = tlset.contains(code) ? .on : .off }
        langModePopup.selectItem(at: langModeValues.firstIndex(of: sc("lang_mode", "translate")) ?? 0)
        writeLangChanged()
        loadPagesConfig()      // 页面 tab：清单 + 发布模式
        loadLinksConfig()      // 链接 tab：网址 + 发布模式
        fire("/bin/bash \(shq(projDir + "/automation/refresh-langs.sh"))")
    }
    @objc func saveSiteSettings() {
        let mode = modeValues[min(max(modePopup.indexOfSelectedItem, 0), modeValues.count - 1)]
        let veto = max(0, Int(vetoField.stringValue.trimmingCharacters(in: .whitespaces)) ?? 6)
        let cat = catCheck.state == .on ? "1" : "0", cover = coverCheck.state == .on ? "1" : "0"
        let wlang = langCodes.isEmpty ? "zh" : langCodes[min(max(writeLangPopup.indexOfSelectedItem, 0), langCodes.count - 1)]
        let tcsv = langChecks.filter { $0.btn.state == .on && $0.code != wlang }.map { $0.code }.joined(separator: ",")
        let lmode = langModeValues[min(max(langModePopup.indexOfSelectedItem, 0), langModeValues.count - 1)]
        let tw = max(0, Int(postWordsField.stringValue.trimmingCharacters(in: .whitespaces)) ?? 0)
        let code = codeCheck.state == .on ? "1" : "0"
        fire("/bin/bash \(shq(projDir + "/automation/apply-site-config.sh")) \(shq(mode)) \(veto) \(cat) \(shq(wlang)) \(shq(tcsv)) \(cover) \(shq(lmode)) \(tw) \(code)")
        savePagesConfig()      // 页面 tab：清单 + 发布模式 一起存
        saveLinksConfig()      // 链接 tab：网址 + 发布模式 一起存
        closeSiteSettings(); notify("本站设置已保存（\(actName)）")
    }
    @objc func closeSiteSettings() { siteSettingsWindow?.orderOut(nil) }

    // MARK: - 旧的单一设置窗口（已停用，保留以兼容编译）
    @objc func openSettings() {
        buildSettings()   // 每次重建，反映当前活动站的语种等
        loadSettings()
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func buildSettings() {
        let W: CGFloat = 480, H: CGFloat = 780
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: W, height: H),
                         styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "设置"
        w.isReleasedWhenClosed = false
        let v = NSView(frame: NSRect(x: 0, y: 0, width: W, height: H))

        let iconView = NSImageView(frame: NSRect(x: 26, y: H - 60, width: 36, height: 36))
        iconView.image = iconColored ?? loadIcon("favicon")
        iconView.imageScaling = .scaleProportionallyUpOrDown
        v.addSubview(iconView)
        let title = NSTextField(labelWithString: "CCVAR 撰稿助手")
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        title.frame = NSRect(x: 72, y: H - 44, width: 320, height: 20); v.addSubview(title)
        let subtitle = NSTextField(labelWithString: "运营设置")
        subtitle.font = .systemFont(ofSize: 12); subtitle.textColor = .secondaryLabelColor
        subtitle.frame = NSRect(x: 72, y: H - 62, width: 320, height: 16); v.addSubview(subtitle)

        func separator(_ y: CGFloat) {
            let b = NSBox(frame: NSRect(x: 20, y: y, width: W - 40, height: 1)); b.boxType = .separator; v.addSubview(b)
        }
        func formLabel(_ s: String, _ y: CGFloat) {
            let l = NSTextField(labelWithString: s); l.alignment = .right; l.font = .systemFont(ofSize: 13)
            l.frame = NSRect(x: 12, y: y, width: 150, height: 18); v.addSubview(l)
        }
        func note(_ s: String, _ x: CGFloat, _ y: CGFloat, _ wdt: CGFloat) {
            let l = NSTextField(labelWithString: s); l.font = .systemFont(ofSize: 10); l.textColor = .tertiaryLabelColor
            l.frame = NSRect(x: x, y: y, width: wdt, height: 14); v.addSubview(l)
        }
        separator(H - 82)

        let r1: CGFloat = H - 120
        formLabel("每日撰稿时间", r1)
        timePicker = NSDatePicker(frame: NSRect(x: 174, y: r1 - 4, width: 110, height: 26))
        timePicker.datePickerStyle = .textFieldAndStepper; timePicker.datePickerElements = [.hourMinute]; v.addSubview(timePicker)

        let r2: CGFloat = H - 158
        formLabel("写作", r2)
        writerEnginePopup = NSPopUpButton(frame: NSRect(x: 172, y: r2 - 5, width: 112, height: 26))
        writerEnginePopup.addItems(withTitles: engineTitles)
        writerEnginePopup.target = self; writerEnginePopup.action = #selector(engineChanged); v.addSubview(writerEnginePopup)
        modelPopup = NSPopUpButton(frame: NSRect(x: 290, y: r2 - 5, width: 172, height: 26))
        modelPopup.addItems(withTitles: modelTitles); v.addSubview(modelPopup)

        let r3: CGFloat = H - 196
        formLabel("审核", r3)
        editorEnginePopup = NSPopUpButton(frame: NSRect(x: 172, y: r3 - 5, width: 112, height: 26))
        editorEnginePopup.addItems(withTitles: engineTitles)
        editorEnginePopup.target = self; editorEnginePopup.action = #selector(engineChanged); v.addSubview(editorEnginePopup)
        editorPopup = NSPopUpButton(frame: NSRect(x: 290, y: r3 - 5, width: 172, height: 26))
        editorPopup.addItems(withTitles: editorTitles); v.addSubview(editorPopup)

        let r4: CGFloat = H - 234
        formLabel("发布模式", r4)
        modePopup = NSPopUpButton(frame: NSRect(x: 172, y: r4 - 5, width: 252, height: 26))
        modePopup.addItems(withTitles: modeTitles); v.addSubview(modePopup)

        let r5: CGFloat = H - 270
        formLabel("否决窗口", r5)
        vetoField = NSTextField(frame: NSRect(x: 174, y: r5 - 3, width: 46, height: 24)); v.addSubview(vetoField)
        note("小时后才自动发，期间你可拦（仅全自动）", 226, r5, 232)

        // 语种：从 langs_cache 读取（本地、快；打开设置时后台异步刷新缓存）
        let langsRaw = sh("python3 -c 'import json;[print(c[\"code\"]+\"|\"+c[\"name\"]) for c in json.load(open(\"\(aPath("config"))\")).get(\"langs_cache\",[])]' 2>/dev/null")
                         .trimmingCharacters(in: .whitespacesAndNewlines)
        var langs: [(code: String, name: String)] = langsRaw.split(separator: "\n").compactMap {
            let p = $0.components(separatedBy: "|"); return p.count >= 2 ? (p[0], p[1]) : nil
        }
        if langs.isEmpty { langs = [("zh", "中文"), ("en", "English")] }
        langCodes = langs.map { $0.code }

        let r6: CGFloat = H - 306
        formLabel("写作语种", r6)
        writeLangPopup = NSPopUpButton(frame: NSRect(x: 172, y: r6 - 5, width: 170, height: 26))
        for l in langs { writeLangPopup.addItem(withTitle: "\(l.name)（\(l.code)）") }
        writeLangPopup.target = self; writeLangPopup.action = #selector(writeLangChanged); v.addSubview(writeLangPopup)

        let rMode: CGFloat = H - 346
        formLabel("译文方式", rMode)
        langModePopup = NSPopUpButton(frame: NSRect(x: 172, y: rMode - 5, width: 292, height: 26))
        langModePopup.addItems(withTitles: langModeTitles); v.addSubview(langModePopup)

        let r7: CGFloat = H - 388
        formLabel("译文语种", r7)
        langChecks = []
        var cx: CGFloat = 172
        for l in langs {
            let cb = NSButton(checkboxWithTitle: l.name, target: nil, action: nil)
            cb.sizeToFit(); var f = cb.frame; f.origin = NSPoint(x: cx, y: r7 - 2); cb.frame = f
            v.addSubview(cb); langChecks.append((l.code, cb)); cx += cb.frame.width + 16
        }
        note("勾哪些就额外产哪些语种译文；不勾=不翻译（写作语种会自动置灰）", 172, r7 - 19, 320)

        let r8: CGFloat = H - 434
        formLabel("增强", r8)
        catCheck = NSButton(checkboxWithTitle: "自动归类目录", target: nil, action: nil)
        catCheck.frame = NSRect(x: 172, y: r8 - 2, width: 128, height: 20); v.addSubview(catCheck)
        coverCheck = NSButton(checkboxWithTitle: "自动配图", target: nil, action: nil)
        coverCheck.frame = NSRect(x: 304, y: r8 - 2, width: 100, height: 20); v.addSubview(coverCheck)
        note("译文·配图更费额度，默认关；归类建议开", 172, r8 - 19, 300)

        separator(H - 460)

        let r9: CGFloat = H - 496
        formLabel("CCVAR API 密钥", r9)
        keyField = NSSecureTextField(frame: NSRect(x: 174, y: r9 - 3, width: 286, height: 24))
        keyField.placeholderString = "gcms_…"; v.addSubview(keyField)

        let r10: CGFloat = H - 534
        formLabel("Claude 令牌", r10)
        tokenField = NSSecureTextField(frame: NSRect(x: 174, y: r10 - 3, width: 286, height: 24))
        tokenField.placeholderString = "sk-ant-oat…（claude setup-token 生成）"; v.addSubview(tokenField)

        let rOAI: CGFloat = H - 572
        formLabel("OpenAI Key", rOAI)
        openaiField = NSSecureTextField(frame: NSRect(x: 174, y: rOAI - 3, width: 286, height: 24))
        openaiField.placeholderString = "可选；填了 GPT 按量计费，留空用 ChatGPT 登录"; v.addSubview(openaiField)

        let r11: CGFloat = H - 610
        formLabel("AI 命令（高级）", r11)
        cliField = NSTextField(frame: NSRect(x: 174, y: r11 - 3, width: 286, height: 24))
        cliField.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        cliField.placeholderString = "默认 Claude；可改成 codex 等"; v.addSubview(cliField)

        let hint = NSTextField(wrappingLabelWithString: "写作/审核可各选 Claude 或 GPT 引擎。模式：手动只撰稿／半自动给建议你点发／全自动过审自动发。Claude 令牌在终端 claude setup-token 生成后粘进来。")
        hint.font = .systemFont(ofSize: 11); hint.textColor = .secondaryLabelColor
        hint.frame = NSRect(x: 22, y: 78, width: W - 44, height: 52); v.addSubview(hint)

        gptStatusLabel = NSTextField(labelWithString: "GPT 登录：检测中…")
        gptStatusLabel.font = .systemFont(ofSize: 10); gptStatusLabel.textColor = .tertiaryLabelColor
        gptStatusLabel.frame = NSRect(x: 22, y: 60, width: W - 44, height: 14); v.addSubview(gptStatusLabel)

        separator(54)
        let save = NSButton(title: "保存", target: self, action: #selector(saveSettings))
        save.frame = NSRect(x: W - 112, y: 16, width: 94, height: 30); save.bezelStyle = .rounded; save.keyEquivalent = "\r"; v.addSubview(save)
        let cancel = NSButton(title: "取消", target: self, action: #selector(closeSettings))
        cancel.frame = NSRect(x: W - 210, y: 16, width: 94, height: 30); cancel.bezelStyle = .rounded; cancel.keyEquivalent = "\u{1b}"; v.addSubview(cancel)

        w.contentView = v
        settingsWindow = w
    }

    func loadSettings() {
        let hh = Int(sh("python3 -c 'import json;print(json.load(open(\"\(projDir)/config.json\")).get(\"draft_hour\",8))' 2>/dev/null")
                       .trimmingCharacters(in: .whitespacesAndNewlines)) ?? 8
        let mm = Int(sh("python3 -c 'import json;print(json.load(open(\"\(projDir)/config.json\")).get(\"draft_minute\",0))' 2>/dev/null")
                       .trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        var c = DateComponents(); c.hour = hh; c.minute = mm
        timePicker.dateValue = Calendar.current.date(from: c) ?? Date()
        let key = sh("/usr/bin/grep '^CCVAR_API_KEY=' \(shq(aPath("keyfile"))) 2>/dev/null | cut -d= -f2-")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
        keyField.stringValue = (key == "PASTE_YOUR_KEY_HERE") ? "" : key
        let cmd = sh("python3 -c 'import json;print(json.load(open(\"\(projDir)/config.json\")).get(\"ai_cmd\",\"\") or \"\")' 2>/dev/null")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
        cliField.stringValue = cmd.isEmpty ? defaultAICmd : cmd
        let model = sh("python3 -c 'import json;print(json.load(open(\"\(projDir)/config.json\")).get(\"model\",\"\") or \"\")' 2>/dev/null")
                      .trimmingCharacters(in: .whitespacesAndNewlines)
        let token = sh("/usr/bin/grep '^CLAUDE_CODE_OAUTH_TOKEN=' \(shq(projDir + "/.claude-auth.env")) 2>/dev/null | cut -d= -f2-")
                      .trimmingCharacters(in: .whitespacesAndNewlines)
        tokenField.stringValue = token
        let editor = sh("python3 -c 'import json;print(json.load(open(\"\(projDir)/config.json\")).get(\"editor_model\",\"\") or \"\")' 2>/dev/null")
                       .trimmingCharacters(in: .whitespacesAndNewlines)
        let mode = sh("python3 -c 'import json;print(json.load(open(\"\(aPath("config"))\")).get(\"publish_mode\",\"manual\") or \"manual\")' 2>/dev/null")
                     .trimmingCharacters(in: .whitespacesAndNewlines)
        modePopup.selectItem(at: modeValues.firstIndex(of: mode) ?? 0)
        let veto = sh("python3 -c 'import json;print(json.load(open(\"\(aPath("config"))\")).get(\"veto_hours\",6))' 2>/dev/null")
                     .trimmingCharacters(in: .whitespacesAndNewlines)
        vetoField.stringValue = veto.isEmpty ? "6" : veto
        func cfgBool(_ key: String, _ dflt: String) -> Bool {
            sh("python3 -c 'import json;print(json.load(open(\"\(aPath("config"))\")).get(\"\(key)\",\(dflt)))' 2>/dev/null")
              .trimmingCharacters(in: .whitespacesAndNewlines) == "True"
        }
        catCheck.state = cfgBool("auto_category", "True") ? .on : .off
        coverCheck.state = cfgBool("auto_cover", "False") ? .on : .off
        let wl = sh("python3 -c 'import json;print(json.load(open(\"\(aPath("config"))\")).get(\"write_lang\",\"zh\") or \"zh\")' 2>/dev/null")
                   .trimmingCharacters(in: .whitespacesAndNewlines)
        if let idx = langCodes.firstIndex(of: wl) { writeLangPopup.selectItem(at: idx) }
        let tl = sh("python3 -c 'import json;print(\" \".join(json.load(open(\"\(aPath("config"))\")).get(\"translate_langs\",[])))' 2>/dev/null")
                   .trimmingCharacters(in: .whitespacesAndNewlines)
        let tlset = Set(tl.split(separator: " ").map(String.init))
        for (code, btn) in langChecks { btn.state = tlset.contains(code) ? .on : .off }
        let lmode = sh("python3 -c 'import json;print(json.load(open(\"\(aPath("config"))\")).get(\"lang_mode\",\"translate\") or \"translate\")' 2>/dev/null")
                      .trimmingCharacters(in: .whitespacesAndNewlines)
        langModePopup.selectItem(at: langModeValues.firstIndex(of: lmode) ?? 0)
        writeLangChanged()
        let weng = sh("python3 -c 'import json;print(json.load(open(\"\(projDir)/config.json\")).get(\"writer_engine\",\"claude\") or \"claude\")' 2>/dev/null")
                     .trimmingCharacters(in: .whitespacesAndNewlines)
        writerEnginePopup.selectItem(at: engineValues.firstIndex(of: weng) ?? 0)
        let eeng = sh("python3 -c 'import json;print(json.load(open(\"\(projDir)/config.json\")).get(\"editor_engine\",\"claude\") or \"claude\")' 2>/dev/null")
                     .trimmingCharacters(in: .whitespacesAndNewlines)
        editorEnginePopup.selectItem(at: engineValues.firstIndex(of: eeng) ?? 0)
        engineChanged()
        let cmodel = sh("python3 -c 'import json;print(json.load(open(\"\(projDir)/config.json\")).get(\"codex_model\",\"\") or \"\")' 2>/dev/null")
                       .trimmingCharacters(in: .whitespacesAndNewlines)
        if weng == "codex" { modelPopup.selectItem(at: codexModelValues.firstIndex(of: cmodel) ?? 0) }
        else { modelPopup.selectItem(at: modelValues.firstIndex(of: modelAliasMap[model] ?? model) ?? 0) }
        if eeng == "codex" { editorPopup.selectItem(at: codexModelValues.firstIndex(of: cmodel) ?? 0) }
        else { editorPopup.selectItem(at: editorValues.firstIndex(of: editor) ?? 0) }
        let oaikey = sh("/usr/bin/grep '^OPENAI_API_KEY=' \(shq(projDir + "/.openai.env")) 2>/dev/null | cut -d= -f2-")
                       .trimmingCharacters(in: .whitespacesAndNewlines)
        openaiField.stringValue = oaikey
        checkGPTLogin()
        // 后台异步刷新语种缓存，供下次打开设置时更新（不阻塞 UI）
        fire("/bin/bash \(shq(projDir + "/automation/refresh-langs.sh"))")
    }

    @objc func writeLangChanged() {
        guard !langCodes.isEmpty else { return }
        let wl = langCodes[min(max(writeLangPopup.indexOfSelectedItem, 0), langCodes.count - 1)]
        for (code, btn) in langChecks {
            if code == wl { btn.state = .off; btn.isEnabled = false } else { btn.isEnabled = true }
        }
        updateTransUI()
    }
    @objc func transCheckChanged() { updateTransUI() }
    // 译文区自适应：单语种或一个译文都没勾时，「译文方式」自动置灰并给清晰提示
    func updateTransUI() {
        guard transHint != nil, langModePopup != nil else { return }
        let targets = langChecks.filter { $0.btn.isEnabled }        // 非写作语种 = 可作译文目标
        if targets.isEmpty {
            langModePopup.isEnabled = false
            transHint.stringValue = "本站只有一个语种，无需译文。"
        } else if !targets.contains(where: { $0.btn.state == .on }) {
            langModePopup.isEnabled = false
            transHint.stringValue = "未勾选 = 只写「写作语种」、不产译文。要多语言就在上面勾。"
        } else {
            langModePopup.isEnabled = true
            transHint.stringValue = "勾选的语种会额外产出译文（更费额度）。"
        }
    }

    @objc func engineChanged() {
        repopModel(modelPopup, writerEnginePopup, modelTitles)
        repopModel(editorPopup, editorEnginePopup, editorTitles)
    }
    // 引擎=GPT 时该模型下拉换成 GPT 模型；=Claude 时换回 Claude 模型
    func repopModel(_ p: NSPopUpButton?, _ engine: NSPopUpButton?, _ claudeTitles: [String]) {
        guard let p = p else { return }
        let isGPT = (engine?.indexOfSelectedItem ?? 0) == 1
        let titles = isGPT ? codexModelTitles : claudeTitles
        let cur = max(p.indexOfSelectedItem, 0)
        p.removeAllItems(); p.addItems(withTitles: titles)
        p.selectItem(at: min(cur, titles.count - 1)); p.isEnabled = true
    }

    // 异步检测 GPT(codex) 登录状态，更新设置页那行备注（不阻塞 UI）
    func checkGPTLogin() {
        guard gptStatusLabel != nil else { return }
        gptStatusLabel.stringValue = "GPT 登录：检测中…"; gptStatusLabel.textColor = .tertiaryLabelColor
        let dir = projDir
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let hasKey = self.sh("/usr/bin/test -s \(shq(dir + "/.openai.env")) && echo 1 || echo 0")
                           .trimmingCharacters(in: .whitespacesAndNewlines) == "1"
            let out = self.sh("export PATH=\"$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin\"; codex login status 2>&1").lowercased()
            let loggedIn = out.contains("logged in")
            DispatchQueue.main.async {
                if hasKey {
                    self.gptStatusLabel.stringValue = "GPT 登录：✅ 用 OpenAI Key（按量计费）"
                    self.gptStatusLabel.textColor = .systemGreen
                } else if loggedIn {
                    self.gptStatusLabel.stringValue = "GPT 登录：✅ ChatGPT 已登录（自动识别本机 codex）"
                    self.gptStatusLabel.textColor = .systemGreen
                } else {
                    self.gptStatusLabel.stringValue = "GPT 登录：⚠️ 未登录 · 终端跑 codex login，或上方填 OpenAI Key"
                    self.gptStatusLabel.textColor = .systemOrange
                }
            }
        }
    }

    @objc func saveSettings() {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: timePicker.dateValue)
        let hh = comps.hour ?? 8, mm = comps.minute ?? 0
        func pick(_ p: NSPopUpButton, _ vals: [String]) -> String { vals[min(max(p.indexOfSelectedItem, 0), vals.count - 1)] }
        func readCfg(_ k: String) -> String {
            sh("python3 -c 'import json;print(json.load(open(\"\(projDir)/config.json\")).get(\"\(k)\",\"\") or \"\")' 2>/dev/null").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let mode = pick(modePopup, modeValues)
        let veto = max(0, Int(vetoField.stringValue.trimmingCharacters(in: .whitespaces)) ?? 6)
        let cli = cliField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let cliToSave = (cli.isEmpty || cli == defaultAICmd) ? "" : cli
        let cat = catCheck.state == .on ? "1" : "0"
        let cover = coverCheck.state == .on ? "1" : "0"
        let wlang = langCodes.isEmpty ? "zh" : langCodes[min(max(writeLangPopup.indexOfSelectedItem, 0), langCodes.count - 1)]
        let tcsv = langChecks.filter { $0.btn.state == .on && $0.code != wlang }.map { $0.code }.joined(separator: ",")
        let lmode = langModeValues[min(max(langModePopup.indexOfSelectedItem, 0), langModeValues.count - 1)]
        let weng = engineValues[min(max(writerEnginePopup.indexOfSelectedItem, 0), engineValues.count - 1)]
        let eeng = engineValues[min(max(editorEnginePopup.indexOfSelectedItem, 0), engineValues.count - 1)]
        // 模型：引擎=Claude 时下拉是 Claude 模型；=GPT 时是 GPT 模型 → 存到 codex_model
        let wIdx = max(modelPopup.indexOfSelectedItem, 0), eIdx = max(editorPopup.indexOfSelectedItem, 0)
        let model = (weng == "claude") ? modelValues[min(wIdx, modelValues.count - 1)] : readCfg("model")
        let editor = (eeng == "claude") ? editorValues[min(eIdx, editorValues.count - 1)] : readCfg("editor_model")
        var codexModel = readCfg("codex_model")
        if weng == "codex" { codexModel = codexModelValues[min(wIdx, codexModelValues.count - 1)] }
        if eeng == "codex" { codexModel = codexModelValues[min(eIdx, codexModelValues.count - 1)] }
        // 一次性写入 config.json（避免并发撞坏）并更新定时器
        fire("/bin/bash \(shq(projDir + "/automation/apply-config.sh")) \(hh) \(mm) \(shq(model)) \(shq(cliToSave)) \(shq(editor)) \(shq(mode)) \(veto) \(cat) \(shq(wlang)) \(shq(tcsv)) \(cover) \(shq(lmode)) \(shq(weng)) \(shq(eeng)) \(shq(codexModel))")
        let oaikey = openaiField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        fire("/bin/bash \(shq(projDir + "/automation/set-openai-key.sh")) \(shq(oaikey))")
        let key = keyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty {
            fire("/bin/bash \(shq(projDir + "/automation/set-key.sh")) \(shq(key))")
        }
        let token = tokenField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        fire("/bin/bash \(shq(projDir + "/automation/set-token.sh")) \(shq(token))")
        closeSettings()
        notify(String(format: "设置已保存：每天 %02d:%02d", hh, mm))
    }
    @objc func closeSettings() { settingsWindow?.orderOut(nil) }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // 仅菜单栏，无 Dock 图标
let delegate = AppDelegate()
app.delegate = delegate
app.run()
