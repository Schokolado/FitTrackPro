import SwiftUI
import Charts

struct PDFHistoricalPlanPageView: View {
    let plan: TrainingPlan
    let sessions: [WorkoutSession]
    let pageSessions: [WorkoutSession]
    let pageIndex: Int
    let totalPages: Int
    let showCharts: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Historie: \(plan.name)")
                    .font(.system(size: 32, weight: .bold))
                Text("Absolvierte Workouts: \(sessions.count)")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, showCharts ? 0 : 20)
            
            if showCharts {
                VStack(spacing: 16) {
                    // Volumen
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Volumen (kg)").font(.caption).bold()
                        if sessions.isEmpty {
                            Chart {}.frame(height: 80).chartYScale(domain: 0...1000)
                        } else {
                            Chart {
                                ForEach(sessions.sorted(by: { $0.startTime < $1.startTime })) { session in
                                    LineMark(x: .value("Datum", session.startTime), y: .value("Volumen", calculateVolume(for: session)))
                                    .symbol(Circle())
                                    .foregroundStyle(Color.blue)
                                }
                            }
                            .frame(height: 80)
                        }
                    }
                    

                    // Reps
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Wiederholungen").font(.caption).bold()
                        if sessions.isEmpty {
                            Chart {}.frame(height: 80).chartYScale(domain: 0...50)
                        } else {
                            Chart {
                                ForEach(sessions.sorted(by: { $0.startTime < $1.startTime })) { session in
                                    LineMark(x: .value("Datum", session.startTime), y: .value("Reps", Double(calculateTotalReps(for: session))))
                                    .foregroundStyle(Color.purple)
                                    .symbol(Circle())
                                }
                            }
                            .frame(height: 80)
                        }
                    }
                }
                .padding(.bottom, 10)
            }
            
            // Table
            VStack(spacing: 1) {
                HStack(spacing: 1) {
                    tableCell("Datum", weight: .bold, width: 100, isHeader: true)
                    tableCell("Dauer", weight: .bold, width: 50, isHeader: true)
                    tableCell("Vol.", weight: .bold, width: 60, isHeader: true)
                    tableCell("Reps", weight: .bold, width: 40, isHeader: true)
                    tableCell("Intensität", weight: .bold, width: 60, isHeader: true)
                    tableCell("Stimmung", weight: .bold, width: 60, isHeader: true)
                    tableCell("Notizen", weight: .bold, isHeader: true)
                }
                
                if pageSessions.isEmpty {
                    HStack(spacing: 1) {
                        tableCell("Noch keine Daten", width: 100)
                        tableCell("-", width: 50)
                        tableCell("-", width: 60)
                        tableCell("-", width: 40)
                        tableCell("-", width: 60)
                        tableCell("-", width: 60)
                        tableCell("-")
                    }
                } else {
                    ForEach(pageSessions) { session in
                        HStack(spacing: 1) {
                            tableCell(session.startTime.formatted(date: .abbreviated, time: .shortened), width: 100)
                            tableCell(formatDuration(calculateDuration(for: session)), width: 50)
                            tableCell(String(format: "%.0f", calculateVolume(for: session)), width: 60)
                            tableCell("\(calculateTotalReps(for: session))", width: 40)
                            
                            let intensity = session.intensityRating.map { "\($0)" } ?? "-"
                            let mood = session.moodRating.map { "\($0)" } ?? "-"
                            tableCell(intensity, width: 60)
                            tableCell(mood, width: 60)
                            
                            tableCell(session.notes)
                        }
                    }
                }
            }
            .background(Color.gray)
            .border(Color.gray, width: 1)
            
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
    
    private func calculateVolume(for session: WorkoutSession) -> Double {
        (session.sets ?? []).filter { $0.isCompleted }.reduce(0) { $0 + ($1.actualWeight * Double($1.actualReps)) }
    }
    
    private func calculateDuration(for session: WorkoutSession) -> TimeInterval {
        (session.endTime ?? Date()).timeIntervalSince(session.startTime)
    }
    
    private func calculateMaxWeight(for session: WorkoutSession) -> Double {
        let weights = (session.sets ?? []).filter { $0.isCompleted }.map { $0.actualWeight }
        return weights.max() ?? 0
    }
    
    private func calculateAverageWeight(for session: WorkoutSession) -> Double {
        let completedSets = (session.sets ?? []).filter { $0.isCompleted }
        guard !completedSets.isEmpty else { return 0 }
        let totalWeight = completedSets.reduce(0.0) { $0 + $1.actualWeight }
        return totalWeight / Double(completedSets.count)
    }
    
    private func calculateTotalReps(for session: WorkoutSession) -> Int {
        (session.sets ?? []).filter { $0.isCompleted }.reduce(0) { $0 + $1.actualReps }
    }
    
    private func tableCell(_ text: String, weight: Font.Weight = .regular, width: CGFloat? = nil, isHeader: Bool = false) -> some View {
        Text(text)
            .font(.system(size: isHeader ? 11 : 12, weight: weight))
            .lineLimit(isHeader ? 1 : nil)
            .minimumScaleFactor(0.5)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 36)
            .frame(width: width)
            .background(isHeader ? Color(white: 0.88) : Color.white)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? ""
    }
}

