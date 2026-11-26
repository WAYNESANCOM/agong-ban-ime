import Carbon
// 向系統登記並啟用、切換到 ㄅ半注音
let path = CommandLine.arguments[1]
let st = TISRegisterInputSource(URL(fileURLWithPath: path) as CFURL)
print("register:", st)
let filter = [kTISPropertyBundleID as String: "com.waynesan.inputmethod.BopomofoHalf"] as CFDictionary
guard let list = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource], !list.isEmpty else {
    print("NOT_FOUND"); exit(1)
}
for s in list {
    let id = Unmanaged<CFString>.fromOpaque(TISGetInputSourceProperty(s, kTISPropertyInputSourceID)).takeUnretainedValue() as String
    let enable = TISEnableInputSource(s)
    print(id, "enable:", enable)
    if id.hasSuffix(".Bopomofo") { print("select:", TISSelectInputSource(s)) }
}
