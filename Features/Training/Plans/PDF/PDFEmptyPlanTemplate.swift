import SwiftUI

struct PDFEmptyPlanPageView: View {
    let plan: TrainingPlan
    let pageRows: [PDFEmptyPlanTemplate.PDFRow]
    let pageIndex: Int
    let totalPages: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text(plan.name)
                    .font(.system(size: 32, weight: .bold))
                Text("Datum: ____________________  Dauer: _________")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 20)
            
            // Exercises Table
            VStack(spacing: 1) {
                // Table Header
                HStack(spacing: 1) {
                    tableCell("Übung", weight: .bold, width: 180, isHeader: true)
                    tableCell("Sätze x Wdh.", weight: .bold, width: 100, isHeader: true)
                    tableCell("Gewicht", weight: .bold, width: 100, isHeader: true)
                    tableCell("Notizen / Ist-Werte", weight: .bold, isHeader: true)
                }
                
                // Table Rows
                ForEach(Array(pageRows.enumerated()), id: \.offset) { _, row in
                    switch row {
                    case .supersetHeader:
                        HStack(spacing: 1) {
                            supersetHeaderCell("🔗 Supersatz")
                        }
                    case .exercise(let planEx, let isSuperset):
                        HStack(spacing: 1) {
                            let prefix = isSuperset ? "  ↳ " : ""
                            tableCell(prefix + (planEx.exercise?.name ?? "Unbekannt"), width: 180)
                            tableCell("\(planEx.targetSets) x \(planEx.targetReps)", width: 100)
                            tableCell("_______ kg", width: 100)
                            tableCell("")
                        }
                    }
                }
            }
            .background(Color.gray) // Creates the 1px grid lines
            .border(Color.gray, width: 1) // Outer border
            
            Spacer()
            
            // Page Number
            HStack {
                Spacer()
                Text("Seite \(pageIndex + 1) / \(totalPages)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(40)
        .frame(width: 595.2, height: 841.8, alignment: .top)
        .background(Color.white)
    }
    
    private func tableCell(_ text: String, weight: Font.Weight = .regular, width: CGFloat? = nil, isHeader: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 14, weight: weight))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 44) // Set explicitly
            .frame(width: width)
            .background(isHeader ? Color(white: 0.88) : Color.white)
    }

    private func supersetHeaderCell(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.black)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 24)
            .background(Color(white: 0.95))
    }
}

enum PDFEmptyPlanTemplate {
    enum PDFRow {
        case supersetHeader
        case exercise(PlanExercise, isSuperset: Bool)
    }
    
    static func generatePages(for plan: TrainingPlan) -> [AnyView] {
        let sorted = (plan.planExercises ?? []).sorted(by: { $0.sortOrder < $1.sortOrder })
        var rows: [PDFRow] = []
        var currentSupersetGroup: Int? = nil
        
        for ex in sorted {
            if let groupId = ex.supersetGroup {
                if currentSupersetGroup != groupId {
                    rows.append(.supersetHeader)
                    currentSupersetGroup = groupId
                }
                rows.append(.exercise(ex, isSuperset: true))
            } else {
                currentSupersetGroup = nil
                rows.append(.exercise(ex, isSuperset: false))
            }
        }
        
        let maxRowsPerPage = 13
        var chunks: [[PDFRow]] = []
        for i in stride(from: 0, to: rows.count, by: maxRowsPerPage) {
            let end = min(i + maxRowsPerPage, rows.count)
            chunks.append(Array(rows[i..<end]))
        }
        
        if chunks.isEmpty {
            return [AnyView(PDFEmptyPlanPageView(plan: plan, pageRows: [], pageIndex: 0, totalPages: 1))]
        }
        
        return chunks.enumerated().map { index, chunk in
            AnyView(PDFEmptyPlanPageView(plan: plan, pageRows: chunk, pageIndex: index, totalPages: chunks.count))
        }
    }
}
