import Cocoa
// 產生選單列用的「ㄅ」圖示（黑字透明底，系統當 template 上色）
let out = CommandLine.arguments[1]
func rep(_ px: Int) -> NSBitmapImageRep {
    let r = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    r.size = NSSize(width: 16, height: 16)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: r)
    let p = NSBezierPath(roundedRect: NSRect(x: 0.5, y: 0.5, width: 15, height: 15), xRadius: 2, yRadius: 2)
    NSColor.black.setStroke(); p.lineWidth = 1; p.stroke()
    let f = NSFont(name: "STSongti-TC-Bold", size: 12) ?? NSFont.boldSystemFont(ofSize: 12)
    let s = NSAttributedString(string: "ㄅ", attributes: [.font: f, .foregroundColor: NSColor.black])
    let sz = s.size()
    s.draw(at: NSPoint(x: (16 - sz.width) / 2, y: (16 - sz.height) / 2))
    NSGraphicsContext.restoreGraphicsState()
    return r
}
let img = NSImage(size: NSSize(width: 16, height: 16))
img.addRepresentation(rep(16)); img.addRepresentation(rep(32))
try! img.tiffRepresentation!.write(to: URL(fileURLWithPath: out))
