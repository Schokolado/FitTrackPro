import SwiftUI
import Charts

struct PlanProgressView: View {
    let plan: TrainingPlan
    let allSessions: [WorkoutSession]
    let viewModel: StatisticsViewModel
    
    @State private var showingShareSheet = false
    @State private var generatedPDFUrl: URL?
    @State private var isGeneratingPDF = false

    private var planSessions: [WorkoutSession] {
        allSessions.filter { $0.plan?.id == plan.id && $0.endTime != nil }
                   .sorted { $0.startTime < $1.startTime }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Plan-Name Header
                Text(plan.name)
                    .font(.title2.bold())
                    .foregroundStyle(Color.textPrimary)
                    .padding(.horizontal)

                // Summary Stats (3 Kacheln)
                HStack(spacing: 12) {
                    StatTile(
                        title: "Workouts",
                        value: "\(planSessions.count)",
                        icon: "dumbbell.fill",
                        color: .brand
                    )
                    StatTile(
                        title: "Ø Dauer",
                        value: formatDuration(viewModel.averageWorkoutDuration(in: planSessions)),
                        icon: "clock.fill",
                        color: .brandSecondary
                    )
                    StatTile(
                        title: "Volumen",
                        value: formatVolume(viewModel.totalVolume(in: planSessions)),
                        icon: "chart.bar.fill",
                        color: .success
                    )
                }
                .padding(.horizontal)

                // Wöchentliche Frequenz (Balkendiagramm)
                if !planSessions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Trainingsfrequenz")
                            .font(.headline)
                            .padding(.horizontal)

                        let freqData = viewModel.weeklyFrequency(in: planSessions)
                        Chart(freqData, id: \.weekLabel) { item in
                            BarMark(
                                x: .value("Woche", item.weekLabel),
                                y: .value("Workouts", item.count)
                            )
                            .foregroundStyle(Color.brand.gradient)
                            .cornerRadius(4)
                        }
                        .frame(height: 160)
                        .chartXAxis {
                            AxisMarks { val in
                                AxisValueLabel()
                                    .foregroundStyle(Color.textSecondary)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Session-History Liste
                VStack(alignment: .leading, spacing: 8) {
                    Text("Verlauf")
                        .font(.headline)
                        .padding(.horizontal)

                    ForEach(groupedSessions, id: \.monthYear) { group in
                        Text(group.monthYear)
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.textSecondary)
                            .padding(.horizontal)
                            .padding(.top, 8)

                        ForEach(group.sessions) { session in
                            NavigationLink(destination: WorkoutHistoryDetailView(session: session, activeSessionId: nil)) {
                                PlanSessionRow(session: session)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color.backgroundPrimary)
        .navigationTitle("Statistik")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isGeneratingPDF {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.8)
                } else {
                    Menu {
                        Section("Als PDF exportieren") {
                            Button {
                                exportEmptyPlan()
                            } label: {
                                Label("Leerer Plan (Vorlage)", systemImage: "doc.text")
                            }
                            
                            Button {
                                exportHistoricalPlan()
                            } label: {
                                Label("Historie inkl. Daten", systemImage: "chart.bar.doc.horizontal")
                            }
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet, onDismiss: {
            if let url = generatedPDFUrl {
                try? FileManager.default.removeItem(at: url)
            }
        }) {
            if let url = generatedPDFUrl {
                ShareSheet(activityItems: [url])
                    .presentationDetents([.medium, .large])
            }
        }
    }
    
    private func exportEmptyPlan() {
        isGeneratingPDF = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let url = PDFExportService.shared.exportEmptyPlan(plan) {
                self.generatedPDFUrl = url
                self.showingShareSheet = true
            }
            self.isGeneratingPDF = false
        }
    }

    private func exportHistoricalPlan() {
        isGeneratingPDF = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let url = PDFExportService.shared.exportHistoricalPlan(plan: plan, sessions: planSessions) {
                self.generatedPDFUrl = url
                self.showingShareSheet = true
            }
            self.isGeneratingPDF = false
        }
    }

    // MARK: - Helpers
    private var groupedSessions: [(monthYear: String, sessions: [WorkoutSession])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        
        var groups: [(monthYear: String, sessions: [WorkoutSession])] = []
        for session in planSessions.reversed() {
            let label = formatter.string(from: session.startTime)
            if let lastIndex = groups.indices.last, groups[lastIndex].monthYear == label {
                groups[lastIndex].sessions.append(session)
            } else {
                groups.append((monthYear: label, sessions: [session]))
            }
        }
        return groups
    }
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        if mins < 60 { return "\(mins) min" }
        return "\(mins / 60)h \(mins % 60)m"
    }

    private func formatVolume(_ kg: Double) -> String {
        if kg >= 1000 { return String(format: "%.1ft", kg / 1000) }
        return "\(Int(kg)) kg"
    }
}

// MARK: - Supporting Views

struct StatTile: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Spacer()
            }
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(Color.textPrimary)
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
        }
        .padding(12)
        .background(Color.backgroundCard)
        .cornerRadius(12)
    }
}

struct PlanSessionRow: View {
    let session: WorkoutSession

    private var duration: String {
        guard let end = session.endTime else { return "–" }
        let mins = Int(end.timeIntervalSince(session.startTime)) / 60
        return "\(mins) min"
    }

    private var repCount: Int {
        (session.sets ?? []).filter(\.isCompleted).reduce(0) { $0 + $1.actualReps }
    }

    private var dateLabel: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: session.startTime)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(dateLabel)
                    .font(.subheadline)
                    .foregroundStyle(Color.textPrimary)
                Text("\(repCount) Wdh. · \(duration)")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer()
            if let mood = session.moodRating {
                Text(moodStars(mood))
                    .font(.caption)
                    .foregroundStyle(Color.warning)
            }
        }
        .padding(12)
        .background(Color.backgroundCard)
        .cornerRadius(10)
    }

    private func moodStars(_ rating: Int) -> String {
        let filled = max(0, min(5, rating))
        let empty = 5 - filled
        return String(repeating: "★", count: filled) + String(repeating: "☆", count: empty)
    }
}
