// 渲染一张 1200×630 的品牌封面图（标题卡）。用法：render-cover "<标题>" <输出.png>
import AppKit

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write("用法: render-cover <标题> <输出.png>\n".data(using: .utf8)!)
    exit(1)
}
let title = args[1]
let outPath = args[2]
let W = 1200, H = 630

guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
      let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
    FileHandle.standardError.write("无法创建画布\n".data(using: .utf8)!); exit(1)
}
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = ctx

// 背景：品牌酒红
NSColor(red: 0x9a/255.0, green: 0x3b/255.0, blue: 0x2f/255.0, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: W, height: H).fill()

// 左侧竖条装饰
NSColor(white: 1, alpha: 0.18).setFill()
NSRect(x: 64, y: 110, width: 6, height: CGFloat(H) - 220).fill()

let inset: CGFloat = 96
// 标题（自动换行，超长截断）
let para = NSMutableParagraphStyle()
para.lineSpacing = 10
para.lineBreakMode = .byTruncatingTail
let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 60, weight: .bold),
    .foregroundColor: NSColor.white,
    .paragraphStyle: para,
]
let textRect = NSRect(x: inset, y: 150, width: CGFloat(W) - inset - 80, height: CGFloat(H) - 280)
title.draw(in: textRect, withAttributes: titleAttrs)

// 底部水印
let mark: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 30, weight: .semibold),
    .foregroundColor: NSColor(white: 1, alpha: 0.9),
]
("CCVAR 简记" as NSString).draw(at: NSPoint(x: inset, y: 70), withAttributes: mark)

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("PNG 编码失败\n".data(using: .utf8)!); exit(1)
}
do {
    try png.write(to: URL(fileURLWithPath: outPath))
    print("OK \(outPath)")
} catch {
    FileHandle.standardError.write("写文件失败: \(error)\n".data(using: .utf8)!); exit(1)
}
