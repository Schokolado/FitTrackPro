import SwiftUI
import SwiftData

struct AppRouter: View {
    @Environment(WorkoutManager.self) private var workoutManager
    @State private var showingWorkoutSession = false
    @AppStorage("mainSelectedTab") private var selectedTab = 0
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<WorkoutSession> { $0.endTime == nil }, sort: \.startTime, order: .reverse) private var unfinishedWorkouts: [WorkoutSession]
    @State private var showingResumeWorkoutAlert = false
    @State private var showingDiscardConfirmationAlert = false
    @State private var sessionToResume: WorkoutSession?
    
    private var tabSelection: Binding<Int> {
        Binding(
            get: { selectedTab },
            set: { newTab in
                if newTab == selectedTab {
                    NotificationCenter.default.post(name: NSNotification.Name("TabReselected"), object: newTab)
                }
                selectedTab = newTab
            }
        )
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: tabSelection) {
                DashboardView(selectedTab: $selectedTab)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.backgroundPrimary)
                    .globalMiniPlayerSafeArea(isActive: workoutManager.activeViewModel != nil)
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag(0)
                
                TrainingMainView()
                    .globalMiniPlayerSafeArea(isActive: workoutManager.activeViewModel != nil)
                    .tabItem {
                        Label("Training", systemImage: "dumbbell.fill")
                    }
                    .tag(1)
                
                NutritionDashboardView()
                    .globalMiniPlayerSafeArea(isActive: workoutManager.activeViewModel != nil)
                    .tabItem {
                        Label("Ernährung", systemImage: "fork.knife")
                    }
                    .tag(2)
            }
            .tint(.brand)
            .preferredColorScheme(appTheme.colorScheme)
            
            if let vm = workoutManager.activeViewModel, !showingWorkoutSession {
                WorkoutMiniPlayerView(viewModel: vm, planName: workoutManager.activeSession?.plan?.name) {
                    showingWorkoutSession = true
                }
                .padding(.bottom, 49) // Approximate tab bar height padding
            }
        }
        .fullScreenCover(isPresented: $showingWorkoutSession) {
            if let session = workoutManager.activeSession, let vm = workoutManager.activeViewModel {
                WorkoutSessionView(viewModel: vm, session: session)
            }
        }
        .onChange(of: workoutManager.activeSession) { oldValue, newValue in
            if newValue != nil {
                showingWorkoutSession = true
            }
        }
        .onOpenURL { url in
            if url.host == "add-meal" {
                selectedTab = 2
                NotificationCenter.default.post(name: NSNotification.Name("ResetNutritionToToday"), object: nil)
                NotificationCenter.default.post(name: NSNotification.Name("OpenNutritionAddEntry"), object: nil)
            } else if url.host == "start-workout" {
                selectedTab = 1
                NotificationCenter.default.post(name: NSNotification.Name("OpenWorkoutSelection"), object: nil)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenActiveWorkout"))) { _ in
            if workoutManager.isWorkoutActive {
                showingWorkoutSession = true
            }
        }
        .onAppear {
            if !workoutManager.isWorkoutActive {
                if let session = unfinishedWorkouts.first {
                    sessionToResume = session
                    showingResumeWorkoutAlert = true
                }
            }
        }
        .alert("Abgebrochenes Workout", isPresented: $showingResumeWorkoutAlert) {
            Button("Fortsetzen") {
                if let session = sessionToResume {
                    workoutManager.resumeUnfinishedWorkout(session: session)
                }
            }
            Button("Verwerfen", role: .destructive) {
                showingDiscardConfirmationAlert = true
            }
        } message: {
            if let session = sessionToResume {
                Text("Du hast ein Workout (\(session.plan?.name ?? "Freies Workout")) am \(session.startTime.formatted(.dateTime.day().month().hour().minute())) begonnen und nicht beendet. Möchtest du es fortsetzen?")
            } else {
                Text("Möchtest du das abgebrochene Workout fortsetzen?")
            }
        }
        .alert("Wirklich verwerfen?", isPresented: $showingDiscardConfirmationAlert) {
            Button("Zurück", role: .cancel) {
                // Show the original alert again if they cancel
                showingResumeWorkoutAlert = true
            }
            Button("Ja, endgültig verwerfen", role: .destructive) {
                if let session = sessionToResume {
                    modelContext.delete(session)
                    sessionToResume = nil
                }
            }
        } message: {
            Text("Alle bisher eingetragenen Sätze und Fortschritte dieses Workouts gehen dauerhaft verloren.")
        }
    }
}

// MARK: - Global Safe Area Hack for UITabBarController
struct TabBarAccessor: UIViewControllerRepresentable {
    var bottomInset: CGFloat
    
    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        return vc
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            // Finde den übergeordneten UITabBarController und setze die globalen Insets
            // WICHTIG: Die Insets auf die CHILD-Controller anwenden, nicht auf den TabBarController selbst!
            // Sonst verschiebt sich die Tab-Bar nach oben.
            if let tabBarController = uiViewController.tabBarController {
                for vc in tabBarController.viewControllers ?? [] {
                    if vc.additionalSafeAreaInsets.bottom != bottomInset {
                        vc.additionalSafeAreaInsets.bottom = bottomInset
                    }
                }
            }
        }
    }
}

extension View {
    func globalMiniPlayerSafeArea(isActive: Bool) -> some View {
        self.background(TabBarAccessor(bottomInset: isActive ? 70 : 0))
    }
}

// MARK: - Lazy View wrapper for NavigationLink
struct LazyView<Content: View>: View {
    let build: () -> Content
    
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    
    var body: Content {
        build()
    }
}

#Preview {
    AppRouter()
}

