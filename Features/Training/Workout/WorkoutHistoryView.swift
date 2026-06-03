import SwiftUI
import SwiftData

// MARK: - Helpers

private func durationString(session: WorkoutSession, activeSessionId: UUID?) -> String {
    // Only show "Laufend" if this is the currently active session
    if session.endTime == nil {
        if session.id == activeSessionId { return "Laufend" }
        return "–"  // No endTime but not active → incomplete/aborted session
    }
    let secs = Int(session.endTime!.timeIntervalSince(session.startTime))
    let h = secs / 3600
    let m = (secs % 3600) / 60
    let s = secs % 60
    if h > 0 { return "\(h)h \(m)min \(s)s" }
    return "\(m)m \(s)s"
}

private func monthKey(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "de_DE")
    formatter.dateFormat = "MMMM yyyy"
    return formatter.string(from: date)
}

// MARK: - Workout History List View

struct WorkoutHistoryView: View {
    @Query(sort: \WorkoutSession.startTime, order: .reverse) private var sessions: [WorkoutSession]
    @Environment(WorkoutManager.self) private var workoutManager

    /// Sessions grouped by month, in order
    private var groupedSessions: [(monthLabel: String, sessions: [WorkoutSession])] {
        var result: [(monthLabel: String, sessions: [WorkoutSession])] = []
        var seen: [String: Int] = [:]
        for session in sessions {
            let key = monthKey(for: session.startTime)
            if let idx = seen[key] {
                result[idx].sessions.append(session)
            } else {
                seen[key] = result.count
                result.append((monthLabel: key, sessions: [session]))
            }
        }
        return result
    }

    private var activeSessionId: UUID? {
        workoutManager.activeSession?.id
    }

    @AppStorage("openHistorySessionId") private var openHistorySessionId: String = ""

    private var selectionBinding: Binding<String?> {
        Binding(
            get: { openHistorySessionId.isEmpty ? nil : openHistorySessionId },
            set: { openHistorySessionId = $0 ?? "" }
        )
    }

    var body: some View {
        Group {
            if sessions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Noch keine Trainings absolviert")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Absolviere dein erstes Workout, um es hier zu sehen.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 80)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12, pinnedViews: []) {
                        ForEach(groupedSessions, id: \.monthLabel) { group in
                            // Month header
                            HStack {
                                Text(group.monthLabel)
                                    .font(.subheadline.bold())
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(group.sessions.count) Einheiten")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 4)
                            .padding(.top, 8)

                            // Cards in this month
                            ForEach(group.sessions) { session in
                                NavigationLink(
                                    destination: WorkoutHistoryDetailView(session: session, activeSessionId: activeSessionId),
                                    tag: session.id.uuidString,
                                    selection: selectionBinding
                                ) {
                                    WorkoutHistoryCard(session: session, activeSessionId: activeSessionId)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding()
                    .padding(.bottom, 80)
                }
            }
        }
        .background(Color.backgroundPrimary)
        .onAppear {
            // Check if openHistorySessionId matches an existing session
            // If not, clear it so we don't get stuck
            if !openHistorySessionId.isEmpty && !sessions.contains(where: { $0.id.uuidString == openHistorySessionId }) {
                openHistorySessionId = ""
            }
        }
    }
}


// MARK: - History Card (List Row)

struct WorkoutHistoryCard: View {
    let session: WorkoutSession
    let activeSessionId: UUID?

    private var duration: String {
        durationString(session: session, activeSessionId: activeSessionId)
    }

    private var completedSets: [WorkoutSet] {
        (session.sets ?? []).filter { $0.isCompleted }
    }

    private var exerciseCount: Int {
        Set(completedSets.compactMap { $0.exercise?.id }).count
    }

    private var totalVolume: Double {
        completedSets.reduce(0) { $0 + ($1.actualWeight * Double($1.actualReps)) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.plan?.name ?? "Freies Workout")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(session.startTime, format: .dateTime.weekday(.wide).day().month().year())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            Divider()

            // Stats row
            HStack(spacing: 0) {
                StatPill(icon: "clock", label: duration)
                Spacer()
                StatPill(icon: "dumbbell", label: "\(exerciseCount) Übungen")
                Spacer()
                StatPill(icon: "square.stack.3d.up", label: "\(completedSets.count) Sätze")
                Spacer()
                StatPill(icon: "scalemass", label: String(format: "%.0f kg", totalVolume))
            }

            // Rating row (only if set)
            if session.moodRating != nil || session.intensityRating != nil {
                HStack(spacing: 12) {
                    if let mood = session.moodRating {
                        RatingBadge(label: "Stimmung", value: mood, color: .blue)
                    }
                    if let intensity = session.intensityRating {
                        RatingBadge(label: "Intensität", value: intensity, color: .orange)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.backgroundSecondary)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        )
    }
}

struct StatPill: View {
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(.brand)
            Text(label)
                .font(.caption.bold())
                .foregroundColor(.primary)
        }
    }
}

struct RatingBadge: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { i in
                    Image(systemName: i <= value ? "star.fill" : "star")
                        .font(.system(size: 9))
                        .foregroundColor(i <= value ? color : .secondary.opacity(0.4))
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Detail View

struct WorkoutHistoryDetailView: View {
    let session: WorkoutSession
    let activeSessionId: UUID?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false

