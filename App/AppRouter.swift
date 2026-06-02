import SwiftUI

struct AppRouter: View {
    @Environment(WorkoutManager.self) private var workoutManager
    @State private var showingWorkoutSession = false
    
    var body: some View {
        TabView {
            Text("Dashboard View")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.backgroundPrimary)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            
            TrainingMainView()
                .tabItem {
                    Label("Training", systemImage: "dumbbell.fill")
                }
            
            NutritionDashboardView()
                .tabItem {
                    Label("Ernährung", systemImage: "fork.knife")
                }
            
            Text("Statistics View")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.backgroundPrimary)
                .tabItem {
                    Label("Statistik", systemImage: "chart.xyaxis.line")
                }
            
            SettingsView()
                .tabItem {
                    Label("Einstellungen", systemImage: "gearshape.fill")
                }
        }
        .tint(.brand)
        .safeAreaInset(edge: .bottom) {
            if let vm = workoutManager.activeViewModel {
                WorkoutMiniPlayerView(viewModel: vm, planName: workoutManager.activeSession?.plan?.name) {
                    showingWorkoutSession = true
                }
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

#Preview {
    AppRouter()
}

