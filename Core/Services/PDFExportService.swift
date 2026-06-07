import SwiftUI
import CoreGraphics

@MainActor
class PDFExportService {
    static let shared = PDFExportService()
    
    private init() {}
    
    func exportEmptyPlan(_ plan: TrainingPlan) -> URL? {
        let pages = PDFEmptyPlanTemplate.generatePages(for: plan)
        return renderPagesToPDF(pages: pages, filename: "Trainingsplan_\(plan.name).pdf")
    }
    
    func exportHistoricalPlan(plan: TrainingPlan, sessions: [WorkoutSession]) -> URL? {
        let a4Size = CGSize(width: 595.2, height: 841.8)
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("Historie_\(plan.name.replacingOccurrences(of: " ", with: "_")).pdf")
        
        var box = CGRect(origin: .zero, size: a4Size)
        guard let context = CGContext(fileURL as CFURL, mediaBox: &box, nil) else {
            return nil
        }
        
        let pages = PDFHistoricalPlanTemplate.generatePages(for: plan, sessions: sessions)
        
        for pageView in pages {
            context.beginPDFPage(nil)
            
            let renderer = ImageRenderer(content: pageView)
            renderer.proposedSize = .init(a4Size)
            
            renderer.render { size, renderContext in
                renderContext(context)
            }
            
            context.endPDFPage()
        }
        
        context.closePDF()
        
        return fileURL
    }
    
    func exportExerciseHistory(exercise: Exercise, sessions: [WorkoutSession]) -> URL? {
        let a4Size = CGSize(width: 595.2, height: 841.8)
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("Historie_\(exercise.name.replacingOccurrences(of: " ", with: "_")).pdf")
        
        var box = CGRect(origin: .zero, size: a4Size)
        guard let context = CGContext(fileURL as CFURL, mediaBox: &box, nil) else {
            return nil
        }
        
        let pages = PDFExerciseHistoryTemplate.generatePages(for: exercise, sessions: sessions)
        
        for pageView in pages {
            context.beginPDFPage(nil)
            
            let renderer = ImageRenderer(content: pageView)
            renderer.proposedSize = .init(a4Size)
            
            renderer.render { size, renderContext in
                renderContext(context)
            }
            
            context.endPDFPage()
        }
        
        context.closePDF()
        
        return fileURL
    }
    
    private func renderToPDF<V: View>(view: V, filename: String) -> URL? {
        let renderer = ImageRenderer(content: view)
        
        // Standard A4 width and height
        let a4Size = CGSize(width: 595.2, height: 841.8)
        
        // Allow the height to grow based on content
        renderer.proposedSize = .init(width: a4Size.width, height: nil)
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        
        renderer.render { size, context in
            var box = CGRect(origin: .zero, size: a4Size)
            
            guard let pdf = CGContext(fileURL as CFURL, mediaBox: &box, nil) else {
                return
            }
            
            let totalHeight = size.height
            let pageHeight = a4Size.height
            let numberOfPages = max(1, Int(ceil(totalHeight / pageHeight)))
            
            for page in 0..<numberOfPages {
                pdf.beginPDFPage(nil)
                pdf.saveGState()
                
                let yOffset = -(totalHeight - pageHeight - (CGFloat(page) * pageHeight))
                pdf.translateBy(x: 0, y: yOffset)
                
                context(pdf)
                
                pdf.restoreGState()
                pdf.endPDFPage()
            }
            pdf.closePDF()
        }
        
        return fileURL
    }
    
    private func renderPagesToPDF(pages: [AnyView], filename: String) -> URL? {
        guard let firstPage = pages.first else { return nil }
        
        let a4Size = CGSize(width: 595.2, height: 841.8)
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        
        let initialRenderer = ImageRenderer(content: firstPage)
        initialRenderer.proposedSize = .init(a4Size)
        
        initialRenderer.render { size, context in
            var box = CGRect(origin: .zero, size: a4Size)
            guard let pdf = CGContext(fileURL as CFURL, mediaBox: &box, nil) else { return }
            
            for pageView in pages {
                let pageRenderer = ImageRenderer(content: pageView)
                pageRenderer.proposedSize = .init(a4Size)
                
                pdf.beginPDFPage(nil)
                pageRenderer.render { _, pageContext in
                    pageContext(pdf)
                }
                pdf.endPDFPage()
            }
            pdf.closePDF()
        }
        
        return fileURL
    }
}
