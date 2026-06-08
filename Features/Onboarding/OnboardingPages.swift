import SwiftUI
import SwiftData

// MARK: - Shared Onboarding UI Helpers

struct OnboardingPageContainer<Content: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let gradientColors: [Color]
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top icon + title
                VStack(spacing: 16) {
                    Image(systemName: systemImage)
                        .font(.system(size: 52, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.top, 80)

                    Text(title)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                // Content card
                VStack(spacing: 0) {
                    content
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(.regularMaterial)
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}

struct OnboardingNextButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.headline)
                Image(systemName: "arrow.right")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundColor(.white)
            .background(Color.brand)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(.top, 8)
    }
}

// MARK: - Page 1: Welcome

struct OnboardingWelcomePage: View {
    @Binding var currentPage: Int

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 16) {
                    Image("VigrLogoTransparent")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 260, height: 260)

                    Text("Vigr")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundColor(.primary)

                    Text("Dein persönlicher Fitness-\nBegleiter für jeden Tag.")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                Button(action: { withAnimation { currentPage = 1 } }) {
                    HStack(spacing: 10) {
                        Text("Jetzt loslegen")
                            .font(.headline)
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .foregroundColor(.white)
                    .background(Color.brand)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Color.brand.opacity(0.3), radius: 10, y: 5)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 80)
            }
        }
    }
}

// MARK: - Page 2: Profile

struct OnboardingProfilePage: View {
    @Binding var currentPage: Int
    @AppStorage(AppStorageKeys.userName) private var userName = ""
    @AppStorage(AppStorageKeys.userBiologicalSex) private var userSex = "other"

    // Birth date stored as TimeInterval
    @AppStorage(AppStorageKeys.userBirthDate) private var birthDateInterval: Double = 0
    @State private var birthDate: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()

