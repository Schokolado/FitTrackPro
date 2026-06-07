import Cocoa
import Foundation

let brandColor = NSColor(calibratedRed: 0.24, green: 0.33, blue: 0.83, alpha: 1.0)
let brandLight = brandColor.withAlphaComponent(0.2)

func generateLogo(scale: CGFloat, filename: String) {
    let pointSize = CGSize(width: 120, height: 120)
    let size = CGSize(width: pointSize.width * scale, height: pointSize.height * scale)
    let image = NSImage(size: size)
    
    image.lockFocus()
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: scale, y: scale)
    
    // Outer circle (120x120)
    let outerRect = NSRect(x: 0, y: 0, width: 120, height: 120)
    let outerPath = NSBezierPath(ovalIn: outerRect)
    brandLight.setFill()
    outerPath.fill()
    
    // Inner circle (90x90)
    let innerRect = NSRect(x: 15, y: 15, width: 90, height: 90)
    let innerPath = NSBezierPath(ovalIn: innerRect)
    brandColor.setFill()
    innerPath.fill()
    
    // Dumbbell
    if let dumbbell = NSImage(systemSymbolName: "dumbbell.fill", accessibilityDescription: nil) {
        let config = NSImage.SymbolConfiguration(pointSize: 45, weight: .regular)
        let configuredDumbbell = dumbbell.withSymbolConfiguration(config)!
        
        let iconSize = configuredDumbbell.size
        let x = (120 - iconSize.width) / 2
        let y = (120 - iconSize.height) / 2
        
        configuredDumbbell.lockFocus()
        NSColor.white.set()
        let imageRect = NSRect(origin: .zero, size: iconSize)
        imageRect.fill(using: .sourceAtop)
        configuredDumbbell.unlockFocus()
        
        configuredDumbbell.draw(in: NSRect(origin: CGPoint(x: x, y: y), size: iconSize))
    }
    
    image.unlockFocus()
    
    if let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) {
        let pngData = bitmap.representation(using: .png, properties: [:])
        let fm = FileManager.default
        let folder = "Resources/Assets.xcassets/LaunchLogoV3.imageset"
        try? fm.createDirectory(atPath: folder, withIntermediateDirectories: true, attributes: nil)
        
        let url = URL(fileURLWithPath: "\(folder)/\(filename)")
        try? pngData?.write(to: url)
        print("Generated \(filename)")
    }
}

generateLogo(scale: 1, filename: "LaunchLogoV3.png")
generateLogo(scale: 2, filename: "LaunchLogoV3@2x.png")
generateLogo(scale: 3, filename: "LaunchLogoV3@3x.png")

// Write Contents.json
let contentsJSON = """
{
  "images" : [
    {
      "filename" : "LaunchLogoV3.png",
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "filename" : "LaunchLogoV3@2x.png",
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "filename" : "LaunchLogoV3@3x.png",
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""
let folder = "Resources/Assets.xcassets/LaunchLogoV3.imageset"
try? contentsJSON.write(to: URL(fileURLWithPath: "\(folder)/Contents.json"), atomically: true, encoding: .utf8)
