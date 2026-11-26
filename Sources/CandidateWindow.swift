import Cocoa

/// 舊注音的直式選字窗：一行一個「1 我」，底下顯示頁數；聯想詞時上方有標題。
final class CandidateWindow {
    static let shared = CandidateWindow()

    private let panel: NSPanel
    private let view = CandidateView()
    private var hideTimer: Timer?

    /// 目前是哪一個輸入控制器打開的（每個輸入框各有一個控制器，但視窗只有一個）
    weak var owner: AnyObject?
    var isVisible: Bool { panel.isVisible }

    var onPick: ((Int) -> Void)? {
        get { view.onPick }
        set { view.onPick = newValue }
    }

    private init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: true)
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.popUpMenuWindow)) + 1)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // 系統選單那種半透明圓角底，深淺色自動跟著系統
        let fx = NSVisualEffectView()
        fx.material = .menu
        fx.state = .active
        fx.blendingMode = .behindWindow
        fx.wantsLayer = true
        fx.layer?.cornerRadius = 9
        fx.layer?.masksToBounds = true
        fx.layer?.borderWidth = 0.5
        fx.layer?.borderColor = NSColor.separatorColor.cgColor
        fx.addSubview(view)
        panel.contentView = fx
    }

    func show(items: [String], title: String?, footer: String?, near rect: NSRect, compact: Bool = false) {
        hideTimer?.invalidate()
        view.set(items: items, title: title, footer: footer, compact: compact)
        place(near: rect)
    }

    /// 切換中英時短暫顯示目前模式
    func flash(_ text: String, near rect: NSRect) {
        hideTimer?.invalidate()
        view.set(items: [], title: text, footer: nil, compact: false)
        place(near: rect)
        hideTimer = Timer.scheduledTimer(withTimeInterval: 0.9, repeats: false) { [weak self] _ in self?.hide() }
    }

    /// 視窗開著時移到新的位置（內容不變）
    func move(near rect: NSRect) {
        guard panel.isVisible else { return }
        place(near: rect)
    }

    func hide() {
        hideTimer?.invalidate()
        panel.orderOut(nil)
    }

    private func place(near rect: NSRect) {
        let size = view.fittingSize
        // 固定放在這一行文字的上方；上面放不下才放到下方
        var origin = NSPoint(x: rect.minX, y: rect.maxY + 3)
        let screen = NSScreen.screens.first { $0.frame.contains(NSPoint(x: rect.midX, y: rect.midY)) } ?? NSScreen.main
        if let vf = screen?.visibleFrame {
            if origin.y + size.height > vf.maxY { origin.y = rect.minY - size.height - 3 }
            origin.x = min(max(origin.x, vf.minX), vf.maxX - size.width)
            origin.y = min(max(origin.y, vf.minY), vf.maxY - size.height)
        }
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        view.frame = NSRect(origin: .zero, size: size)
        panel.invalidateShadow()
        panel.orderFrontRegardless()
    }
}

final class CandidateView: NSView {
    var onPick: ((Int) -> Void)?

    private static func han(_ size: CGFloat) -> NSFont { NSFont(name: "PingFangTC-Regular", size: size) ?? NSFont.systemFont(ofSize: size) }
    private static let smallFont = NSFont.systemFont(ofSize: 14)
    private static let pad: CGFloat = 5
    // 一般選字用大字；聯想詞用小一號的精簡版
    private var hanFont = CandidateView.han(18)
    private var numFont = NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .medium)
    private var rowH: CGFloat = 30
    private var footerH: CGFloat = 22

    private var items: [String] = []
    private var title: String?
    private var footer: String?
    private var size = NSSize(width: 80, height: 30)
    private var hover: Int?

    override var isFlipped: Bool { true }
    override var fittingSize: NSSize { size }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private func width(_ s: String, _ f: NSFont) -> CGFloat { ceil(NSAttributedString(string: s, attributes: [.font: f]).size().width) }

    func set(items: [String], title: String?, footer: String?, compact: Bool) {
        self.items = items; self.title = title; self.footer = footer; hover = nil
        hanFont = CandidateView.han(18)
        numFont = NSFont.monospacedDigitSystemFont(ofSize: compact ? 12 : 14, weight: .medium)
        rowH = compact ? 26 : 30
        footerH = 22
        var w: CGFloat = 0
        for s in items { w = max(w, width(s, hanFont) + (rowH < 30 ? 34 : 46)) }
        if let t = title { w = max(w, width(t, items.isEmpty ? hanFont : Self.smallFont) + 24) }
        if let f = footer { w = max(w, width(f, Self.smallFont) + 24) }
        let h = Self.pad * 2 + (title != nil ? (items.isEmpty ? 30 : 22) : 0)
            + CGFloat(items.count) * rowH + (footer != nil ? footerH : 0)
        size = NSSize(width: max(w, rowH < 30 ? 60 : 76), height: h)
        frame = NSRect(origin: .zero, size: size)
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways],
                                       owner: self, userInfo: nil))
        needsDisplay = true
    }

    private var top: CGFloat { Self.pad + (title != nil ? 22 : 0) }
    private func rowRect(_ i: Int) -> NSRect {
        NSRect(x: Self.pad, y: top + CGFloat(i) * rowH, width: bounds.width - Self.pad * 2, height: rowH)
    }

    override func draw(_ dirtyRect: NSRect) {
        if let t = title {
            if items.isEmpty {   // 中英切換提示
                let s = NSAttributedString(string: t, attributes: [.font: hanFont, .foregroundColor: NSColor.labelColor])
                s.draw(at: NSPoint(x: (bounds.width - s.size().width) / 2, y: (bounds.height - s.size().height) / 2))
            } else {
                let s = NSAttributedString(string: t, attributes: [.font: Self.smallFont, .foregroundColor: NSColor.secondaryLabelColor])
                s.draw(at: NSPoint(x: Self.pad + 8, y: Self.pad + 2))
            }
        }
        for (i, c) in items.enumerated() {
            let r = rowRect(i)
            let on = i == hover
            if on {
                NSColor.controlAccentColor.setFill()
                NSBezierPath(roundedRect: r, xRadius: 5, yRadius: 5).fill()
            }
            let n = NSAttributedString(string: "\(i + 1)", attributes: [.font: numFont,
                .foregroundColor: on ? NSColor.white.withAlphaComponent(0.85) : NSColor.secondaryLabelColor])
            n.draw(at: NSPoint(x: r.minX + (rowH < 30 ? 7 : 9), y: r.midY - n.size().height / 2))
            let s = NSAttributedString(string: c, attributes: [.font: hanFont,
                .foregroundColor: on ? NSColor.white : NSColor.labelColor])
            s.draw(at: NSPoint(x: r.minX + (rowH < 30 ? 22 : 28), y: r.midY - s.size().height / 2))
        }
        if let f = footer {
            let s = NSAttributedString(string: f, attributes: [.font: Self.smallFont, .foregroundColor: NSColor.tertiaryLabelColor])
            s.draw(at: NSPoint(x: bounds.width - s.size().width - Self.pad - 6, y: bounds.height - Self.pad - footerH + 2))
        }
    }

    private func index(at event: NSEvent) -> Int? {
        let pt = convert(event.locationInWindow, from: nil)
        return items.indices.first { rowRect($0).contains(pt) }
    }

    override func mouseMoved(with event: NSEvent) {
        let i = index(at: event)
        if i != hover { hover = i; needsDisplay = true }
    }

    override func mouseExited(with event: NSEvent) { hover = nil; needsDisplay = true }

    override func mouseDown(with event: NSEvent) {
        if let i = index(at: event) { onPick?(i) }
    }
}
