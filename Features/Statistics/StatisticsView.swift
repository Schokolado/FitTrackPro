import SwiftUI
import SwiftData
import Charts

struct StatisticsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var themeManager: ThemeManager

    // SwiftData Queries
    @Query(sort: \WorkoutSession.startTime, order: .reverse)
    private var allSessions: [WorkoutSession]

    @Query(sort: \Exercise.name)
    private var allExercises: [Exercise]

    @Query(sort: \TrainingPlan.createdAt, order: .reverse)
    private var allPlans: [TrainingPlan]

    // ViewModel
    @State private var viewModel = StatisticsViewModel()

    // Navigation State
    @State private var selectedSegment: Int = 0  // 0 = Übungen, 1 = Pläne, 2 = Balance
    @State private var balanceMetric: MuscleBalanceMetric = .sets
    @State private var navId = UUID()
    @AppStorage("stats_selectedExerciseId") private var savedExerciseId: String = ""

    // Export State
    @State private var isGeneratingPDF = false
    @State private var generatedPDFUrl: URL?
    @State private var showingShareSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                    // ─── Header Picker ─────────────────────────────────
                    Picker("Ansicht", selection: $selectedSegment) {
                        Text("Übungen").tag(0)
                        Text("Pläne").tag(1)
                        Text("Balance").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // ─── Zeitraum-Filter (für Übungen & Balance) ────
                    if selectedSegment == 0 || selectedSegment == 2 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(TimeRange.allCases) { range in
                                    TimeRangeChip(
                                        label: range.rawValue,
                                        isSelected: viewModel.selectedTimeRange == range
                                    ) {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            viewModel.selectedTimeRange = range
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // ─── Inhalt je nach Segment ───────────────────────
                    if selectedSegment == 0 {
                        exerciseStatisticsSection
                    } else if selectedSegment == 1 {
                        planStatisticsSection
                    } else {
                        balanceStatisticsSection
                    }
                }
                .padding(.bottom, 120)
            }
            .background(Color.backgroundPrimary)
            .navigationTitle("Statistik")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedSegment == 0, let exercise = viewModel.selectedExercise {
                        if isGeneratingPDF {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.8)
                        } else {
                            Menu {
                                Section("Als PDF exportieren") {
                                    Button {
                                        exportExerciseHistory(exercise)
                                    } label: {
                                        Label("Übungs-Historie", systemImage: "chart.bar.doc.horizontal")
                                    }
                                }
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = generatedPDFUrl {
                    ShareSheet(activityItems: [url])
                }
            }
        .id(navId)
        .onAppear {
            preselectExercise()
        }
        .onChange(of: viewModel.selectedTimeRange) { _, _ in
            preselectExercise()
        }
        .onChange(of: viewModel.selectedExercise) { _, newValue in
            savedExerciseId = newValue?.id.uuidString ?? ""
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TabReselected"))) { notification in
            if let tab = notification.object as? Int, tab == 3 {
                navId = UUID()
            }
        }
    }

    private func exportExerciseHistory(_ exercise: Exercise) {
        isGeneratingPDF = true
        let sessions = filteredSessions
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let url = PDFExportService.shared.exportExerciseHistory(exercise: exercise, sessions: sessions) {
                self.generatedPDFUrl = url
                self.showingShareSheet = true
            }
            self.isGeneratingPDF = false
        }
    }

    // MARK: - Übungen-Sektion

    private var filteredSessions: [WorkoutSession] {
        viewModel.filteredSessions(from: allSessions, timeRange: viewModel.selectedTimeRange)
    }

    private var usedExercises: [Exercise] {
        viewModel.usedExercises(in: filteredSessions)
    }

    private var exercisesByCategory: [(category: String, exercises: [Exercise])] {
        let grouped = Dictionary(grouping: usedExercises, by: \.category)
        return grouped.keys.sorted().map { key in
            (category: key, exercises: grouped[key] ?? [])
        }
    }

    private var exerciseStatisticsSection: some View {
        VStack(spacing: 12) {
            if let exercise = viewModel.selectedExercise {
                // Personal Record Card
                if let pr = viewModel.personalRecord(for: exercise, in: allSessions) {
                    PersonalRecordCard(record: pr)
                        .padding(.horizontal)
                }

                // Chart Card with exercise title inside
                VStack(alignment: .leading, spacing: 12) {
                    // Exercise title + selector
                    exerciseChartHeader

                    let data = viewModel.chartData(
                        for: exercise,
                        in: filteredSessions,
                        metric: viewModel.selectedMetric
                    )

                    ExerciseProgressChart(
                        dataPoints: data,
                        metric: viewModel.selectedMetric,
                        accentColor: .brand
                    )

                    if !data.isEmpty {
                        chartSummaryRow(data: data)
                    }
                }
                .padding()
                .background(Color.backgroundCard)
                .cornerRadius(16)
                .padding(.horizontal)

                // Metrik-Auswahl
                Picker("Metrik", selection: $viewModel.selectedMetric) {
                    ForEach(StatisticsMetric.allCases) { metric in
                        Text(metric.rawValue).tag(metric)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
            } else if usedExercises.isEmpty {
                Text("Keine Workouts im gewählten Zeitraum.")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
                    .padding(.horizontal)
            } else {
                // Initial exercise selection
                exerciseChartHeader
                    .padding(.horizontal)
                noExerciseSelectedView
            }
        }
    }

    /// Chart header: exercise name as title, tappable to change exercise
    private var exerciseChartHeader: some View {
        Menu {
            ForEach(exercisesByCategory, id: \.category) { group in
                Section(group.category) {
                    ForEach(group.exercises) { exercise in
                        Button {
                            viewModel.selectedExercise = exercise
                        } label: {
                            Text(exercise.name)
                            if viewModel.selectedExercise?.id == exercise.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    Text(viewModel.selectedExercise?.name ?? "Übung wählen")
                        .font(.title3.bold())
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(viewModel.selectedExercise == nil ? Color.textSecondary : Color.textPrimary)
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundStyle(Color.brand)
                        .imageScale(.small)
                    Spacer()
                }
                if viewModel.selectedExercise != nil {
                    Text(viewModel.selectedMetric == .reps ? "Wiederholungen" : viewModel.selectedMetric.rawValue)
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private func chartSummaryRow(data: [VolumeDataPoint]) -> some View {
        let values = data.map(\.value)
        if let minV = values.min(), let maxV = values.max() {
            HStack {
                VStack(alignment: .leading) {
                    Text("Min")
                        .font(.caption2)
                        .foregroundStyle(Color.textSecondary)
                    Text(formatValue(minV))
                        .font(.caption.bold())
                        .foregroundStyle(Color.textPrimary)
                }
                Spacer()
                VStack {
                    Text("Ø")
                        .font(.caption2)
                        .foregroundStyle(Color.textSecondary)
                    let avg = values.reduce(0, +) / Double(values.count)
                    Text(formatValue(avg))
                        .font(.caption.bold())
                        .foregroundStyle(Color.textPrimary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Max")
                        .font(.caption2)
                        .foregroundStyle(Color.textSecondary)
                    Text(formatValue(maxV))
                        .font(.caption.bold())
                        .foregroundStyle(Color.brandSecondary)
                }
            }
        }
    }

    private func formatValue(_ v: Double) -> String {
        switch viewModel.selectedMetric {
        case .reps:      return "\(Int(v))"
        default:         return "\(Int(v)) kg"
        }
    }

    private var noExerciseSelectedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.tap")
                .font(.system(size: 44))
                .foregroundStyle(Color.brand.opacity(0.6))
            Text("Übung auswählen")
                .font(.headline)
                .foregroundStyle(Color.textPrimary)
            Text("Wähle oben eine Übung, um deinen Fortschritt zu sehen.")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 250)
    }

    private func preselectExercise() {
        let available = usedExercises
        
        if let savedId = UUID(uuidString: savedExerciseId),
           let savedExercise = available.first(where: { $0.id == savedId }) {
            if viewModel.selectedExercise?.id != savedExercise.id {
                viewModel.selectedExercise = savedExercise
            }
            return
        }
        
        if viewModel.selectedExercise == nil || !available.contains(where: { $0.id == viewModel.selectedExercise?.id }) {
            let bestExercise = available.first { ex in
                !viewModel.volumeData(for: ex, in: filteredSessions).isEmpty
            } ?? available.first
            viewModel.selectedExercise = bestExercise
        }
    }

    // MARK: - Pläne-Sektion

    private var planStatisticsSection: some View {
        VStack(spacing: 16) {
            if allPlans.isEmpty {
                emptyPlansView
            } else {
                ForEach(allPlans) { plan in
                    NavigationLink {
                        PlanProgressView(
                            plan: plan,
                            allSessions: allSessions,
                            viewModel: viewModel
                        )
                    } label: {
                        PlanSummaryCard(
                            plan: plan,
                            sessions: allSessions.filter { $0.plan?.id == plan.id },
                            viewModel: viewModel
                        )
                        .padding(.horizontal)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    private var emptyPlansView: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 44))
                .foregroundStyle(Color.brand.opacity(0.6))
            Text("Keine Trainingspläne")
                .font(.headline)
            Text("Erstelle einen Trainingsplan im Training-Tab.")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 250)
    }

    // MARK: - Balance & Aktivitätszusammenfassung

    private var balanceStatisticsSection: some View {
        let sessions = filteredSessions
        let breakdown = viewModel.muscleGroupBreakdown(in: sessions)
        let workoutCount = viewModel.completedWorkoutCount(in: sessions)
        let totalVol = viewModel.totalVolume(in: sessions)
        let totalSets = viewModel.totalSets(in: sessions)
        let totalDur = viewModel.totalWorkoutDuration(in: sessions)
        let avgDur = viewModel.averageWorkoutDuration(in: sessions)

        return VStack(spacing: 16) {
            if sessions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.brand.opacity(0.6))
                    Text("Noch keine abgeschlossenen Workouts")
                        .font(.headline)
                    Text("Absolviere ein Workout im gewählten Zeitraum, um deine Muskelgruppen-Balance und Aktivitätszusammenfassung zu sehen.")
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 250)
            } else {
                // 1. Aktivitätszusammenfassung Card
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(Color.orange)
                        Text("Aktivitätszusammenfassung")
                            .font(.headline)
                        Spacer()
                        Text(viewModel.selectedTimeRange.rawValue)
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        activityMetricTile(
                            title: "Workouts",
                            value: "\(workoutCount)",
                            subtitle: avgDur > 0 ? "Ø \(formatDurationShort(avgDur))" : "Abgeschlossen",
                            icon: "figure.strengthtraining.traditional",
                            color: .brand
                        )
                        activityMetricTile(
                            title: "Trainingszeit",
                            value: formatDurationShort(totalDur),
                            subtitle: "Gesamtdauer",
                            icon: "clock.fill",
                            color: .blue
                        )
                        activityMetricTile(
                            title: "Gesamtvolumen",
                            value: "\(Int(totalVol)) kg",
                            subtitle: "Bewegtes Gewicht",
                            icon: "scalemass.fill",
                            color: .purple
                        )
                        activityMetricTile(
                            title: "Sätze",
                            value: "\(totalSets)",
                            subtitle: "Abgeschlossen",
                            icon: "checkmark.circle.fill",
                            color: .green
                        )
                    }
                }
                .padding()
                .background(Color.backgroundCard)
                .cornerRadius(16)
                .padding(.horizontal)

                // 2. Muskelgruppen-Balance Card
                if !breakdown.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "chart.pie.fill")
                                .foregroundStyle(Color.brand)
                            Text("Muskelgruppen-Balance")
                                .font(.headline)
                            Spacer()
                        }

                        Picker("Balance-Metrik", selection: $balanceMetric) {
                            ForEach(MuscleBalanceMetric.allCases) { m in
                                Text(m.rawValue).tag(m)
                            }
                        }
                        .pickerStyle(.segmented)

                        let totalMetricValue = breakdown.reduce(0.0) { $0 + metricValue(for: $1) }

                        // Donut Chart
                        Chart(breakdown) { item in
                            let val = metricValue(for: item)
                            if val > 0 {
                                SectorMark(
                                    angle: .value(balanceMetric.rawValue, val),
                                    innerRadius: .ratio(0.58),
                                    angularInset: 2
                                )
                                .cornerRadius(4)
                                .foregroundStyle(themeManager.color(for: item.category))
                            }
                        }
                        .frame(height: 210)
                        .chartBackground { _ in
                            VStack(spacing: 2) {
                                Text(formatTotalMetric(totalMetricValue))
                                    .font(.title3.bold())
                                    .foregroundStyle(Color.textPrimary)
                                Text(balanceMetric.rawValue)
                                    .font(.caption2)
                                    .foregroundStyle(Color.textSecondary)
                            }
                        }

                        // Breakdown List
                        VStack(spacing: 10) {
                            ForEach(breakdown) { item in
                                let val = metricValue(for: item)
                                let pct = totalMetricValue > 0 ? Int(round((val / totalMetricValue) * 100)) : 0
                                let catColor = themeManager.color(for: item.category)

                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(catColor)
                                        .frame(width: 10, height: 10)

                                    Text(item.category)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.textPrimary)

                                    Spacer()

                                    Text("\(item.setCount) Sätze")
                                        .font(.caption)
                                        .foregroundStyle(Color.textSecondary)

                                    if item.volumeKg > 0 {
                                        Text("• \(Int(item.volumeKg)) kg")
                                            .font(.caption)
                                            .foregroundStyle(Color.textSecondary)
                                    }

                                    Text("\(pct)%")
                                        .font(.caption.bold())
                                        .foregroundStyle(catColor)
                                        .frame(minWidth: 36, alignment: .trailing)
                                }
                                .padding(.vertical, 2)
                            }
                        }

                        if let insight = viewModel.muscleBalanceInsight(from: breakdown) {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: insight.isBalanced ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                    .foregroundStyle(insight.isBalanced ? Color.green : Color.orange)
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(insight.title)
                                        .font(.subheadline.bold())
                                    Text(insight.message)
                                        .font(.caption)
                                        .foregroundStyle(Color.textSecondary)
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background((insight.isBalanced ? Color.green : Color.orange).opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                    .background(Color.backgroundCard)
                    .cornerRadius(16)
                    .padding(.horizontal)
                }
            }
        }
    }

    private func metricValue(for item: MuscleGroupStat) -> Double {
        switch balanceMetric {
        case .sets:     return Double(item.setCount)
        case .volume:   return item.volumeKg
        case .workouts: return Double(item.workoutCount)
        }
    }

    private func formatTotalMetric(_ val: Double) -> String {
        switch balanceMetric {
        case .sets, .workouts: return "\(Int(val))"
        case .volume:          return "\(Int(val)) kg"
        }
    }

    private func formatDurationShort(_ duration: TimeInterval) -> String {
        let mins = Int(duration) / 60
        let h = mins / 60
        let m = mins % 60
        if h > 0 {
            return "\(h)h \(m)m"
        }
        return "\(m) Min"
    }

    private func activityMetricTile(title: String, value: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(Color.textPrimary)
                .minimumScaleFactor(0.75)
                .lineLimit(1)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.backgroundSecondary)
        .cornerRadius(12)
    }


}

