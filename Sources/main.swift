import Cocoa
import Carbon
import InputMethodKit

// 安裝檔裝完會執行 `BopomofoHalf install`：向系統登記並啟用輸入法，然後結束
if CommandLine.arguments.dropFirst().first == "install" {
    TISRegisterInputSource(Bundle.main.bundleURL as CFURL)
    let filter = [kTISPropertyBundleID as String: Bundle.main.bundleIdentifier ?? ""] as CFDictionary
    let sources = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource] ?? []
    for s in sources { TISEnableInputSource(s) }
    print(sources.isEmpty ? "NOT_FOUND" : "INSTALLED")
    exit(sources.isEmpty ? 1 : 0)
}

let connectionName = Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String
    ?? "com.waynesan.inputmethod.BopomofoHalf.Connection"
let server = IMKServer(name: connectionName, bundleIdentifier: Bundle.main.bundleIdentifier)
_ = Engine.dict   // 先載入字庫
NSApplication.shared.run()
