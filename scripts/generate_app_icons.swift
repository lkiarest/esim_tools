import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct IconTarget {
    let path: String
    let size: Int
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

let targets: [IconTarget] = [
    IconTarget(path: "android/app/src/main/res/mipmap-mdpi/ic_launcher.png", size: 48),
    IconTarget(path: "android/app/src/main/res/mipmap-hdpi/ic_launcher.png", size: 72),
    IconTarget(path: "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png", size: 96),
    IconTarget(path: "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png", size: 144),
    IconTarget(path: "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png", size: 192),
    IconTarget(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png", size: 20),
    IconTarget(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png", size: 40),
    IconTarget(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png", size: 60),
    IconTarget(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png", size: 29),
    IconTarget(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png", size: 58),
    IconTarget(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png", size: 87),
    IconTarget(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png", size: 40),
    IconTarget(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png", size: 80),
    IconTarget(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png", size: 120),
    IconTarget(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png", size: 120),
    IconTarget(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png", size: 180),
    IconTarget(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png", size: 76),
    IconTarget(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png", size: 152),
    IconTarget(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png", size: 167),
    IconTarget(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png", size: 1024),
    IconTarget(path: "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png", size: 16),
    IconTarget(path: "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png", size: 32),
    IconTarget(path: "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png", size: 64),
    IconTarget(path: "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png", size: 128),
    IconTarget(path: "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png", size: 256),
    IconTarget(path: "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png", size: 512),
    IconTarget(path: "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png", size: 1024),
    IconTarget(path: "web/favicon.png", size: 64),
    IconTarget(path: "web/icons/Icon-192.png", size: 192),
    IconTarget(path: "web/icons/Icon-maskable-192.png", size: 192),
    IconTarget(path: "web/icons/Icon-512.png", size: 512),
    IconTarget(path: "web/icons/Icon-maskable-512.png", size: 512),
]

func drawIcon(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let context = NSGraphicsContext.current?.cgContext else {
        fatalError("No drawing context")
    }
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    let scale = CGFloat(size) / 1024.0
    func s(_ value: CGFloat) -> CGFloat { value * scale }

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            NSColor(red: 0.03, green: 0.16, blue: 0.55, alpha: 1).cgColor,
            NSColor(red: 0.03, green: 0.44, blue: 0.95, alpha: 1).cgColor,
            NSColor(red: 0.02, green: 0.78, blue: 0.84, alpha: 1).cgColor,
        ] as CFArray,
        locations: [0.0, 0.62, 1.0]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: size),
        end: CGPoint(x: size, y: 0),
        options: []
    )

    context.setFillColor(NSColor.white.withAlphaComponent(0.12).cgColor)
    context.fillEllipse(in: CGRect(x: s(660), y: s(660), width: s(390), height: s(390)))
    context.setFillColor(NSColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 0.12).cgColor)
    context.fillEllipse(in: CGRect(x: s(-120), y: s(-80), width: s(480), height: s(480)))

    context.saveGState()
    context.translateBy(x: s(78), y: s(50))
    context.rotate(by: -0.10)

    let card = CGRect(x: s(205), y: s(210), width: s(610), height: s(610))
    let shadow = CGPath(roundedRect: card.offsetBy(dx: s(0), dy: s(-22)), cornerWidth: s(122), cornerHeight: s(122), transform: nil)
    context.addPath(shadow)
    context.setFillColor(NSColor.black.withAlphaComponent(0.22).cgColor)
    context.fillPath()

    let cardPath = CGPath(roundedRect: card, cornerWidth: s(122), cornerHeight: s(122), transform: nil)
    context.addPath(cardPath)
    context.setFillColor(NSColor.white.withAlphaComponent(0.96).cgColor)
    context.fillPath()

    let notch = CGRect(x: s(565), y: s(210), width: s(250), height: s(250))
    context.addPath(CGPath(ellipseIn: notch, transform: nil))
    context.setFillColor(NSColor(red: 0.07, green: 0.39, blue: 0.95, alpha: 0.16).cgColor)
    context.fillPath()

    let chip = CGRect(x: s(332), y: s(365), width: s(328), height: s(292))
    context.addPath(CGPath(roundedRect: chip, cornerWidth: s(56), cornerHeight: s(56), transform: nil))
    context.setFillColor(NSColor(red: 0.03, green: 0.26, blue: 0.70, alpha: 1).cgColor)
    context.fillPath()

    context.setStrokeColor(NSColor(red: 0.63, green: 0.96, blue: 1.0, alpha: 1).cgColor)
    context.setLineWidth(s(20))
    context.setLineCap(.round)
    for x in [s(386), s(496), s(606)] {
        context.move(to: CGPoint(x: x, y: s(408)))
        context.addLine(to: CGPoint(x: x, y: s(612)))
    }
    for y in [s(438), s(512), s(586)] {
        context.move(to: CGPoint(x: s(370), y: y))
        context.addLine(to: CGPoint(x: s(622), y: y))
    }
    context.strokePath()

    context.setStrokeColor(NSColor(red: 0.0, green: 0.78, blue: 0.90, alpha: 1).cgColor)
    context.setLineWidth(s(32))
    context.move(to: CGPoint(x: s(670), y: s(520)))
    context.addCurve(to: CGPoint(x: s(750), y: s(610)), control1: CGPoint(x: s(708), y: s(542)), control2: CGPoint(x: s(736), y: s(572)))
    context.strokePath()
    context.setStrokeColor(NSColor(red: 0.0, green: 0.78, blue: 0.90, alpha: 0.62).cgColor)
    context.setLineWidth(s(28))
    context.move(to: CGPoint(x: s(685), y: s(440)))
    context.addCurve(to: CGPoint(x: s(815), y: s(640)), control1: CGPoint(x: s(760), y: s(470)), control2: CGPoint(x: s(800), y: s(550)))
    context.strokePath()

    context.setFillColor(NSColor(red: 0.0, green: 0.68, blue: 0.47, alpha: 1).cgColor)
    context.fillEllipse(in: CGRect(x: s(540), y: s(235), width: s(175), height: s(175)))
    context.setStrokeColor(NSColor.white.cgColor)
    context.setLineWidth(s(25))
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.move(to: CGPoint(x: s(584), y: s(322)))
    context.addLine(to: CGPoint(x: s(620), y: s(284)))
    context.addLine(to: CGPoint(x: s(675), y: s(352)))
    context.strokePath()

    context.restoreGState()
    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to url: URL) throws {
    let pixelWidth = Int(image.size.width)
    let pixelHeight = Int(image.size.height)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

    var buffer = Data(count: pixelWidth * pixelHeight * 4)
    buffer.withUnsafeMutableBytes { rawBuffer in
        guard
            let baseAddress = rawBuffer.baseAddress,
            let context = CGContext(
                data: baseAddress,
                width: pixelWidth,
                height: pixelHeight,
                bitsPerComponent: 8,
                bytesPerRow: pixelWidth * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ),
            let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            fatalError("Failed to create RGB drawing context")
        }

        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

        guard
            let output = context.makeImage(),
            let destination = CGImageDestinationCreateWithURL(
                url as CFURL,
                UTType.png.identifier as CFString,
                1,
                nil
            )
        else {
            fatalError("Failed to create PNG destination")
        }

        CGImageDestinationAddImage(destination, output, nil)
        if !CGImageDestinationFinalize(destination) {
            fatalError("Failed to write PNG")
        }
    }
}

for target in targets {
    let url = root.appendingPathComponent(target.path)
    try writePNG(drawIcon(size: target.size), to: url)
}

print("Generated \(targets.count) app icon files")
