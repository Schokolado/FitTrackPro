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
            if let ex = newValue, !ex.usesWeightInput {
                viewModel.selectedMetric = .reps
            }
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

                    let activeMetric: StatisticsMetric = exercise.usesWeightInput ? viewModel.selectedMetric : .reps
                    let data = viewModel.chartData(
                        for: exercise,
                        in: filteredSessions,
                        metric: activeMetric
                    )

                    ExerciseProgressChart(
                        dataPoints: data,
                        metric: activeMetric,
                        accentColor: .brand,
                        repsUnit: exercise.usesTimeInput ? exercise.effectiveTimeUnit : nil
                    )

                    if !data.isEmpty {
                        chartSummaryRow(data: data)
                    }
                }
                .padding()
                .background(Color.backgroundCard)
                .cornerRadius(16)
                .padding(.horizontal)

                // Metrik-Auswahl (bei reinen Zeit-Übungen ohne Gewicht nicht nötig)
                if exercise.usesWeightInput {
                    Picker("Metrik", selection: $viewModel.selectedMetric) {
                        ForEach(StatisticsMetric.allCases) { metric in
                            Text(metric.rawValue).tag(metric)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                }
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
                if let ex = viewModel.selectedExercise {
                    let metricSubtitle: String = {
                        if !ex.usesWeightInput && ex.usesTimeInput {
                            return "Gesamtdauer (\(ex.effectiveTimeUnit))"
                        }
                        if viewModel.selectedMetric == .reps {
                            return ex.usesTimeInput ? "Dauer (\(ex.effectiveTimeUnit))" : "Wiederholungen"
                        }
                        return viewModel.selectedMetric.rawValue
                    }()
                    Text(metricSubtitle)
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
        let effectiveMetric = (viewModel.selectedExercise?.usesWeightInput == false) ? .reps : viewModel.selectedMetric
        switch effectiveMetric {
        case .reps:
            if let ex = viewModel.selectedExercise, ex.usesTimeInput {
                return "\(Int(v)) \(ex.effectiveTimeUnit)"
            }
            return "\(Int(v))"
        default:
            return "\(Int(v)) kg"
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
                    MuscleBalanceCard(
                        stats: breakdown,
                        availableMetrics: [.sets, .volume, .workouts],
                        configuredFocus: .fullBody
                    )
                    .padding(.horizontal)
                }

                // 3. Trainingsbelastung & Fitness-Status (über letzte 6 Wochen)
                let loadAnalysis = TrainingLoadCalculator.analyze(workouts: allSessions)
                NavigationLink(destination: TrainingLoadDetailView(analysis: loadAnalysis)) {
                    TrainingLoadSummaryCard(analysis: loadAnalysis)
                        .padding(.horizontal)
                }
                .buttonStyle(.plain)
            }
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
                let prText: String = {
                    let ex = record.exercise
                    let unit = ex.effectiveTimeUnit
                    if ex.usesLevelInput {
                        return record.weightKg > 0
                            ? "Level \(Int(record.weightKg)) • \(record.totalReps) \(unit)"
                            : "\(record.totalReps) \(unit)"
                    } else if ex.usesTimeInput {
                        if ex.usesWeightInput && record.weightKg > 0 {
                            return "\(Int(record.weightKg)) kg • \(record.totalReps) \(unit)"
                        }
                        return "\(record.totalReps) \(unit)"
                    } else {
                        return "\(Int(record.weightKg)) kg × \(record.totalReps) Wdh."
                    }
                }()
                Text(prText)
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

// MARK: - Wiederverwendbare interaktive Muskelgruppen-Balance-Card

struct MuscleBalanceCard: View {
    @EnvironmentObject var themeManager: ThemeManager

    let title: String
    let stats: [MuscleGroupStat]
    let availableMetrics: [MuscleBalanceMetric]
    let showInsight: Bool
    let configuredFocus: PlanFocus
    let focusBinding: Binding<PlanFocus>?
    let planName: String?
    let onCollapse: (() -> Void)?

    @State private var selectedMetric: MuscleBalanceMetric
    @State private var selectedCategory: String?

    init(
        title: String = "Muskelgruppen-Balance",
        stats: [MuscleGroupStat],
        availableMetrics: [MuscleBalanceMetric] = [.sets, .volume],
        showInsight: Bool = true,
        configuredFocus: PlanFocus = .auto,
        focusBinding: Binding<PlanFocus>? = nil,
        planName: String? = nil,
        onCollapse: (() -> Void)? = nil
    ) {
        self.title = title
        self.stats = stats
        let resolvedMetrics = availableMetrics.isEmpty ? [.sets] : availableMetrics
        self.availableMetrics = resolvedMetrics
        self.showInsight = showInsight
        self.configuredFocus = configuredFocus
        self.focusBinding = focusBinding
        self.planName = planName
        self.onCollapse = onCollapse

        // Erste Metrik mit Werten > 0 automatisch bevorzugen (z. B. .exercises, falls Soll-Sätze 0 sind)
        let firstWithData = resolvedMetrics.first { metric in
            stats.contains { Self.metricValue(for: $0, metric: metric) > 0 }
        }
        _selectedMetric = State(initialValue: firstWithData ?? resolvedMetrics[0])
    }

    private var activeConfiguredFocus: PlanFocus {
        focusBinding?.wrappedValue ?? configuredFocus
    }

    private var effectiveFocus: PlanFocus {
        StatisticsViewModel.resolvedPlanFocus(for: activeConfiguredFocus, planName: planName, stats: stats)
    }

    private var visibleStats: [MuscleGroupStat] {
        stats.filter { Self.metricValue(for: $0, metric: selectedMetric) > 0 }
    }

    private var totalMetricValue: Double {
        visibleStats.reduce(0.0) { $0 + Self.metricValue(for: $1, metric: selectedMetric) }
    }

    private var selectedItem: MuscleGroupStat? {
        guard let selectedCategory else { return nil }
        return visibleStats.first { $0.category == selectedCategory }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundStyle(Color.brand)
                Text(title)
                    .font(.headline)
                Spacer()
                if let focusBinding {
                    focusPickerMenu(binding: focusBinding)
                } else if activeConfiguredFocus == .auto && !stats.isEmpty {
                    focusBadge(text: "Auto: \(effectiveFocus.shortLabel)")
                } else if activeConfiguredFocus != .fullBody {
                    focusBadge(text: activeConfiguredFocus.shortLabel)
                }
                if let onCollapse {
                    Button(action: onCollapse) {
                        Image(systemName: "chevron.up")
                            .font(.caption.bold())
                            .foregroundStyle(Color.textSecondary)
                            .padding(6)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if let onCollapse {
                    onCollapse()
                } else if selectedCategory != nil {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = nil
                    }
                }
            }

            if availableMetrics.count > 1 {
                Picker("Balance-Metrik", selection: $selectedMetric) {
                    ForEach(availableMetrics) { metric in
                        Text(metric.rawValue).tag(metric)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedMetric) { _, newMetric in
                    if let current = selectedCategory,
                       !stats.contains(where: { $0.category == current && Self.metricValue(for: $0, metric: newMetric) > 0 }) {
                        selectedCategory = nil
                    }
                }
            }

            if visibleStats.isEmpty {
                Text("Für die gewählte Metrik liegen noch keine Werte vor.")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                // Interaktiver Donut Chart
                Chart(visibleStats) { item in
                    let val = Self.metricValue(for: item, metric: selectedMetric)
                    let isSelected = selectedCategory == item.category
                    let isDimmed = selectedCategory != nil && !isSelected
                    let catColor = themeManager.color(for: item.category)

                    SectorMark(
                        angle: .value(selectedMetric.rawValue, val),
                        innerRadius: .ratio(0.58),
                        outerRadius: isSelected ? .ratio(1.0) : (selectedCategory == nil ? .ratio(0.94) : .ratio(0.86)),
                        angularInset: 2
                    )
                    .cornerRadius(4)
                    .foregroundStyle(catColor.opacity(isDimmed ? 0.28 : 1.0))
                }
                .frame(height: 210)
                .animation(.easeInOut(duration: 0.2), value: selectedCategory)
                .chartBackground { _ in
                    centerLabelView
                }
                .chartOverlay { _ in
                    GeometryReader { geo in
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                handleDonutTap(at: location, in: geo.size)
                            }
                    }
                }

                // Breakdown Liste (ebenfalls antippbar zum Hervorheben / Abwählen)
                VStack(spacing: 6) {
                    ForEach(visibleStats) { item in
                        breakdownRow(for: item)
                    }
                }
            }

            if showInsight, let insight = StatisticsViewModel.muscleBalanceInsight(
                from: stats,
                configuredFocus: activeConfiguredFocus,
                planName: planName
            ) {
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
        .contentShape(Rectangle())
        .onTapGesture {
            if selectedCategory != nil {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedCategory = nil
                }
            }
        }
    }

    @ViewBuilder
    private func focusPickerMenu(binding: Binding<PlanFocus>) -> some View {
        let labelText = binding.wrappedValue == .auto
            ? "Auto: \(effectiveFocus.shortLabel)"
            : binding.wrappedValue.shortLabel

        Menu {
            ForEach(PlanFocus.allCases) { option in
                Button {
                    binding.wrappedValue = option
                } label: {
                    HStack {
                        Text(option.rawValue)
                        if binding.wrappedValue == option {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(labelText)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.brand)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.brand.opacity(0.12))
            .clipShape(Capsule())
        }
    }

    private func focusBadge(text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(Color.textSecondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.12))
            .clipShape(Capsule())
    }

    @ViewBuilder
    private var centerLabelView: some View {
        if let item = selectedItem {
            let val = Self.metricValue(for: item, metric: selectedMetric)
            let pct = totalMetricValue > 0 ? Int(round((val / totalMetricValue) * 100)) : 0
            let catColor = themeManager.color(for: item.category)

            VStack(spacing: 2) {
                Text(Self.formatMetricValue(val, metric: selectedMetric))
                    .font(.title3.bold())
                    .foregroundStyle(Color.textPrimary)
                Text(item.category)
                    .font(.caption.bold())
                    .foregroundStyle(catColor)
                    .lineLimit(1)
                Text("\(pct)%")
                    .font(.caption2)
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.horizontal, 8)
        } else {
            VStack(spacing: 2) {
                Text(Self.formatMetricValue(totalMetricValue, metric: selectedMetric))
                    .font(.title3.bold())
                    .foregroundStyle(Color.textPrimary)
                Text(selectedMetric.rawValue)
                    .font(.caption2)
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }

    private func breakdownRow(for item: MuscleGroupStat) -> some View {
        let val = Self.metricValue(for: item, metric: selectedMetric)
        let pct = totalMetricValue > 0 ? Int(round((val / totalMetricValue) * 100)) : 0
        let catColor = themeManager.color(for: item.category)
        let isSelected = selectedCategory == item.category
        let isDimmed = selectedCategory != nil && !isSelected

        return HStack(spacing: 10) {
            Circle()
                .fill(catColor)
                .frame(width: 10, height: 10)

            Text(item.category)
                .font(.subheadline.weight(isSelected ? .bold : .medium))
                .foregroundStyle(Color.textPrimary)

            Spacer()

            if item.setCount > 0 {
                Text("\(item.setCount) Sätze")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            } else {
                Text("\(item.exerciseCount) Üb.")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }

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
        .padding(.horizontal, isSelected ? 8 : 0)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? catColor.opacity(0.14) : Color.clear)
        )
        .opacity(isDimmed ? 0.42 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture {
            toggleCategory(item.category)
        }
    }

    private func handleDonutTap(at location: CGPoint, in size: CGSize) {
        guard totalMetricValue > 0, !visibleStats.isEmpty else { return }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let outerRadius = min(size.width, size.height) / 2
        let dx = location.x - center.x
        let dy = location.y - center.y
        let distance = hypot(dx, dy)

        // Klick in die Donut-Mitte oder außerhalb des Rings wählt die Auswahl ab
        guard distance >= outerRadius * 0.54, distance <= outerRadius else {
            if selectedCategory != nil {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedCategory = nil
                }
            }
            return
        }

        // Winkel ab 12 Uhr im Uhrzeigersinn [0, 2π)
        var angle = atan2(dx, -dy)
        if angle < 0 {
            angle += 2 * .pi
        }

        let targetValue = (angle / (2 * .pi)) * totalMetricValue
        var cumulative: Double = 0
        for item in visibleStats {
            cumulative += Self.metricValue(for: item, metric: selectedMetric)
            if targetValue <= cumulative {
                toggleCategory(item.category)
                return
            }
        }
    }

    private func toggleCategory(_ category: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if selectedCategory == category {
                selectedCategory = nil
            } else {
                selectedCategory = category
            }
        }
    }

    private static func metricValue(for item: MuscleGroupStat, metric: MuscleBalanceMetric) -> Double {
        switch metric {
        case .sets:      return Double(item.setCount)
        case .volume:    return item.volumeKg
        case .exercises: return Double(item.exerciseCount)
        case .workouts:  return Double(item.workoutCount)
        }
    }

    private static func formatMetricValue(_ val: Double, metric: MuscleBalanceMetric) -> String {
        switch metric {
        case .sets, .exercises, .workouts:
            return "\(Int(val))"
        case .volume:
            return "\(Int(val)) kg"
        }
    }
}

// MARK: - Kompakte Balance-Leiste (für Plan-Übersicht & einklappbare Detailansicht)

struct MuscleBalanceCompactBar: View {
    @EnvironmentObject var themeManager: ThemeManager

    let title: String
    let stats: [MuscleGroupStat]
    let configuredFocus: PlanFocus
    let planName: String?
    var trailingIcon: String = "chevron.right"

    private var effectiveFocus: PlanFocus {
        StatisticsViewModel.resolvedPlanFocus(for: configuredFocus, planName: planName, stats: stats)
    }

    private func unitValue(for item: MuscleGroupStat) -> Double {
        Double(item.setCount > 0 ? item.setCount : item.exerciseCount)
    }

    private var visibleStats: [MuscleGroupStat] {
        stats.filter { unitValue(for: $0) > 0 }
    }

    private var totalUnits: Double {
        visibleStats.reduce(0.0) { $0 + unitValue(for: $1) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "chart.pie.fill")
                    .foregroundStyle(Color.brand)
                    .font(.subheadline)

                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                if !stats.isEmpty {
                    Text(configuredFocus == .auto ? "Auto: \(effectiveFocus.shortLabel)" : configuredFocus.shortLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.brand)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.brand.opacity(0.12))
                        .clipShape(Capsule())
                }

                Image(systemName: trailingIcon)
                    .font(.caption.bold())
                    .foregroundStyle(Color.textSecondary)
            }

            // Gestapelter proportionaler Farbbalken
            if totalUnits > 0 {
                GeometryReader { geo in
                    let totalGap = CGFloat(max(0, visibleStats.count - 1)) * 2
                    let usableWidth = max(0, geo.size.width - totalGap)

                    HStack(spacing: 2) {
                        ForEach(visibleStats) { item in
                            let share = unitValue(for: item) / totalUnits
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(themeManager.color(for: item.category))
                                .frame(width: max(4, usableWidth * share), height: 10)
                        }
                    }
                }
                .frame(height: 10)

                // Kompakte horizontale Legende
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(visibleStats) { item in
                            let pct = Int(round((unitValue(for: item) / totalUnits) * 100))
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(themeManager.color(for: item.category))
                                    .frame(width: 8, height: 8)
                                Text("\(item.category) \(pct)%")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(Color.textSecondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color.backgroundCard)
        .cornerRadius(16)
    }
}

struct CollapsibleMuscleBalanceCard: View {
    let title: String
    let stats: [MuscleGroupStat]
    let availableMetrics: [MuscleBalanceMetric]
    let showInsight: Bool
    let configuredFocus: PlanFocus
    let focusBinding: Binding<PlanFocus>?
    let planName: String?

    @State private var isExpanded: Bool

    init(
        title: String = "Muskelgruppen-Balance",
        stats: [MuscleGroupStat],
        availableMetrics: [MuscleBalanceMetric] = [.sets, .volume],
        showInsight: Bool = true,
        configuredFocus: PlanFocus = .auto,
        focusBinding: Binding<PlanFocus>? = nil,
        planName: String? = nil,
        initiallyExpanded: Bool = false
    ) {
        self.title = title
        self.stats = stats
        self.availableMetrics = availableMetrics
        self.showInsight = showInsight
        self.configuredFocus = configuredFocus
        self.focusBinding = focusBinding
        self.planName = planName
        self._isExpanded = State(initialValue: initiallyExpanded)
    }

    var body: some View {
        if isExpanded {
            MuscleBalanceCard(
                title: title,
                stats: stats,
                availableMetrics: availableMetrics,
                showInsight: showInsight,
                configuredFocus: configuredFocus,
                focusBinding: focusBinding,
                planName: planName,
                onCollapse: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isExpanded = false
                    }
                }
            )
        } else {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded = true
                }
            } label: {
                MuscleBalanceCompactBar(
                    title: title,
                    stats: stats,
                    configuredFocus: focusBinding?.wrappedValue ?? configuredFocus,
                    planName: planName,
                    trailingIcon: "chevron.down"
                )
            }
            .buttonStyle(.plain)
        }
    }
}
