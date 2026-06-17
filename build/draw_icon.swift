import AppKit

// 画一个 1024x1024 的 App 图标：橙色渐变圆角底 + 白色「文稿」卡片
func makeIcon(_ px: Int) -> Data {
    let size = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let g = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = g
    let ctx = g.cgContext

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let corner = size * 0.225
    let bg = CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)

    // 渐变橙色背景
    ctx.saveGState()
    ctx.addPath(bg); ctx.clip()
    let cs = CGColorSpaceCreateDeviceRGB()
    let colors = [CGColor(srgbRed: 1.00, green: 0.55, blue: 0.28, alpha: 1),
                  CGColor(srgbRed: 0.95, green: 0.31, blue: 0.11, alpha: 1)] as CFArray
    let grad = CGGradient(colorsSpace: cs, colors: colors, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: size),
                           end: CGPoint(x: size, y: 0), options: [])
    ctx.restoreGState()

    // 白色文稿卡片（带柔和阴影）
    let pw = size * 0.46, ph = size * 0.58
    let px0 = (size - pw)/2, py0 = (size - ph)/2
    let pageRect = CGRect(x: px0, y: py0, width: pw, height: ph)
    let pageCorner = size * 0.04
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -size*0.010), blur: size*0.035,
                  color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.22))
    ctx.addPath(CGPath(roundedRect: pageRect, cornerWidth: pageCorner, cornerHeight: pageCorner, transform: nil))
    ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()

    // 文稿里的文字行
    func bar(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: CGColor) {
        ctx.addPath(CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h),
                           cornerWidth: h/2, cornerHeight: h/2, transform: nil))
        ctx.setFillColor(c); ctx.fillPath()
    }
    let inset = pw * 0.17
    let lineX = px0 + inset
    let lineW = pw - inset*2
    let lineH = size * 0.026
    let gap = size * 0.050
    var y = py0 + ph - inset*1.2 - lineH*1.6
    bar(lineX, y, lineW*0.62, lineH*1.5, CGColor(srgbRed: 0.97, green: 0.42, blue: 0.18, alpha: 1)) // 标题（橙）
    y -= gap*1.5
    let gray = CGColor(srgbRed: 0.80, green: 0.80, blue: 0.83, alpha: 1)
    for i in 0..<4 {
        bar(lineX, y, (i == 3 ? lineW*0.5 : lineW), lineH, gray)
        y -= gap
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_src.png"
try! makeIcon(1024).write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
