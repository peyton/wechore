import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ToolError: Error, CustomStringConvertible {
    let description: String
}

func fail(_ message: String) throws -> Never {
    throw ToolError(description: message)
}

func parseHexColor(_ hex: String) throws -> CGColor {
    let trimmed = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    guard trimmed.count == 6, let value = UInt32(trimmed, radix: 16) else {
        try fail("Expected a six-digit RGB hex color, got \(hex)")
    }

    let red = CGFloat((value >> 16) & 0xff) / 255.0
    let green = CGFloat((value >> 8) & 0xff) / 255.0
    let blue = CGFloat(value & 0xff) / 255.0
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    return CGColor(colorSpace: colorSpace, components: [red, green, blue, 1.0])
        ?? CGColor(red: red, green: green, blue: blue, alpha: 1.0)
}

func drawRoundedLine(
    in context: CGContext,
    from start: CGPoint,
    to end: CGPoint,
    width: CGFloat,
    color: CGColor
) {
    context.setStrokeColor(color)
    context.setLineWidth(width)
    context.setLineCap(.round)
    context.move(to: start)
    context.addLine(to: end)
    context.strokePath()
}

func drawIcon(in context: CGContext, backgroundColor: CGColor) {
    let white = CGColor(red: 0.9725, green: 1.0, blue: 0.9765, alpha: 1.0)
    let black = CGColor(red: 0.0706, green: 0.0941, blue: 0.0784, alpha: 1.0)

    context.setFillColor(backgroundColor)
    context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))

    context.translateBy(x: 0, y: 1024)
    context.scaleBy(x: 1, y: -1)

    let bubble = CGMutablePath()
    bubble.move(to: CGPoint(x: 206, y: 332))
    bubble.addCurve(
        to: CGPoint(x: 354, y: 184),
        control1: CGPoint(x: 206, y: 250),
        control2: CGPoint(x: 272, y: 184)
    )
    bubble.addLine(to: CGPoint(x: 670, y: 184))
    bubble.addCurve(
        to: CGPoint(x: 818, y: 332),
        control1: CGPoint(x: 752, y: 184),
        control2: CGPoint(x: 818, y: 250)
    )
    bubble.addLine(to: CGPoint(x: 818, y: 530))
    bubble.addCurve(
        to: CGPoint(x: 670, y: 678),
        control1: CGPoint(x: 818, y: 612),
        control2: CGPoint(x: 752, y: 678)
    )
    bubble.addLine(to: CGPoint(x: 472, y: 678))
    bubble.addLine(to: CGPoint(x: 318, y: 806))
    bubble.addCurve(
        to: CGPoint(x: 266, y: 781),
        control1: CGPoint(x: 297, y: 823),
        control2: CGPoint(x: 266, y: 808)
    )
    bubble.addLine(to: CGPoint(x: 266, y: 662))
    bubble.addCurve(
        to: CGPoint(x: 206, y: 543),
        control1: CGPoint(x: 229, y: 635),
        control2: CGPoint(x: 206, y: 592)
    )
    bubble.closeSubpath()

    context.setFillColor(white)
    context.addPath(bubble)
    context.fillPath()

    drawRoundedLine(
        in: context,
        from: CGPoint(x: 342, y: 384),
        to: CGPoint(x: 682, y: 384),
        width: 58,
        color: black
    )
    drawRoundedLine(
        in: context,
        from: CGPoint(x: 342, y: 516),
        to: CGPoint(x: 562, y: 516),
        width: 58,
        color: black
    )

    context.setStrokeColor(backgroundColor)
    context.setLineWidth(62)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.move(to: CGPoint(x: 394, y: 628))
    context.addLine(to: CGPoint(x: 466, y: 700))
    context.addLine(to: CGPoint(x: 634, y: 516))
    context.strokePath()
}

func makeIcon(backgroundColor: CGColor) throws -> CGImage {
    let width = 1024
    let height = 1024
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    let bytesPerRow = width * 4
    var buffer = [UInt8](repeating: 0, count: bytesPerRow * height)
    let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue
        | CGImageAlphaInfo.noneSkipLast.rawValue

    guard let context = CGContext(
        data: &buffer,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else {
        try fail("Could not create RGB bitmap context")
    }

    context.interpolationQuality = .high
    drawIcon(in: context, backgroundColor: backgroundColor)

    guard let image = context.makeImage() else {
        try fail("Could not create app icon image")
    }

    return image
}

func run() throws {
    guard CommandLine.arguments.count == 3 else {
        try fail("Usage: generate_app_icon.swift <output.png> <background-rgb-hex>")
    }

    let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
    let backgroundColor = try parseHexColor(CommandLine.arguments[2])
    let image = try makeIcon(backgroundColor: backgroundColor)

    guard let destination = CGImageDestinationCreateWithURL(
        outputURL as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        try fail("Could not create image destination at \(outputURL.path)")
    }

    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        try fail("Could not write image at \(outputURL.path)")
    }
}

do {
    try run()
} catch {
    fputs("\(error)\n", stderr)
    exit(1)
}
