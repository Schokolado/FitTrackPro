import SwiftUI
import SwiftData
import Photos
import PhotosUI
import AVFoundation
import UIKit

// MARK: - Models & Options

enum WorkoutShareAspectRatio: String, CaseIterable, Identifiable {
    case card = "Feed (4:5)"
    case story = "Story (9:16)"

    var id: String { rawValue }

    var canvasSize: CGSize {
        switch self {
        case .card:  return CGSize(width: 360, height: 450)
        case .story: return CGSize(width: 360, height: 640)
        }
    }
}

enum WorkoutShareTheme: String, CaseIterable, Identifiable {
    case brand = "Vantage"
    case dark  = "Nacht"
    case light = "Minimal"

    var id: String { rawValue }
}

private struct IdentifiableShareImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct WorkoutShareData {
    struct ExerciseHighlight: Identifiable {
        let id: UUID
        let name: String
        let setsCount: Int
        let bestText: String
    }

    let title: String
    let date: Date
    let durationText: String
    let totalVolumeKg: Int
    let completedSetsCount: Int
    let exerciseCount: Int
    let burnedCalories: Int?
    let averageHeartRate: Int?
    let muscleTags: [String]
    let exerciseHighlights: [ExerciseHighlight]

    init(
        session: WorkoutSession,
        burnedCaloriesOverride: Double? = nil,
        averageHeartRateOverride: Double? = nil
    ) {
        self.title = session.plan?.name ?? "Freies Workout"
        self.date = session.startTime

        let end = session.endTime ?? Date()
        let totalSeconds = max(0, Int(end.timeIntervalSince(session.startTime)))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            self.durationText = "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            self.durationText = "\(minutes) Min."
        } else {
            self.durationText = "\(totalSeconds) Sek."
        }

        let completedSets = (session.sets ?? []).filter { $0.isCompleted }
        self.completedSetsCount = completedSets.count
        self.totalVolumeKg = Int(
            completedSets.reduce(0.0) { $0 + ($1.actualWeight * Double($1.actualReps)) }.rounded()
        )
        self.exerciseCount = Set(completedSets.compactMap { $0.exercise?.id }).count

        let resolvedCalories = burnedCaloriesOverride ?? session.burnedCalories
        if let kcal = resolvedCalories, kcal > 0 {
            self.burnedCalories = Int(kcal.rounded())
        } else {
            self.burnedCalories = nil
        }

        let resolvedHR = averageHeartRateOverride ?? session.averageHeartRate
        if let hr = resolvedHR, hr > 0 {
            self.averageHeartRate = Int(hr.rounded())
        } else {
            self.averageHeartRate = nil
        }

        self.muscleTags = StatisticsViewModel
            .muscleGroupBreakdown(in: session)
            .prefix(3)
            .map { $0.category }

        // Group completed sets by exercise in order of appearance
        var grouped: [(Exercise, [WorkoutSet])] = []
        var indexByExerciseId: [UUID: Int] = [:]
        for set in completedSets.sorted(by: { $0.timestamp < $1.timestamp }) {
            guard let exercise = set.exercise else { continue }
            if let idx = indexByExerciseId[exercise.id] {
                grouped[idx].1.append(set)
            } else {
                indexByExerciseId[exercise.id] = grouped.count
                grouped.append((exercise, [set]))
            }
        }

        self.exerciseHighlights = grouped.map { exercise, sets in
            let bestText: String
            if exercise.usesTimeInput {
                let maxVal = sets.map(\.actualReps).max() ?? 0
                bestText = "\(maxVal) \(exercise.effectiveTimeUnit)"
            } else if exercise.usesLevelInput {
                let maxLevel = Int((sets.map(\.actualWeight).max() ?? 0).rounded())
                let maxReps = sets.map(\.actualReps).max() ?? 0
                bestText = maxLevel > 0 ? "Lvl \(maxLevel)" : "\(maxReps) Wdh"
            } else {
                let maxWeight = sets.map(\.actualWeight).max() ?? 0
                if maxWeight > 0 {
                    let weightStr = maxWeight.truncatingRemainder(dividingBy: 1) == 0
                        ? "\(Int(maxWeight))"
                        : String(format: "%.1f", maxWeight)
                    bestText = "max. \(weightStr) kg"
                } else {
                    let maxReps = sets.map(\.actualReps).max() ?? 0
                    bestText = "\(maxReps) Wdh"
                }
            }

            return ExerciseHighlight(
                id: exercise.id,
                name: exercise.name,
                setsCount: sets.count,
                bestText: bestText
            )
        }
    }
}

