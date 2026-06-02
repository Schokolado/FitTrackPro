import SwiftUI

struct AppRouter: View {
    @Environment(WorkoutManager.self) private var workoutManager
    @State private var showingWorkoutSession = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                Text("Dashboard View")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.backgroundPrimary)
                    .globalMiniPlayerSafeArea(isActive: workoutManager.activeViewModel != nil)
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                
                TrainingMainView()
                    .globalMiniPlayerSafeArea(isActive: workoutManager.activeViewModel != nil)
                    .tabItem {
                        Label("Training", systemImage: "dumbbell.fill")
                    }
                
                NutritionDashboardView()
                    .globalMiniPlayerSafeArea(isActive: workoutManager.activeViewModel != nil)
                    .tabItem {
                        Label("Ernährung", systemImage: "fork.knife")
                    }
                
                Text("Statistics View")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.backgroundPrimary)
                    .globalMiniPlayerSafeArea(isActive: workoutManager.activeViewModel != nil)
                    .tabItem {
                        Label("Statistik", systemImage: "chart.xyaxis.line")
                    }
                
                SettingsView()
                    .globalMiniPlayerSafeArea(isActive: workoutManager.activeViewModel != nil)
                    .tabItem {
                        Label("Einstellungen", systemImage: "gearshape.fill")
                    }
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
            if let tabBarController = uiViewController.tabBarController {
                if tabBarController.additionalSafeAreaInsets.bottom != bottomInset {
                    tabBarController.additionalSafeAreaInsets.bottom = bottomInset
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

