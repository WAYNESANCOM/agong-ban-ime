import Cocoa
import InputMethodKit

@objc(BopomofoHalfInputController)
final class InputController: IMKInputController {
    // 中英、全半形跨 App 共用，跟以前一樣切一次就到處生效
    static var chinese = true
    static var fullWidth = false

    private let engine = Engine()
    private var shiftAlone = false
    private var shiftDownAt = Date.distantPast
    private static let shiftHold: TimeInterval = 0.8   // 按住 Shift 這麼久再放開才切中英
    private var assoc: [String]? = nil
    private var assocPage = 0
    private var lastCaret: NSRect?
    // 數字列 1~9 的 keyCode，聯想詞用 Shift+數字選
    private static let digitKeyCodes: [UInt16: Int] = [18: 1, 19: 2, 20: 3, 21: 4, 23: 5, 22: 6, 26: 7, 28: 8, 25: 9]
    // 右邊數字鍵盤的 0~9 和 . * + / - =（不含 Enter）
    private static let keypadKeyCodes: Set<UInt16> = [82, 83, 84, 85, 86, 87, 88, 89, 91, 92, 65, 67, 69, 75, 78, 81]

    override func recognizedEvents(_ sender: Any!) -> Int {
        Int(NSEvent.EventTypeMask([.keyDown, .keyUp, .flagsChanged]).rawValue)
    }

    override func activateServer(_ sender: Any!) {
        lastCaret = nil
        // 指定底層鍵盤配置，沙盒 App 才會正常把鍵送進來
        (sender as? IMKTextInput)?.overrideKeyboard(withKeyboardNamed: "com.apple.keylayout.ABC")
        engine.reset()
        assoc = nil
        CandidateWindow.shared.hide()
    }

    override func setValue(_ value: Any!, forTag tag: Int, client sender: Any!) {
        (sender as? IMKTextInput)?.overrideKeyboard(withKeyboardNamed: "com.apple.keylayout.ABC")
    }

    override func deactivateServer(_ sender: Any!) {
        if engine.isActive, let c = sender as? IMKTextInput { setMarked("", client: c) }
        engine.reset()
        assoc = nil
        CandidateWindow.shared.hide()
    }

