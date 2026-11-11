import SwiftUI
import SwiftData

struct ExerciseDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var exercise: Exercise
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var showingEditForm = false
    @State private var showingFullScreenViewer = false
    @State private var selectedImageIndex: Int = 0
    @State private var showingResetNotesAlert = false
    
    private var trackingChipLabel: String {
        if exercise.usesLevelInput {
            return "Level • \(exercise.effectiveTimeUnit)"
        }
        if exercise.usesTimeInput {
            return exercise.usesWeightInput
                ? "Dauer (\(exercise.effectiveTimeUnit)) + kg"
                : "Dauer (\(exercise.effectiveTimeUnit))"
        }
        return "Wdh. & kg"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                // Hero Header: Farb-Icon + voller Übungsname + kompakte Meta-Chips
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 14) {
                        let catColor = themeManager.color(for: exercise.category)
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [catColor.opacity(0.75), catColor],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 52, height: 52)
                            ExerciseIconView(exercise: exercise, size: 24)
                                .foregroundColor(.white)
                        }
                        .shadow(color: catColor.opacity(0.25), radius: 5, y: 2)

                        Text(exercise.name)
                            .font(.title2.bold())
                            .foregroundStyle(Color.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Label("\(Int(exercise.defaultRestDuration))s Pause", systemImage: "timer")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.backgroundSecondary)
                                .clipShape(Capsule())

                            Label(trackingChipLabel, systemImage: exercise.usesTimeInput ? "clock" : "arrow.triangle.2.circlepath")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.backgroundSecondary)
                                .clipShape(Capsule())

                            if exercise.isCustom {
                                Label("Eigene Übung", systemImage: "person.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(themeManager.color(for: exercise.category))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(themeManager.color(for: exercise.category).opacity(0.14))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                ExerciseHistoryPreview(exercise: exercise)
                
                let defaultNote = SeedDataService.shared.defaultExerciseNotes(for: exercise.name)
                
                if exercise.notes.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Button(action: { showingEditForm = true }) {
                            HStack {
                                Image(systemName: "note.text.badge.plus")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                                Text("Notizen hinzufügen")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if defaultNote != nil {
                            Divider()
                            Button(action: { showingResetNotesAlert = true }) {
                                Label("Standard-Notiz wiederherstellen", systemImage: "arrow.counterclockwise")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.brand)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
                    .padding(.horizontal)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        RichNotesCard(
                            title: "Notizen",
                            text: exercise.notes,
                            onEdit: { showingEditForm = true }
                        )

                        if let def = defaultNote, exercise.notes != def {
                            Button(action: { showingResetNotesAlert = true }) {
                                Label("Auf Werkseinstellungen zurücksetzen", systemImage: "arrow.counterclockwise")
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.brand)
                            }
                            .padding(.leading, 4)
                        }
                    }
                    .padding(.horizontal)
                }
                
                if let url = exercise.externalVideoURL {
                    Button(action: { openVideoURL(url) }) {
                        HStack {
                            Image(systemName: "play.rectangle.fill")
                                .font(.title2)
                                .foregroundColor(.red)
                            Text("Video-Tutorial ansehen")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
                    .padding(.horizontal)
                } else {
                    Button(action: { showingEditForm = true }) {
                        HStack {
                            Image(systemName: "video.badge.plus")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            Text("Video-Tutorial hinzufügen")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
                    .padding(.horizontal)
                }
                
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Bilder")
                        .font(.headline)
                        .padding(.horizontal)
                        
                    if !exercise.localMediaPaths.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Spacing.sm) {
                                ForEach(Array(exercise.localMediaPaths.enumerated()), id: \.offset) { index, path in
                                    if let image = MediaStorageService.shared.loadImage(named: path) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 150, height: 150)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .onTapGesture {
                                                selectedImageIndex = index
                                                showingFullScreenViewer = true
                                            }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    } else {
                        Button(action: { showingEditForm = true }) {
                            VStack(spacing: Spacing.sm) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 32))
                                    .foregroundColor(.secondary)
                                Text("Bilder hinzufügen")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 150, height: 150)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
                            )
                        }
                        .padding(.horizontal)
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.bottom)
            }
            .padding(.top)
        }
        .navigationTitle(exercise.category)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingEditForm = true
                    } label: {
                        Label("Bearbeiten", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive) {
                        modelContext.delete(exercise)
                        dismiss()
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditForm) {
            NavigationStack {
                ExerciseFormView(exerciseToEdit: exercise)
            }
        }
        .fullScreenCover(isPresented: $showingFullScreenViewer) {
            FullScreenImageViewer(mediaPaths: exercise.localMediaPaths, initialIndex: selectedImageIndex)
        }
        .alert("Notiz zurücksetzen?", isPresented: $showingResetNotesAlert) {
            Button("Abbrechen", role: .cancel) { }
            Button("Zurücksetzen", role: .destructive) {
                if let def = SeedDataService.shared.defaultExerciseNotes(for: exercise.name) {
                    exercise.notes = def
                    try? modelContext.save()
                }
            }
        } message: {
            Text("Möchtest du die Notizen für diese Übung auf die Standardbeschreibung (Werkseinstellungen) zurücksetzen?")
        }
    }
    
    private func openVideoURL(_ url: URL) {
        var appURL: URL? = nil
        let urlString = url.absoluteString
        
        if urlString.contains("youtube.com") || urlString.contains("youtu.be") {
            let schemeReplaced = urlString
                .replacingOccurrences(of: "https://", with: "youtube://")
                .replacingOccurrences(of: "http://", with: "youtube://")
            
            if urlString.contains("youtu.be/") {
                if let id = urlString.components(separatedBy: "youtu.be/").last {
                    appURL = URL(string: "youtube://watch?v=\(id)")
                }
            } else {
                appURL = URL(string: schemeReplaced)
            }
        }
        
        if let appURL = appURL {
            UIApplication.shared.open(appURL, options: [:]) { success in
                if !success {
                    // Fallback to web browser if YouTube app is not installed
                    UIApplication.shared.open(url)
                }
            }
        } else {
            UIApplication.shared.open(url)
        }
    }
}