    private var duration: String {
        durationString(session: session, activeSessionId: activeSessionId)
    }

    private var completedSets: [WorkoutSet] {
        (session.sets ?? []).filter { $0.isCompleted }
    }

    private var totalVolume: Double {
        completedSets.reduce(0) { $0 + ($1.actualWeight * Double($1.actualReps)) }
    }

    // Group sets by exercise
    private var exerciseGroups: [(Exercise, [WorkoutSet])] {
        var dict: [(Exercise, [WorkoutSet])] = []
        var seen: [UUID: Int] = [:]
        for set in completedSets.sorted(by: { $0.setNumber < $1.setNumber }) {
            guard let ex = set.exercise else { continue }
            if let idx = seen[ex.id] {
                dict[idx].1.append(set)
            } else {
                seen[ex.id] = dict.count
                dict.append((ex, [set]))
            }
        }
        return dict
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // Summary card
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.plan?.name ?? "Freies Workout")
                                .font(.title2.bold())
                            Text(session.startTime, format: .dateTime.weekday(.wide).day().month().year())
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }

                    Divider()

                    // Stats grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        DetailStatBox(icon: "clock.fill", label: "Dauer", value: duration, color: .brand)
                        DetailStatBox(icon: "scalemass.fill", label: "Volumen", value: String(format: "%.0f kg", totalVolume), color: .purple)
                        DetailStatBox(icon: "dumbbell.fill", label: "Übungen", value: "\(exerciseGroups.count)", color: .blue)
                        DetailStatBox(icon: "square.stack.3d.up.fill", label: "Sätze", value: "\(completedSets.count)", color: .orange)
                    }

                    // Ratings
                    if session.moodRating != nil || session.intensityRating != nil {
                        Divider()
                        HStack(spacing: 20) {
                            if let mood = session.moodRating {
                                VStack(spacing: 4) {
                                    Text("Stimmung")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    HStack(spacing: 3) {
                                        ForEach(1...5, id: \.self) { i in
                                            Image(systemName: i <= mood ? "star.fill" : "star")
                                                .foregroundColor(i <= mood ? .blue : .secondary.opacity(0.3))
                                        }
                                    }
                                }
                            }
                            if let intensity = session.intensityRating {
                                VStack(spacing: 4) {
                                    Text("Intensität")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    HStack(spacing: 3) {
                                        ForEach(1...5, id: \.self) { i in
                                            Image(systemName: i <= intensity ? "star.fill" : "star")
                                                .foregroundColor(i <= intensity ? .orange : .secondary.opacity(0.3))
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // Notes
                    if !session.notes.isEmpty {
                        Divider()
                        HStack {
                            Text(session.notes)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.backgroundSecondary)
                )

                // Exercise breakdown
                if !exerciseGroups.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Übungen")
                            .font(.headline)
                            .padding(.horizontal, 4)

                        ForEach(exerciseGroups, id: \.0.id) { exercise, sets in
                            ExerciseHistoryBlock(exercise: exercise, sets: sets)
                        }
                    }
                }

                // Resume Button (if unfinished and not active)
                if session.endTime == nil && activeSessionId != session.id {
                    Button {
                        WorkoutManager.shared.resumeUnfinishedWorkout(session: session)
                        dismiss()
                    } label: {
                        Label("Workout fortsetzen", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.brand)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.top, 16)
                }

                // Delete Button
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Workout löschen", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.top, 8)
            }
            .padding()
            .padding(.bottom, 40)
        }
        .background(Color.backgroundPrimary)
        .navigationTitle("Workout Details")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Workout wirklich löschen?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                modelContext.delete(session)
                dismiss()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Diese Aktion kann nicht rückgängig gemacht werden.")
        }
    }
}

struct DetailStatBox: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline.monospacedDigit())
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ExerciseHistoryBlock: View {
    let exercise: Exercise
    let sets: [WorkoutSet]
    @AppStorage("zeroWeightIsBodyweight") private var zeroWeightIsBodyweight = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ExerciseIconView(exercise: exercise, size: 28)
                Text(exercise.name)
                    .font(.subheadline.bold())
                Spacer()
                Text("\(sets.count) Sätze")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            VStack(spacing: 8) {
                ForEach(sets.sorted(by: { $0.setNumber < $1.setNumber })) { set in
                    HStack(spacing: 16) {
                        Text("\(set.setNumber)")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Color.brand)
                            .clipShape(Circle())
                        
                        Spacer()
                        
                        HStack(spacing: 6) {
                            Image(systemName: "dumbbell.fill")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(set.actualWeight > 0 ? "\(set.actualWeight, specifier: "%.1f") kg" : (zeroWeightIsBodyweight ? "Körpergewicht" : "0 kg"))
                                .font(.subheadline.bold())
                                .fixedSize()
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("\(set.actualReps) Wdh")
                                .font(.subheadline.bold())
                        }
                        .frame(minWidth: 70, alignment: .leading)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(Color.backgroundPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.top, 4)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.backgroundSecondary)
        )
    }
}