    override func commitComposition(_ sender: Any!) {
        if engine.isActive, let c = sender as? IMKTextInput { setMarked("", client: c) }
        engine.reset()
        assoc = nil
        CandidateWindow.shared.hide()
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event = event, let client = sender as? IMKTextInput else { return false }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if event.type == .flagsChanged {
            // 長按 Shift（中間沒按別的鍵）放開 = 中英切換
            if flags == .shift { shiftAlone = true; shiftDownAt = Date() }
            else if flags.isEmpty && shiftAlone {
                shiftAlone = false
                if Date().timeIntervalSince(shiftDownAt) >= InputController.shiftHold { toggleChinese(client) }
            }
            else { shiftAlone = false }
            return false
        }
        if event.type == .keyUp { return false }
        shiftAlone = false
        guard event.type == .keyDown else { return false }
        // 視窗是別的輸入框（舊的控制器）開的：這邊沒有它的狀態，直接關掉，免得留在畫面上
        if CandidateWindow.shared.isVisible, CandidateWindow.shared.owner !== self { CandidateWindow.shared.hide() }
        // 保險：沒在打字、也沒有聯想詞，視窗卻還在，就關掉
        if CandidateWindow.shared.isVisible, assoc == nil, !engine.isActive { CandidateWindow.shared.hide() }

        if let list = assoc {
            let pages = (list.count + Engine.perPage - 1) / Engine.perPage
            let start = assocPage * Engine.perPage
            if flags == .shift, let n = InputController.digitKeyCodes[event.keyCode], start + n <= list.count {
                commit(list[start + n - 1], client: client)
                return true
            }
            if flags.isEmpty && pages > 1 && [49, 125, 121, 126, 116].contains(event.keyCode) {   // 空白、↓、PageDown 下一頁；↑、PageUp 上一頁
                let back = event.keyCode == 126 || event.keyCode == 116
                assocPage = (assocPage + (back ? pages - 1 : 1)) % pages
                showAssoc(client)
                return true
            }
            closeAssoc()
            if event.keyCode == 53 { return true }   // Esc 只關掉聯想
        }

        if flags == [.control, .shift] && event.keyCode == 3 {   // Ctrl+Shift+F 切換繁體／簡體輸出
            toggleSimplified(nil)
            return true
        }
        if InputController.chinese && flags == [.control, .option] && event.keyCode == 43 {   // Ctrl+Option+, 符號表
            if engine.isActive { setMarked("", client: client) }
            engine.openSymbols(); refresh(client)
            return true
        }
        if flags.contains(.command) || flags.contains(.control) || flags.contains(.option) {
            return engine.isActive   // 組字中吞掉快捷鍵，避免打到一半被搶走
        }
        if event.keyCode == 49 && flags.contains(.shift) {   // Shift+空白
            InputController.fullWidth.toggle()
            CandidateWindow.shared.flash(InputController.fullWidth ? "全形" : "半形", near: caretRect(client))
            return true
        }
        // 跟以前的ㄅ半一樣：右邊數字鍵盤直接打數字和運算符號，不當成注音
        if InputController.chinese, !flags.contains(.capsLock), InputController.keypadKeyCodes.contains(event.keyCode),
           let s = event.characters, s.count == 1 {
            switch engine.literal(s, fullWidth: InputController.fullWidth) {
            case .commit(let out): commit(out, client: client)
            case .beep: NSSound.beep()
            default: break
            }
            return true
        }
        // 跟以前的ㄅ半一樣：注音模式下按住 Shift 加字母打英文，大寫鎖定燈亮是大寫、沒亮是小寫
        if InputController.chinese, flags.subtracting(.capsLock) == .shift,
           let s = event.characters?.lowercased(), s.count == 1, let u = s.unicodeScalars.first, (0x61...0x7A).contains(u.value) {
            let letter = flags.contains(.capsLock) ? s.uppercased() : s
            switch engine.literal(letter, fullWidth: InputController.fullWidth) {
            case .commit(let out): commit(out, client: client)
            case .beep: NSSound.beep()
            default: break
            }
            return true
        }
        if !InputController.chinese || flags.contains(.capsLock) {
            guard InputController.fullWidth, let s = event.characters, s.count == 1,
                  let u = s.unicodeScalars.first, (0x20...0x7E).contains(u.value) else { return false }
            client.insertText(Engine.fullWidth(s), replacementRange: NSRange(location: NSNotFound, length: 0))
            return true
        }

        guard let key = keyName(event) else { return engine.isActive }
        switch engine.handle(key, fullWidth: InputController.fullWidth) {
        case .pass:
            return false
        case .beep:
            NSSound.beep()
            return true
        case .commit(let s):
            commit(s, client: client)
            if key == "Enter" { closeAssoc() }   // 用 Enter 送出就不跳聯想詞
            return true
        case .commitThenPass(let s):
            commit(s, client: client)
            closeAssoc()
            return false
        case .consumed:
            refresh(client)
            return true
        }
    }

    private func keyName(_ e: NSEvent) -> String? {
        switch e.keyCode {
        case 51: return "Backspace"
        case 53: return "Escape"
        case 36, 76: return "Enter"
        case 48: return "Tab"
        case 123: return "Left"
        case 124: return "Right"
        case 125: return "Down"
        case 126: return "Up"
        case 116: return "PageUp"
        case 121: return "PageDown"
        case 49: return " "
        default:
            // 用 characters 才會帶到 Shift（Shift+, 是 <、Shift+a 是 A）；charactersIgnoringModifiers 在這裡會把 Shift 丟掉
            guard let s = e.characters, s.count == 1,
                  let u = s.unicodeScalars.first, (0x21...0x7E).contains(u.value) else { return nil }
            return s
        }
    }

    private func toggleChinese(_ client: IMKTextInput) {
        InputController.chinese.toggle()
        if engine.isActive { setMarked("", client: client); engine.reset() }
        assoc = nil
        CandidateWindow.shared.flash(InputController.chinese ? "【注音】" : "【英數】", near: caretRect(client))
    }