struct ExerciseHistoryPreview: View {
    let exercise: Exercise
    
    @Query private var pastSets: [WorkoutSet]
    @State private var showingHistory = false
    
    init(exercise: Exercise) {
        self.exercise = exercise
        let exerciseId = exercise.id
        
        _pastSets = Query(
            filter: #Predicate<WorkoutSet> { set in
                set.exercise?.id == exerciseId && set.isCompleted == true
            },
            sort: \.timestamp, order: .reverse
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Historie")
                    .font(.headline)
                Spacer()
                Button(action: { showingHistory = true }) {
                    Text("Mehr")
                        .font(.subheadline)
                        .foregroundColor(.brand)
                }
            }
            
            if pastSets.isEmpty {
                Text("Noch keine Einträge.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            } else {
                ForEach(pastSets.prefix(3)) { set in
                    HStack {
                        Text(set.timestamp, format: .dateTime.day().month().year())
                            .font(.subheadline)
                        Spacer()
                        let durationUnit = exercise.effectiveTimeUnit
                        let detailText: String = {
                            if exercise.usesLevelInput {
                                return "Lvl \(Int(set.actualWeight)) • \(set.actualReps) \(durationUnit)"
                            } else if exercise.usesTimeInput {
                                if (exercise.usesWeightInput || set.actualWeight > 0) && set.actualWeight > 0 {
                                    return String(format: "%.1f kg • %d %@", set.actualWeight, set.actualReps, durationUnit)
                                }
                                return "\(set.actualReps) \(durationUnit)"
                            } else {
                                return String(format: "%.1f kg × %d", set.actualWeight, set.actualReps)
                            }
                        }()
                        Text(detailText)
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .padding(.horizontal)
        .sheet(isPresented: $showingHistory) {
            NavigationStack {
                ExerciseHistoryView(exercise: exercise)
            }
        }
    }
}