    var body: some View {
        OnboardingPageContainer(
            title: "Dein Profil",
            subtitle: "Damit wir dich besser kennenlernen",
            systemImage: "person.circle",
            gradientColors: [Color(hue: 0.62, saturation: 0.7, brightness: 0.85), Color(hue: 0.55, saturation: 0.8, brightness: 0.7)]
        ) {
            VStack(spacing: 20) {
                // Name
                VStack(alignment: .leading, spacing: 6) {
                    Label("Dein Name", systemImage: "person")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    TextField("z.B. Max", text: $userName)
                        .textContentType(.givenName)
                        .padding(12)
                        .background(Color.backgroundPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // Birthdate
                VStack(alignment: .leading, spacing: 6) {
                    Label("Geburtsdatum", systemImage: "calendar")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    DatePicker("", selection: $birthDate, in: ...Date(), displayedComponents: .date)
                        .labelsHidden()
                        .onChange(of: birthDate) { _, new in
                            birthDateInterval = new.timeIntervalSince1970
                        }
                        .onAppear {
                            if birthDateInterval > 0 {
                                birthDate = Date(timeIntervalSince1970: birthDateInterval)
                            }
                        }
                }

                // Biological Sex
                VStack(alignment: .leading, spacing: 6) {
                    Label("Biologisches Geschlecht", systemImage: "person.2")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    Picker("", selection: $userSex) {
                        Text("Männlich").tag("male")
                        Text("Weiblich").tag("female")
                        Text("Divers").tag("other")
                    }
                    .pickerStyle(.segmented)
                }

                OnboardingNextButton(label: "Weiter") {
                    birthDateInterval = birthDate.timeIntervalSince1970
                    withAnimation { currentPage = 2 }
                }
            }
        }
    }
}

struct OnboardingBodyPage: View {
    @Binding var currentPage: Int
    @AppStorage(AppStorageKeys.userHeightCm) private var heightCm: Double = 175
    @AppStorage(AppStorageKeys.onboardingWeightKg) private var savedOnboardingWeightKg: Double = 0.0
    @Environment(\.modelContext) private var modelContext
    @State private var weightKg: Double = 75

    var body: some View {
        OnboardingPageContainer(
            title: "Körperdaten",
            subtitle: "Für genaue Berechnungen",
            systemImage: "scalemass",
            gradientColors: [Color(hue: 0.35, saturation: 0.6, brightness: 0.7), Color(hue: 0.45, saturation: 0.7, brightness: 0.6)]
        ) {
            VStack(spacing: 20) {
                // Height
                VStack(alignment: .leading, spacing: 6) {
                    Label("Körpergröße", systemImage: "arrow.up.and.down")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    HStack {
                        Slider(value: $heightCm, in: 140...220, step: 1)
                            .tint(.brand)
                        HStack(spacing: 4) {
                            TextField("", value: $heightCm, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(.headline.monospacedDigit())
                            Text("cm")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 80, alignment: .trailing)
                    }
                }

                // Weight
                VStack(alignment: .leading, spacing: 6) {
                    Label("Aktuelles Gewicht", systemImage: "scalemass")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    HStack {
                        Slider(value: $weightKg, in: 30...200, step: 0.5)
                            .tint(.brand)
                        HStack(spacing: 4) {
                            TextField("", value: $weightKg, format: .number.precision(.fractionLength(1)))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(.headline.monospacedDigit())
                            Text("kg")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 80, alignment: .trailing)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text("Dieses Gewicht wird als erster Eintrag in deinem Gewichtstagebuch gespeichert.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                OnboardingNextButton(label: "Weiter") {
                    // Save as first WeightEntry
                    let entry = WeightEntry(weightKg: weightKg, timestamp: Date(), notes: "Erster Eintrag (Onboarding)")
                    modelContext.insert(entry)
                    
                    savedOnboardingWeightKg = weightKg
                    
                    // Write weight to Apple Health if no entry exists for today
                    Task {
                        if HealthKitService.shared.isAvailable {
                            try? await HealthKitService.shared.exportWeight(entry: entry)
                            entry.syncedToHealthKit = true
                        }
                    }
                    
                    withAnimation { currentPage = 3 }
                }
            }
        }
    }
}

// MARK: - Page 4: Goals

struct OnboardingGoalsPage: View {
    @Binding var currentPage: Int
    @AppStorage(AppStorageKeys.dailyCalorieGoal) private var calorieGoal: Double = 2500
    @AppStorage("nutritionGoalProtein") private var proteinGoal: Double = 150
    @AppStorage("nutritionGoalCarbs") private var carbsGoal: Double = 250
    @AppStorage("nutritionGoalFat") private var fatGoal: Double = 70
    @AppStorage(AppStorageKeys.dailyStepGoal) private var stepGoal: Int = 10000

    var body: some View {
        OnboardingPageContainer(
            title: "Deine Ziele",
            subtitle: "Passe alles auf dich an",
            systemImage: "target",
            gradientColors: [Color(hue: 0.08, saturation: 0.7, brightness: 0.85), Color(hue: 0.02, saturation: 0.8, brightness: 0.75)]
        ) {
            VStack(spacing: 16) {
                // Calories
                GoalSliderRow(
                    label: "Kalorien / Tag",
                    icon: "flame.fill",
                    value: $calorieGoal,
                    range: 1200...5000,
                    step: 50,
                    unit: "kcal"
                )

                Divider()

                GoalSliderRow(
                    label: "Protein / Tag",
                    icon: "p.circle.fill",
                    value: $proteinGoal,
                    range: 50...300,
                    step: 5,
                    unit: "g"
                )

                GoalSliderRow(
                    label: "Kohlenhydrate / Tag",
                    icon: "k.circle.fill",
                    value: $carbsGoal,
                    range: 50...700,
                    step: 10,
                    unit: "g"
                )

                GoalSliderRow(
                    label: "Fett / Tag",
                    icon: "f.circle.fill",
                    value: $fatGoal,
                    range: 20...200,
                    step: 5,
                    unit: "g"
                )

                Divider()

                // Steps
                VStack(alignment: .leading, spacing: 6) {
                    Label("Schritte / Tag", systemImage: "figure.walk")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    HStack {
                        Slider(value: Binding(
                            get: { Double(stepGoal) },
                            set: { stepGoal = Int($0) }
                        ), in: 2000...30000, step: 500)
                        .tint(.brand)
                        TextField("", value: Binding(
                            get: { stepGoal },
                            set: { stepGoal = $0 }
                        ), format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .font(.headline.monospacedDigit())
                        .frame(width: 80, alignment: .trailing)
                    }
                }

                OnboardingNextButton(label: "Fast fertig!") {
                    withAnimation { currentPage = 4 }
                }
            }
        }
    }
}

struct GoalSliderRow: View {
    let label: String
    let icon: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: icon)
                .font(.caption.bold())
                .foregroundColor(.secondary)
            HStack {
                Slider(value: $value, in: range, step: step)
                    .tint(.brand)
                HStack(spacing: 4) {
                    TextField("", value: $value, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.subheadline.monospacedDigit())
                    Text(unit)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(width: 85, alignment: .trailing)
            }
        }
    }
}

// MARK: - Page 5: Finish

struct OnboardingFinishPage: View {
    let onComplete: (Bool) -> Void
    @State private var showCheckmark = false
    @State private var showContent = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.brand, Color(hue: 0.4, saturation: 0.7, brightness: 0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(.white.opacity(0.15))
                        .frame(width: 140, height: 140)

                    if showCheckmark {
                        Image(systemName: "checkmark")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundColor(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .onAppear {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.3)) {
                        showCheckmark = true
                    }
                    withAnimation(.easeOut.delay(0.6)) {
                        showContent = true
                    }
                }

                if showContent {
                    VStack(spacing: 12) {
                        Text("Alles bereit!")
                            .font(.system(size: 38, weight: .black, design: .rounded))
                            .foregroundColor(.white)

                        Text("Dein persönliches Profil ist gespeichert.\nLass uns deine Fitness tracken.")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer()

                if showContent {
                    VStack(spacing: 16) {
                        Button(action: { onComplete(true) }) {
                            HStack(spacing: 10) {
                                Text("Mit Apple Health starten")
                                    .font(.headline)
                                Image(systemName: "heart.text.square.fill")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .foregroundColor(.brand)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
                        }
                        
                        Button(action: {
                            onComplete(false)
                        }) {
                            Text("Manuell eintragen (ohne Apple Health)")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.vertical, 8)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 60)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }
}

// MARK: - Page -1: Welcome Back (Cloud Sync)

struct OnboardingWelcomeBackPage: View {
    @Binding var currentPage: Int
    var onAcceptCloudData: () -> Void
    
    @State private var cloudName = ""
    @State private var cloudHeight = 0.0
    @State private var cloudWeight = 0.0
    @State private var cloudCalories = 0.0
    @State private var cloudSteps = 0
    @State private var cloudBirthday = 0.0
    @State private var cloudProtein = 0.0
    @State private var cloudCarbs = 0.0
    @State private var cloudFat = 0.0
    
    private var formattedBirthday: String {
        guard cloudBirthday > 0 else { return "Nicht gesetzt" }
        let date = Date(timeIntervalSince1970: cloudBirthday)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: date)
    }
    
    var body: some View {
        OnboardingPageContainer(
            title: "Willkommen zurück!",
            subtitle: "Wir haben ein gesichertes Profil in deiner iCloud gefunden.",
            systemImage: "icloud.and.arrow.down",
            gradientColors: [Color.brand, Color.brandSecondary]
        ) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    if !cloudName.isEmpty {
                        Text("Hallo \(cloudName) 👋")
                            .font(.title2.bold())
                    }
                    
                    VStack(spacing: 12) {
                        HStack {
                            Text("Geburtstag")
                            Spacer()
                            Text(formattedBirthday).bold()
                        }
                        Divider()
                        HStack {
                            Text("Größe")
                            Spacer()
                            Text("\(cloudHeight, specifier: "%.0f") cm").bold()
                        }
                        Divider()
                        HStack {
                            Text("Gewicht")
                            Spacer()
                            Text("\(cloudWeight, specifier: "%.1f") kg").bold()
                        }
                        Divider()
                        HStack {
                            Text("Schrittziel")
                            Spacer()
                            Text("\(cloudSteps)").bold()
                        }
                        Divider()
                        HStack {
                            Text("Kalorien")
                            Spacer()
                            Text("\(cloudCalories, specifier: "%.0f") kcal").bold()
                        }
                        Divider()
                        HStack {
                            Text("Makros")
                            Spacer()
                            Text("K \(cloudCarbs, specifier: "%.0f")g • P \(cloudProtein, specifier: "%.0f")g • F \(cloudFat, specifier: "%.0f")g")
                                .font(.footnote.bold())
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.backgroundPrimary)
                    .cornerRadius(12)
                }
                .padding(.bottom, 24)
            }
            
            // Buttons pinned to the bottom
            VStack(spacing: 12) {
                Button(action: {
                    onAcceptCloudData()
                }) {
                    HStack {
                        Text("Daten übernehmen & Starten")
                            .font(.headline)
                        Image(systemName: "checkmark.circle.fill")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundColor(.white)
                    .background(Color.brand)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                
                Button(action: {
                    withAnimation { currentPage = 0 }
                }) {
                    Text("Ignorieren & neu eingeben")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                }
            }
            .padding(.top, 8)
            .onAppear {
                let service = CloudProfileService.shared
                cloudName = service.getCloudName()
                cloudHeight = service.getCloudHeight()
                cloudWeight = service.getCloudWeight()
                cloudCalories = service.getCloudCalorieGoal()
                cloudSteps = service.getCloudStepGoal()
                cloudBirthday = service.getCloudBirthday()
                cloudProtein = service.getCloudProtein()
                cloudCarbs = service.getCloudCarbs()
                cloudFat = service.getCloudFat()
            }
        }
    }
}
