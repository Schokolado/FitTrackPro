import Cocoa
import Foundation

let brandColor = NSColor(calibratedRed: 0.24, green: 0.33, blue: 0.83, alpha: 1.0)
let brandLight = brandColor.withAlphaComponent(0.2)
let launchBackground = NSColor(calibratedRed: 0.949, green: 0.949, blue: 0.969, alpha: 1.0)

func generateAppIcon(width: CGFloat, filename: String) {
    let size = CGSize(width: width, height: width)
    let image = NSImage(size: size)
    
    image.lockFocus()
    
    // Fill entire background with LaunchBackground color (for squircle corners)
    launchBackground.setFill()
    NSRect(origin: .zero, size: size).fill()
    
    // Outer circle (light blue, full bounds)
    brandLight.setFill()
    NSRect(origin: .zero, size: size).fill()
    
    // Inner circle (dark blue) - 75%
    let innerSize: CGFloat = width * 0.75
    let innerRect = NSRect(x: (width - innerSize) / 2, y: (width - innerSize) / 2, width: innerSize, height: innerSize)
    let innerPath = NSBezierPath(ovalIn: innerRect)
    brandColor.setFill()
    innerPath.fill()
    
    // Dumbbell (white) - 37.5%
    if let dumbbell = NSImage(systemSymbolName: "dumbbell.fill", accessibilityDescription: nil) {
        let config = NSImage.SymbolConfiguration(pointSize: width * 0.375, weight: .regular)
        let configuredDumbbell = dumbbell.withSymbolConfiguration(config)!
        
        let iconSize = configuredDumbbell.size
        let x = (width - iconSize.width) / 2
        let y = (width - iconSize.height) / 2
        
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
        let folder = "Resources/Assets.xcassets/AppIcon.appiconset"
        try? fm.createDirectory(atPath: folder, withIntermediateDirectories: true, attributes: nil)
        
        let url = URL(fileURLWithPath: "\(folder)/\(filename)")
        try? pngData?.write(to: url)
        print("Generated \(filename)")
    }
}

generateAppIcon(width: 120, filename: "Icon-120.png")
generateAppIcon(width: 180, filename: "Icon-180.png")
generateAppIcon(width: 1024, filename: "Icon-1024.png")

// Write Contents.json for iPhone sizes and 1024
let contentsJSON = """
{
  "images" : [
    {
      "filename" : "Icon-120.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "60x60"
    },
    {
      "filename" : "Icon-180.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "60x60"
    },
    {
      "filename" : "Icon-1024.png",
      "idiom" : "ios-marketing",
      "scale" : "1x",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""
let folder = "Resources/Assets.xcassets/AppIcon.appiconset"
try? contentsJSON.write(to: URL(fileURLWithPath: "\(folder)/Contents.json"), atomically: true, encoding: .utf8)
