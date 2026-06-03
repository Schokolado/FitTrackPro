import SwiftUI

struct AppRouter: View {
    @Environment(WorkoutManager.self) private var workoutManager
    @State private var showingWorkoutSession = false
    @AppStorage("mainSelectedTab") private var selectedTab = 0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
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
                
                Text("Statistics View")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.backgroundPrimary)
                    .globalMiniPlayerSafeArea(isActive: workoutManager.activeViewModel != nil)
                    .tabItem {
                        Label("Statistik", systemImage: "chart.xyaxis.line")
                    }
                    .tag(3)
                
                SettingsView()
                    .globalMiniPlayerSafeArea(isActive: workoutManager.activeViewModel != nil)
                    .tabItem {
                        Label("Einstellungen", systemImage: "gearshape.fill")
                    }
                    .tag(4)
            }
            .tint(.brand)
            
            if let vm = workoutManager.activeViewModel {
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

#Preview {
    AppRouter()
}

