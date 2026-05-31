import SwiftUI

struct AppRouter: View {
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
    }
}

#Preview {
    AppRouter()
}