enum PDFHistoricalPlanTemplate {
    static func generatePages(for plan: TrainingPlan, sessions: [WorkoutSession]) -> [AnyView] {
        let sortedSessions = sessions.sorted(by: { $0.startTime > $1.startTime })
        
        let firstPageMaxRows = 8
        let subsequentPageMaxRows = 17
        
        var chunks: [[WorkoutSession]] = []
        var remaining = sortedSessions
        
        if remaining.count > firstPageMaxRows {
            chunks.append(Array(remaining.prefix(firstPageMaxRows)))
            remaining = Array(remaining.dropFirst(firstPageMaxRows))
            
            while !remaining.isEmpty {
                let take = min(remaining.count, subsequentPageMaxRows)
                chunks.append(Array(remaining.prefix(take)))
                remaining = Array(remaining.dropFirst(take))
            }
        } else {
            chunks.append(remaining)
        }
        
        if chunks.isEmpty {
            return [AnyView(PDFHistoricalPlanPageView(plan: plan, sessions: sessions, pageSessions: [], pageIndex: 0, totalPages: 1, showCharts: true))]
        }
        
        return chunks.enumerated().map { index, chunk in
            AnyView(PDFHistoricalPlanPageView(plan: plan, sessions: sessions, pageSessions: chunk, pageIndex: index, totalPages: chunks.count, showCharts: index == 0))
        }
    }
}

