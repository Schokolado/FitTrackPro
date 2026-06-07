import SwiftUI
import CoreGraphics
import Foundation

@MainActor
func testPDF() {
    let view = VStack(spacing: 0) {
        Rectangle().fill(Color.red).frame(height: 841.8).overlay(Text("Page 1").font(.largeTitle))
        Rectangle().fill(Color.blue).frame(height: 841.8).overlay(Text("Page 2").font(.largeTitle))
        Rectangle().fill(Color.green).frame(height: 841.8).overlay(Text("Page 3").font(.largeTitle))
    }
    
    let renderer = ImageRenderer(content: view)
    let a4Size = CGSize(width: 595.2, height: 841.8)
    renderer.proposedSize = .init(width: a4Size.width, height: nil)
    
    let fileURL = URL(fileURLWithPath: "test_pagination.pdf")
    
    renderer.render { size, context in
        var box = CGRect(origin: .zero, size: a4Size)
        guard let pdf = CGContext(fileURL as CFURL, mediaBox: &box, nil) else { return }
        
        let totalHeight = size.height
        let pageHeight = a4Size.height
        let numberOfPages = Int(ceil(totalHeight / pageHeight))
        
        for page in 0..<numberOfPages {
            pdf.beginPDFPage(nil)
            pdf.saveGState()
            
            // Calculate offset to show the correct part of the view.
            // Since context origin is bottom-left, y=0 shows the bottom of the view.
            // To show the top, we need to shift the drawing down by (totalHeight - pageHeight)
            let yOffset = -(totalHeight - pageHeight - (CGFloat(page) * pageHeight))
            pdf.translateBy(x: 0, y: yOffset)
            
            context(pdf)
            
            pdf.restoreGState()
            pdf.endPDFPage()
        }
        pdf.closePDF()
        print("Generated PDF at \(fileURL.path) with \(numberOfPages) pages. Total height: \(totalHeight)")
    }
}

Task {
    await testPDF()
    exit(0)
}
RunLoop.main.run()