// MARK: - Share Sheet Container

struct WorkoutShareSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let data: WorkoutShareData

    /// Keeps the optional selfie strictly in memory; never written to disk or SwiftData.
    @State private var selfiePhoto: UIImage?
    @State private var selectedPickerItem: PhotosPickerItem?
    @State private var mirrorPhoto = false

    @State private var aspectRatio: WorkoutShareAspectRatio = .card
    @State private var theme: WorkoutShareTheme = .brand
    @State private var showExercises = true
    @State private var showCalories = true
    @AppStorage(AppStorageKeys.shareWorkoutAutoSaveToPhotos) private var autoSaveToCameraRoll = false
    @State private var savedToPhotosBanner = false

    @State private var showingCamera = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showingAlert = false
    @State private var showSettingsAction = false

    @State private var sharePayload: IdentifiableShareImage?

    init(
        session: WorkoutSession,
        burnedCaloriesOverride: Double? = nil,
        averageHeartRateOverride: Double? = nil
    ) {
        self.data = WorkoutShareData(
            session: session,
            burnedCaloriesOverride: burnedCaloriesOverride,
            averageHeartRateOverride: averageHeartRateOverride
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                previewArea
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 10)

                controlsArea
            }
            .background(Color.backgroundPrimary)
            .navigationTitle("Workout teilen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") {
                        dismiss()
                    }
                }
            }
            .onChange(of: selectedPickerItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let rawData = try? await newItem.loadTransferable(type: Data.self),
                       let loadedImage = UIImage(data: rawData) {
                        let normalized = loadedImage.normalizedAndDownscaled(maxDimension: 2160)
                        await MainActor.run {
                            selfiePhoto = normalized
                            mirrorPhoto = false
                            selectedPickerItem = nil
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                SelfieCameraPicker { captured in
                    selfiePhoto = captured.normalizedAndDownscaled(maxDimension: 2160)
                    mirrorPhoto = false
                }
                .ignoresSafeArea()
            }
            .sheet(item: $sharePayload) { payload in
                ShareSheet(activityItems: [payload.image])
            }
            .alert(alertTitle, isPresented: $showingAlert) {
                if showSettingsAction {
                    Button("Einstellungen") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    private var previewArea: some View {
        GeometryReader { geo in
            let target = aspectRatio.canvasSize
            let scale = min(geo.size.width / target.width, geo.size.height / target.height)
            let scaledWidth = target.width * scale
            let scaledHeight = target.height * scale

            ZStack {
                cardContent
                    .frame(width: target.width, height: target.height)
                    .scaleEffect(scale)
                    .frame(width: scaledWidth, height: scaledHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity)
    }

    private var controlsArea: some View {
        VStack(spacing: 12) {
            // Photo controls: Front Camera, Library, Mirror & Clear
            HStack(spacing: 10) {
                Button {
                    openFrontCamera()
                } label: {
                    Label("Selfie", systemImage: "camera.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.backgroundSecondary)
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                PhotosPicker(selection: $selectedPickerItem, matching: .images) {
                    Label("Galerie", systemImage: "photo.on.rectangle")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.backgroundSecondary)
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if selfiePhoto != nil {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            mirrorPhoto.toggle()
                        }
                    } label: {
                        Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill")
                            .font(.subheadline)
                            .padding(10)
                            .background(mirrorPhoto ? Color.brand.opacity(0.15) : Color.backgroundSecondary)
                            .foregroundColor(mirrorPhoto ? .brand : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .accessibilityLabel("Foto spiegeln")

                    Button(role: .destructive) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selfiePhoto = nil
                            mirrorPhoto = false
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.subheadline)
                            .padding(10)
                            .background(Color.red.opacity(0.12))
                            .foregroundColor(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .accessibilityLabel("Foto entfernen")
                }
            }

            // Format + Theme (when no photo) + Option Toggles
            HStack(spacing: 10) {
                Picker("Format", selection: $aspectRatio) {
                    ForEach(WorkoutShareAspectRatio.allCases) { ratio in
                        Text(ratio.rawValue).tag(ratio)
                    }
                }
                .pickerStyle(.segmented)
            }

            HStack(spacing: 8) {
                if selfiePhoto == nil {
                    Menu {
                        ForEach(WorkoutShareTheme.allCases) { option in
                            Button {
                                theme = option
                            } label: {
                                if theme == option {
                                    Label(option.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(option.rawValue)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "paintpalette.fill")
                            Text(theme.rawValue)
                        }
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.backgroundSecondary)
                        .foregroundColor(.primary)
                        .clipShape(Capsule())
                    }
                }

                if !data.exerciseHighlights.isEmpty {
                    optionChip(title: "Übungen", isActive: $showExercises)
                }

                if data.burnedCalories != nil {
                    optionChip(title: "Kalorien", isActive: $showCalories)
                }

                Spacer()
            }

            Toggle(isOn: $autoSaveToCameraRoll) {
                Label("Automatisch in Fotos sichern", systemImage: "square.and.arrow.down")
                    .font(.subheadline)
            }
            .tint(.brand)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if savedToPhotosBanner {
                Label("In deiner Fotos-Mediathek gesichert", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.green)
                    .transition(.opacity)
            }

            // Primary Share CTA
            Button {
                renderAndShare()
            } label: {
                Label("Grafik teilen", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.brand)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Color.backgroundCard
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func optionChip(title: String, isActive: Binding<Bool>) -> some View {
        Button {
            isActive.wrappedValue.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isActive.wrappedValue ? "checkmark.circle.fill" : "circle")
                Text(title)
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(isActive.wrappedValue ? Color.brand.opacity(0.15) : Color.backgroundSecondary)
            .foregroundColor(isActive.wrappedValue ? .brand : .secondary)
            .clipShape(Capsule())
        }
    }

    private var cardContent: WorkoutShareCardContent {
        WorkoutShareCardContent(
            data: data,
            photo: selfiePhoto,
            mirrorPhoto: mirrorPhoto,
            aspectRatio: aspectRatio,
            theme: theme,
            showExercises: showExercises,
            showCalories: showCalories
        )
    }

    private func openFrontCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            alertTitle = "Kamera nicht verfügbar"
            alertMessage = "Auf diesem Gerät steht keine Kamera zur Verfügung. Du kannst stattdessen ein Foto aus deiner Galerie auswählen."
            showSettingsAction = false
            showingAlert = true
            return
        }

        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            showingCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showingCamera = true
                    } else {
                        alertTitle = "Kamerazugriff verweigert"
                        alertMessage = "Erlaube den Kamerazugriff in den Einstellungen, um ein Workout-Selfie aufzunehmen."
                        showSettingsAction = true
                        showingAlert = true
                    }
                }
            }
        case .denied, .restricted:
            alertTitle = "Kamerazugriff deaktiviert"
            alertMessage = "Bitte aktiviere den Kamerazugriff in den iOS-Einstellungen oder wähle ein Foto aus der Galerie."
            showSettingsAction = true
            showingAlert = true
        @unknown default:
            showingCamera = true
        }
    }

    @MainActor
    private func renderAndShare() {
        let target = aspectRatio.canvasSize
        let exportView = cardContent.frame(width: target.width, height: target.height)
        let renderer = ImageRenderer(content: exportView)
        renderer.scale = 3.0
        renderer.isOpaque = true

        guard let uiImage = renderer.uiImage else { return }

        if autoSaveToCameraRoll {
            Task {
                let saved = await saveImageToPhotoLibrary(uiImage)
                await MainActor.run {
                    withAnimation {
                        savedToPhotosBanner = saved
                    }
                    sharePayload = IdentifiableShareImage(image: uiImage)
                }
            }
        } else {
            savedToPhotosBanner = false
            sharePayload = IdentifiableShareImage(image: uiImage)
        }
    }

    private func saveImageToPhotoLibrary(_ image: UIImage) async -> Bool {
        var status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if status == .notDetermined {
            status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        }
        guard status == .authorized || status == .limited else {
            return false
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            return true
        } catch {
            return false
        }
    }
}

// MARK: - Share Card Canvas View (Rendered both in Preview & ImageRenderer)

struct WorkoutShareCardContent: View {
    let data: WorkoutShareData
    let photo: UIImage?
    let mirrorPhoto: Bool
    let aspectRatio: WorkoutShareAspectRatio
    let theme: WorkoutShareTheme
    let showExercises: Bool
    let showCalories: Bool

    private var isLightInk: Bool {
        photo != nil || theme != .light
    }

    private var primaryInk: Color {
        isLightInk ? .white : Color(red: 0.08, green: 0.10, blue: 0.14)
    }

    private var secondaryInk: Color {
        isLightInk ? Color.white.opacity(0.78) : Color(red: 0.35, green: 0.39, blue: 0.46)
    }

    private var surfaceFill: Color {
        if photo != nil {
            return Color.black.opacity(0.38)
        }
        return isLightInk ? Color.white.opacity(0.11) : Color.black.opacity(0.05)
    }

    private var surfaceBorder: Color {
        isLightInk ? Color.white.opacity(0.20) : Color.black.opacity(0.08)
    }

    private var accentColor: Color {
        if photo != nil { return Color.cyan }
        switch theme {
        case .brand: return Color.cyan
        case .dark:  return Color.cyan
        case .light: return Color.blue
        }
    }

    private var maxVisibleExercises: Int {
        switch (aspectRatio, photo != nil) {
        case (.story, true):  return 4
        case (.story, false): return 6
        case (.card, true):   return 3
        case (.card, false):  return 4
        }
    }

    var body: some View {
        let size = aspectRatio.canvasSize

        ZStack {
            backgroundLayer(size: size)

            VStack(alignment: .leading, spacing: aspectRatio == .story ? 16 : 12) {
                headerRow

                if photo != nil {
                    // Keep the upper part of the selfie unobstructed
                    Spacer(minLength: 0)
                } else {
                    Spacer(minLength: 4)
                }

                titleAndTags

                statsGrid

                if showExercises && !data.exerciseHighlights.isEmpty {
                    exercisesSection
                }

                if photo == nil {
                    Spacer(minLength: 4)
                }

                footerRow
            }
            .padding(.horizontal, 22)
            .padding(.vertical, aspectRatio == .story ? 28 : 22)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    @ViewBuilder
    private func backgroundLayer(size: CGSize) -> some View {
        if let photo {
            ZStack {
                Color.black
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(x: mirrorPhoto ? -1 : 1, y: 1)
                    .frame(width: size.width, height: size.height)
                    .clipped()

                // Top scrim for brand/date contrast
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [Color.black.opacity(0.58), Color.black.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: size.height * 0.22)

                    Spacer(minLength: 0)

                    // Bottom gradient scrim for stats readability over any selfie
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.0),
                            Color.black.opacity(0.55),
                            Color.black.opacity(0.86)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: size.height * (showExercises ? 0.62 : 0.46))
                }
            }
        } else {
            ZStack {
                LinearGradient(
                    colors: backgroundGradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Subtle editorial geometric glow
                Circle()
                    .fill(glowColor.opacity(0.24))
                    .frame(width: size.width * 0.85, height: size.width * 0.85)
                    .offset(x: size.width * 0.34, y: -size.height * 0.32)

                Circle()
                    .fill(glowColor.opacity(0.14))
                    .frame(width: size.width * 0.65, height: size.width * 0.65)
                    .offset(x: -size.width * 0.38, y: size.height * 0.36)
            }
        }
    }

    private var backgroundGradientColors: [Color] {
        switch theme {
        case .brand:
            return [
                Color(red: 0.04, green: 0.11, blue: 0.26),
                Color(red: 0.06, green: 0.25, blue: 0.56),
                Color(red: 0.04, green: 0.14, blue: 0.34)
            ]
        case .dark:
            return [
                Color(red: 0.07, green: 0.08, blue: 0.11),
                Color(red: 0.12, green: 0.14, blue: 0.19),
                Color(red: 0.06, green: 0.07, blue: 0.10)
            ]
        case .light:
            return [
                Color(red: 0.96, green: 0.97, blue: 0.99),
                Color(red: 0.90, green: 0.93, blue: 0.97)
            ]
        }
    }

    private var glowColor: Color {
        switch theme {
        case .brand: return .cyan
        case .dark:  return .blue
        case .light: return .blue
        }
    }

    private var headerRow: some View {
        HStack(alignment: .center) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.caption.bold())
                    .foregroundColor(accentColor)
                Text("VANTAGE")
                    .font(.caption.weight(.heavy))
                    .tracking(1.6)
                    .foregroundColor(primaryInk)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(surfaceFill)
            .overlay(
                Capsule().strokeBorder(surfaceBorder, lineWidth: 1)
            )
            .clipShape(Capsule())

            Spacer()

            Text(data.date, format: .dateTime.day().month(.abbreviated).year().hour().minute())
                .font(.caption2.weight(.semibold))
                .foregroundColor(secondaryInk)
                .shadow(color: photo != nil ? .black.opacity(0.6) : .clear, radius: 4)
        }
    }

    private var titleAndTags: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(data.title)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundColor(primaryInk)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            if !data.muscleTags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(data.muscleTags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(primaryInk)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(accentColor.opacity(photo != nil ? 0.30 : 0.20))
                            .overlay(
                                Capsule().strokeBorder(accentColor.opacity(0.45), lineWidth: 0.8)
                            )
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var statsGrid: some View {
        let hasCalories = showCalories && data.burnedCalories != nil
        let columns = [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]

        return LazyVGrid(columns: columns, spacing: 8) {
            statTile(icon: "clock.fill", label: "Dauer", value: data.durationText)
            statTile(icon: "scalemass.fill", label: "Volumen", value: formattedVolume(data.totalVolumeKg))
            statTile(
                icon: "square.stack.3d.up.fill",
                label: "Umfang",
                value: "\(data.completedSetsCount) Sätze • \(data.exerciseCount) Üb."
            )
            if hasCalories, let kcal = data.burnedCalories {
                let calValue = data.averageHeartRate != nil
                    ? "\(kcal) kcal • \(data.averageHeartRate!) bpm"
                    : "\(kcal) kcal"
                statTile(icon: "flame.fill", label: "Verbrannt", value: calValue)
            } else {
                statTile(icon: "dumbbell.fill", label: "Übungen", value: "\(data.exerciseCount)")
            }
        }
    }

    private func statTile(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(accentColor)
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(secondaryInk)
            }
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
                .foregroundColor(primaryInk)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(surfaceFill)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(surfaceBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var exercisesSection: some View {
        let visible = Array(data.exerciseHighlights.prefix(maxVisibleExercises))
        let remaining = max(0, data.exerciseHighlights.count - visible.count)

        return VStack(alignment: .leading, spacing: 5) {
            ForEach(visible) { item in
                HStack(spacing: 8) {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 5, height: 5)
                    Text(item.name)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(primaryInk)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text("\(item.setsCount)× · \(item.bestText)")
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(secondaryInk)
                        .fixedSize()
                }
            }
            if remaining > 0 {
                Text("+ \(remaining) weitere Übung\(remaining == 1 ? "" : "en")")
                    .font(.caption2)
                    .foregroundColor(secondaryInk)
                    .padding(.leading, 13)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(surfaceFill)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(surfaceBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var footerRow: some View {
        HStack {
            Text("Workout abgeschlossen")
                .font(.caption2.weight(.medium))
                .foregroundColor(secondaryInk)
            Spacer()
            Text("vantage.fitness")
                .font(.caption2.bold())
                .foregroundColor(accentColor)
        }
    }

    private func formattedVolume(_ kg: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "de_DE")
        let numberStr = formatter.string(from: NSNumber(value: kg)) ?? "\(kg)"
        return "\(numberStr) kg"
    }
}

// MARK: - Front Camera Capture Helper (No Disk Persistence)

private struct SelfieCameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onImagePicked: (UIImage) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        if UIImagePickerController.isCameraDeviceAvailable(.front) {
            picker.cameraDevice = .front
        }
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: SelfieCameraPicker

        init(_ parent: SelfieCameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

private extension UIImage {
    /// Normalizes orientation to `.up` and downscales oversized photos in memory for smooth `ImageRenderer` export.
    func normalizedAndDownscaled(maxDimension: CGFloat) -> UIImage {
        let longestSide = max(size.width, size.height)
        let scaleFactor = longestSide > maxDimension ? (maxDimension / longestSide) : 1.0
        let targetSize = CGSize(
            width: (size.width * scaleFactor).rounded(),
            height: (size.height * scaleFactor).rounded()
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
