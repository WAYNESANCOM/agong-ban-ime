import Foundation

/// ㄅ半注音的打字邏輯：大千鍵盤、聲調查字、逐字選字。不碰任何 UI。
final class Engine {
    static let keyMap: [String: String] = [
        "1": "ㄅ", "q": "ㄆ", "a": "ㄇ", "z": "ㄈ", "2": "ㄉ", "w": "ㄊ", "s": "ㄋ", "x": "ㄌ",
        "e": "ㄍ", "d": "ㄎ", "c": "ㄏ", "r": "ㄐ", "f": "ㄑ", "v": "ㄒ", "5": "ㄓ", "t": "ㄔ",
        "g": "ㄕ", "b": "ㄖ", "y": "ㄗ", "h": "ㄘ", "n": "ㄙ", "u": "ㄧ", "j": "ㄨ", "m": "ㄩ",
        "8": "ㄚ", "i": "ㄛ", "k": "ㄜ", ",": "ㄝ", "9": "ㄞ", "o": "ㄟ", "l": "ㄠ", ".": "ㄡ",
        "0": "ㄢ", "p": "ㄣ", ";": "ㄤ", "/": "ㄥ", "-": "ㄦ",
    ]
    static let tones: [String: String] = [" ": "", "6": "ˊ", "3": "ˇ", "4": "ˋ", "7": "˙"]
    static let punct: [String: String] = [
        "<": "，", ">": "。", "?": "？", ":": "：", "\"": "；", "!": "！", "(": "（", ")": "）",
        "[": "「", "]": "」", "{": "『", "}": "』", "'": "、", "~": "～", "@": "＠", "#": "＃",
        "$": "＄", "%": "％", "^": "︿", "&": "＆", "*": "＊", "_": "－", "+": "＋", "=": "＝",
        "|": "｜", "\\": "＼",
    ]
    /// 符號表（按 ` 或 Ctrl+Option+, 開啟）
    static let symbols: [String] = Array("，。、；：？！…‥「」『』（）【】《》〈〉〔〕﹁﹂﹃﹄―～‧·※○●◎△▲□■☆★◇◆→←↑↓＋－×÷＝≠≒≦≧∞√％‰＄￥＃＆＊＠°℃㊣♀♂§№").map(String.init)
    static let medials = "ㄧㄨㄩ"
    static let finals = "ㄚㄛㄜㄝㄞㄟㄠㄡㄢㄣㄤㄥㄦ"
    static let perPage = 9