struct PDFExerciseHistoryPageView: View {
    let exercise: Exercise
    let sessions: [WorkoutSession]
    let pageSessions: [WorkoutSession]
    let pageIndex: Int
    let totalPages: Int
    let showCharts: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Übungs-Historie: \(exercise.name)")
                    .font(.system(size: 32, weight: .bold))
                Text("Absolvierte Workouts: \(sessions.count)")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, showCharts ? 0 : 20)
            
            if showCharts {
                VStack(spacing: 16) {
                    // Volumen
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Volumen (kg)").font(.caption).bold()
                        if sessions.isEmpty {
                            Chart {}.frame(height: 80).chartYScale(domain: 0...1000)
                        } else {
                            Chart {
                                ForEach(sessions.sorted(by: { $0.startTime < $1.startTime })) { session in
                                    LineMark(x: .value("Datum", session.startTime), y: .value("Volumen", calculateVolume(for: session)))
                                    .symbol(Circle())
                                    .foregroundStyle(Color.blue)
                                }
                            }
                            .frame(height: 80)
                        }
                    }
                    
                    // Gewicht
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Max Gewicht & Ø Gewicht").font(.caption).bold()
                        if sessions.isEmpty {
                            Chart {}.frame(height: 80).chartYScale(domain: 0...100)
                        } else {
                            Chart {
                                ForEach(sessions.sorted(by: { $0.startTime < $1.startTime })) { session in
                                    LineMark(x: .value("Datum", session.startTime), y: .value("Max", calculateMaxWeight(for: session)))
                                    .foregroundStyle(Color.green)
                                    .symbol(Circle())
                                    
                                    LineMark(x: .value("Datum", session.startTime), y: .value("Ø", calculateAverageWeight(for: session)))
                                    .foregroundStyle(Color.orange)
                                    .symbol(Circle())
                                }
                            }
                            .frame(height: 80)
                            .chartLegend(position: .trailing)
                        }
                    }
                    
                    // Reps
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Wiederholungen").font(.caption).bold()
                        if sessions.isEmpty {
                            Chart {}.frame(height: 80).chartYScale(domain: 0...50)
                        } else {
                            Chart {
                                ForEach(sessions.sorted(by: { $0.startTime < $1.startTime })) { session in
                                    LineMark(x: .value("Datum", session.startTime), y: .value("Reps", Double(calculateTotalReps(for: session))))
                                    .foregroundStyle(Color.purple)
                                    .symbol(Circle())
                                }
                            }
                            .frame(height: 80)
                        }
                    }
                }
                .padding(.bottom, 10)
            }
            
            // Table
            VStack(spacing: 1) {
                HStack(spacing: 1) {
                    tableCell("Datum", weight: .bold, width: 100, isHeader: true)
                    tableCell("Volumen", weight: .bold, width: 80, isHeader: true)
                    tableCell("Max Gew.", weight: .bold, width: 80, isHeader: true)
                    tableCell("Ø Gew.", weight: .bold, width: 80, isHeader: true)
                    tableCell("Reps", weight: .bold, width: 60, isHeader: true)
                }
                
                if pageSessions.isEmpty {
                    HStack(spacing: 1) {
                        tableCell("Noch keine Daten", width: 100)
                        tableCell("-", width: 80)
                        tableCell("-", width: 80)
                        tableCell("-", width: 80)
                        tableCell("-", width: 60)
                    }
                } else {
                    ForEach(pageSessions) { session in
                        HStack(spacing: 1) {
                            tableCell(session.startTime.formatted(date: .abbreviated, time: .shortened), width: 100)
                            tableCell(String(format: "%.0f", calculateVolume(for: session)), width: 80)
                            tableCell(String(format: "%.1f", calculateMaxWeight(for: session)), width: 80)
                            tableCell(String(format: "%.1f", calculateAverageWeight(for: session)), width: 80)
                            tableCell("\(calculateTotalReps(for: session))", width: 60)
                        }
                    }
                }
            }
            .background(Color.gray)
            .border(Color.gray, width: 1)
            
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
    
    private func sets(for session: WorkoutSession) -> [WorkoutSet] {
        (session.sets ?? []).filter { $0.isCompleted && $0.exercise?.id == exercise.id }
    }
    
    private func calculateVolume(for session: WorkoutSession) -> Double {
        sets(for: session).reduce(0) { $0 + ($1.actualWeight * Double($1.actualReps)) }
    }
    
    private func calculateMaxWeight(for session: WorkoutSession) -> Double {
        let weights = sets(for: session).map { $0.actualWeight }
        return weights.max() ?? 0
    }
    
    private func calculateAverageWeight(for session: WorkoutSession) -> Double {
        let completedSets = sets(for: session)
        guard !completedSets.isEmpty else { return 0 }
        let totalWeight = completedSets.reduce(0.0) { $0 + $1.actualWeight }
        return totalWeight / Double(completedSets.count)
    }
    
    private func calculateTotalReps(for session: WorkoutSession) -> Int {
        sets(for: session).reduce(0) { $0 + $1.actualReps }
    }
    
    private func tableCell(_ text: String, weight: Font.Weight = .regular, width: CGFloat? = nil, isHeader: Bool = false) -> some View {
        Text(text)
            .font(.system(size: isHeader ? 11 : 12, weight: weight))
            .lineLimit(isHeader ? 1 : nil)
            .minimumScaleFactor(0.5)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 36)
            .frame(width: width)
            .background(isHeader ? Color(white: 0.88) : Color.white)
    }
}

enum PDFExerciseHistoryTemplate {
    static func generatePages(for exercise: Exercise, sessions: [WorkoutSession]) -> [AnyView] {
        let sortedSessions = sessions.sorted(by: { $0.startTime > $1.startTime })
        
        let firstPageMaxRows = 8
        let subsequentPageMaxRows = 17
        
        var chunks: [[WorkoutSession]] = []
        var remaining = sortedSessions
        
        if remaining.count > firstPageMaxRows {
            chunks.append(Array(remaining.prefix(firstPageMaxRows)))
            remaining = Array(remaining.dropFirst(firstPageMaxRows))
            
            while !remaining.isEmpty {
                let take = min(remaining.count, subsequentPageMaxRows)
                chunks.append(Array(remaining.prefix(take)))
                remaining = Array(remaining.dropFirst(take))
            }
        } else {
            chunks.append(remaining)
        }
        
        if chunks.isEmpty {
            return [AnyView(PDFExerciseHistoryPageView(exercise: exercise, sessions: sessions, pageSessions: [], pageIndex: 0, totalPages: 1, showCharts: true))]
        }
        
        return chunks.enumerated().map { index, chunk in
            AnyView(PDFExerciseHistoryPageView(exercise: exercise, sessions: sessions, pageSessions: chunk, pageIndex: index, totalPages: chunks.count, showCharts: index == 0))
        }
    }
}