    private func refresh(_ client: IMKTextInput) {
        setMarked(engine.display, client: client)
        if engine.candidates != nil {
            CandidateWindow.shared.onPick = { [weak self, weak client] i in
                guard let self = self, let client = client else { return }
                if case .commit(let s) = self.engine.pickOnPage(i) { self.commit(s, client: client) }
            }
            CandidateWindow.shared.owner = self
            CandidateWindow.shared.show(items: engine.pageItems.map(Engine.out), title: engine.isSymbols ? "符號" : nil,
                                        footer: engine.pageCount > 1 ? "\(engine.page + 1)/\(engine.pageCount)" : nil,
                                        near: caretRect(client))
        } else {
            CandidateWindow.shared.hide()
        }
    }

    /// 送出文字；是中文字就接著跳聯想詞
    private func commit(_ s: String, client: IMKTextInput) {
        setMarked("", client: client)
        client.insertText(Engine.out(s), replacementRange: NSRange(location: NSNotFound, length: 0))
        if engine.isActive { closeAssoc(); refresh(client); return }   // 已經接著打下一個字的注音
        guard let list = Engine.associations(after: s) else { closeAssoc(); return }
        assoc = Engine.dedupeForOutput(list)
        assocPage = 0
        showAssoc(client)
    }

    private func showAssoc(_ client: IMKTextInput) {
        guard let list = assoc else { return }
        let pages = (list.count + Engine.perPage - 1) / Engine.perPage
        let start = assocPage * Engine.perPage
        let items = Array(list[start..<min(start + Engine.perPage, list.count)])
        CandidateWindow.shared.onPick = { [weak self, weak client] i in
            guard let self = self, let client = client, let l = self.assoc, start + i < l.count else { return }
            self.commit(l[start + i], client: client)
        }
        let footer = pages > 1 ? "\(assocPage + 1)/\(pages)　⇧＋數字" : "⇧＋數字"
        CandidateWindow.shared.owner = self
        CandidateWindow.shared.show(items: items.map(Engine.out), title: nil, footer: footer, near: caretRect(client), compact: true)
        // 有些 App（例如 VS Code）送出字後要隔一下才更新游標；稍等再問一次，把視窗移到最後一個字旁邊
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self, weak client] in
            guard let self = self, let client = client, self.assoc != nil, !self.engine.isActive else { return }
            var r = NSRect.zero
            _ = client.attributes(forCharacterIndex: 0, lineHeightRectangle: &r)
            guard r != .zero else { return }
            self.lastCaret = r
            CandidateWindow.shared.move(near: r)
        }
    }

    override func menu() -> NSMenu! {
        let m = NSMenu()
        let item = NSMenuItem(title: "簡體輸出（Ctrl+Shift+F）", action: #selector(toggleSimplified(_:)), keyEquivalent: "")
        item.target = self
        item.state = Engine.simplified ? .on : .off
        m.addItem(item)
        return m
    }

    @objc func toggleSimplified(_ sender: Any?) {
        Engine.simplified.toggle()
        if let c = client() { CandidateWindow.shared.flash(Engine.simplified ? "簡體" : "繁體", near: caretRect(c)) }
    }

    /// 關掉聯想詞，也關掉視窗（視窗可能還留著剛才的選字清單，例如選了沒有聯想詞的字）
    private func closeAssoc() {
        assoc = nil
        CandidateWindow.shared.hide()
    }

    private func setMarked(_ s: String, client: IMKTextInput) {
        let attr = NSAttributedString(string: s, attributes: [
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .markedClauseSegment: 0,
        ])
        client.setMarkedText(attr, selectionRange: NSRange(location: (s as NSString).length, length: 0),
                             replacementRange: NSRange(location: NSNotFound, length: 0))
    }

    /// 游標位置。打注音時問 App「組字開頭」在哪並記下來；送出字之後有些 App（例如 VS Code）
    /// 還沒更新游標，問到的會是輸入框開頭，所以聯想詞改用剛才記下的位置，跟在最後一個字那裡
    private func caretRect(_ client: IMKTextInput) -> NSRect {
        if !engine.isActive, let last = lastCaret { return last }
        var rect = NSRect.zero
        _ = client.attributes(forCharacterIndex: 0, lineHeightRectangle: &rect)
        if rect == .zero, let s = NSScreen.main { return NSRect(x: s.frame.midX, y: s.frame.midY, width: 0, height: 0) }
        if engine.isActive { lastCaret = rect }
        return rect
    }
}