// MARK: - Supporting Views

struct TimeRangeChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.brand : Color.backgroundCard)
                .foregroundStyle(isSelected ? .white : Color.textSecondary)
                .cornerRadius(20)
                .animation(.smooth, value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ExerciseChip: View {
    let exercise: Exercise
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: exercise.themeIcon)
                    .font(.caption)
                Text(exercise.name)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? Color.brand.opacity(0.15) : Color.backgroundCard)
            .foregroundStyle(isSelected ? Color.brand : Color.textSecondary)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.brand : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PersonalRecordCard: View {
    let record: PersonalRecord

    private var dateString: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: record.achievedAt)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Trophäen-Icon
            ZStack {
                Circle()
                    .fill(Color.warning.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: "trophy.fill")
                    .font(.title3)
                    .foregroundStyle(Color.warning)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Persönlicher Rekord")
                    .font(.caption)
                    .foregroundStyle(Color.warning)
                Text("\(Int(record.weightKg)) kg × \(record.totalReps) Wdh.")
                    .font(.title3.bold())
                    .foregroundStyle(Color.textPrimary)
                Text("Erreicht am \(dateString)")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.warning.opacity(0.08), Color.backgroundCard],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.warning.opacity(0.3), lineWidth: 1)
        )
    }
}

struct PlanSummaryCard: View {
    let plan: TrainingPlan
    let sessions: [WorkoutSession]
    let viewModel: StatisticsViewModel

    private var completedSessions: [WorkoutSession] {
        sessions.filter { $0.endTime != nil }
    }

    private var lastSession: WorkoutSession? {
        completedSessions.sorted { $0.startTime > $1.startTime }.first
    }

    private var lastSessionLabel: String {
        guard let last = lastSession else { return "Noch kein Workout" }
        let f = DateFormatter()
        f.dateStyle = .medium
        return "Zuletzt: \(f.string(from: last.startTime))"
    }

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.brand.opacity(0.12))
                    .frame(width: 52, height: 52)
                Image(systemName: "list.bullet.rectangle.portrait.fill")
                    .font(.title3)
                    .foregroundStyle(Color.brand)
            }

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.name)
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)
                Text(lastSessionLabel)
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            // Workout-Anzahl Badge
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(completedSessions.count)")
                    .font(.title2.bold())
                    .foregroundStyle(Color.brand)
                Text("Workouts")
                    .font(.caption2)
                    .foregroundStyle(Color.textSecondary)
            }

            Image(systemName: "chevron.right")
                .foregroundStyle(Color.textSecondary)
                .font(.caption)
        }
        .padding()
        .background(Color.backgroundCard)
        .cornerRadius(16)
    }
}
