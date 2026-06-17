import AppKit

// 用 favicon 生成 macOS App 图标：1024 画布，内容居中占 ~824（留标准边距，像原生图标）
let args = CommandLine.arguments
guard args.count >= 3, let icon = NSImage(contentsOfFile: args[1]) else { print("usage: make_appicon <svg> <out.png>"); exit(1) }
let canvas: CGFloat = 1024, content: CGFloat = 824
let margin = (canvas - content) / 2
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(canvas), pixelsHigh: Int(canvas),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
icon.draw(in: NSRect(x: margin, y: margin, width: content, height: content))
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
print("wrote \(args[2])")
