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
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                
                TrainingMainView()
                    .tabItem {
                        Label("Training", systemImage: "dumbbell.fill")
                    }
                
                Text("Nutrition View")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.backgroundPrimary)
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
            
            if let vm = workoutManager.activeViewModel {
                WorkoutMiniPlayerView(viewModel: vm) {
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
    }
}

#Preview {
    AppRouter()
}