    static let dict: [String: [String]] = {
        guard let url = Bundle.main.url(forResource: "zhuyin", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        else { return [:] }
        return raw.mapValues { $0.map(String.init) }
    }()

    /// 聯想詞：某字之後常接的字詞（只存後半段）
    static let assocDict: [String: [String]] = {
        guard let url = Bundle.main.url(forResource: "assoc", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        else { return [:] }
        return raw.mapValues { $0.split(separator: " ").map(String.init) }
    }()

    /// 簡體輸出：字庫照樣用繁體查，送出和顯示時才轉成簡體（用系統內建的 ICU 轉換）
    static var simplified: Bool {
        get { UserDefaults.standard.bool(forKey: "outputSimplified") }
        set { UserDefaults.standard.set(newValue, forKey: "outputSimplified") }
    }

    static func out(_ s: String) -> String {
        guard simplified else { return s }
        return s.applyingTransform(StringTransform("Hant-Hans"), reverse: false) ?? s
    }

    /// 簡體模式下，轉換後相同的字只留第一個（例如「後」「后」都變成「后」）
    static func dedupeForOutput(_ list: [String]) -> [String] {
        guard simplified else { return list }
        var seen = Set<String>()
        return list.filter { seen.insert(out($0)).inserted }
    }

    static func associations(after text: String) -> [String]? {
        guard let last = text.last, let list = assocDict[String(last)], !list.isEmpty else { return nil }
        return list
    }

    enum Result {
        case consumed           // 吃掉這個鍵，只更新畫面
        case commit(String)     // 送出文字
        case beep               // 錯誤，嗶一聲
        case pass               // 交給 App 自己處理
        case commitThenPass(String)   // 先送出文字，再把這個鍵交給 App（例如選字中按 Tab）
    }

    var ini = "", med = "", fin = ""
    var candidates: [String]? = nil
    var page = 0
    var reading = ""
    var isSymbols = false

    var composing: String { ini + med + fin }
    var isActive: Bool { !composing.isEmpty || candidates != nil }
    var display: String { candidates != nil ? reading : composing }
    var pageCount: Int { candidates.map { ($0.count + Engine.perPage - 1) / Engine.perPage } ?? 0 }
    var pageItems: [String] {
        guard let c = candidates else { return [] }
        let s = page * Engine.perPage
        return Array(c[s..<min(s + Engine.perPage, c.count)])
    }

    func reset() { ini = ""; med = ""; fin = ""; candidates = nil; page = 0; reading = ""; isSymbols = false }

    func openSymbols() { reset(); candidates = Engine.symbols; isSymbols = true }

    func pick(_ index: Int) -> Result {
        guard let c = candidates, index >= 0, index < c.count else { return .beep }
        let ch = c[index]
        reset()
        return .commit(ch)
    }

    func pickOnPage(_ i: Int) -> Result { pick(page * Engine.perPage + i) }

    /// 直接送出英文字母（Shift+字母）：選字窗開著就先送第一個字；正在拼注音就嗶一聲
    func literal(_ s: String, fullWidth: Bool) -> Result {
        let text = fullWidth ? Engine.fullWidth(s) : s
        if candidates != nil {
            if isSymbols { reset(); return .commit(text) }
            guard case .commit(let first) = pickOnPage(0) else { return .beep }
            return .commit(first + text)
        }
        if !composing.isEmpty { return .beep }
        return .commit(text)
    }

    private func setSlot(_ b: String) {
        if Engine.medials.contains(b) { med = b } else if Engine.finals.contains(b) { fin = b } else { ini = b }
    }

    static func fullWidth(_ s: String) -> String {
        String(String.UnicodeScalarView(s.unicodeScalars.map { u in
            if u.value == 0x20 { return Unicode.Scalar(0x3000)! }
            if (0x21...0x7E).contains(u.value) { return Unicode.Scalar(u.value + 0xFEE0)! }
            return u
        }))
    }

    /// key：單一字元（含空白），或 Backspace / Escape / Enter / Tab / Up / Down / Left / Right / PageUp / PageDown
    func handle(_ key: String, fullWidth: Bool) -> Result {
        if candidates != nil {
            if key.count == 1, let d = Int(key), d >= 1 { return pickOnPage(d - 1) }
            switch key {
            case " ", "Down", "PageDown", "Right":
                page = (page + 1) % pageCount; return .consumed
            case "Up", "PageUp", "Left":
                page = (page - 1 + pageCount) % pageCount; return .consumed
            case "Enter": return pickOnPage(0)
            case "Escape": reset(); return .consumed
            case "Backspace": candidates = nil; page = 0; return .consumed
            default:
                // 符號表開著時按別的鍵：關掉符號表，照常處理這個鍵，不要送出符號
                if isSymbols { reset(); return handle(key, fullWidth: fullWidth) }
                // 沒選字就繼續打：先送出第一個字，再照常處理這個鍵
                guard case .commit(let first) = pickOnPage(0) else { return .beep }
                switch handle(key, fullWidth: fullWidth) {
                case .commit(let more): return .commit(first + more)
                case .pass: return .commitThenPass(first)
                default: return .commit(first)
                }
            }
        }
        if !composing.isEmpty {
            if let b = Engine.keyMap[key] { setSlot(b); return .consumed }
            if let t = Engine.tones[key] {
                let r = composing + t
                guard let list = Engine.dict[r], !list.isEmpty else { return .beep }
                let shown = Engine.dedupeForOutput(list)
                if shown.count == 1 { reset(); return .commit(shown[0]) }
                candidates = shown; page = 0; reading = r
                return .consumed
            }
            switch key {
            case "Backspace":
                if !fin.isEmpty { fin = "" } else if !med.isEmpty { med = "" } else { ini = "" }
                return .consumed
            case "Escape": reset(); return .consumed
            default: return .beep
            }
        }
        if let b = Engine.keyMap[key] { setSlot(b); return .consumed }
        if key == "`" { openSymbols(); return .consumed }
        if key == " " { return .commit(fullWidth ? "\u{3000}" : " ") }
        if Engine.tones[key] != nil { return .beep }
        if let p = Engine.punct[key] { return .commit(p) }
        if key.count == 1 { return .commit(fullWidth ? Engine.fullWidth(key) : key) }
        return .pass
    }
}
