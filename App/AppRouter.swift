import SwiftUI

struct AppRouter: View {
    var body: some View {
        TabView {
            Text("Dashboard View")
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            
            Text("Training View")
                .tabItem {
                    Label("Training", systemImage: "dumbbell.fill")
                }
            
            Text("Nutrition View")
                .tabItem {
                    Label("Ernährung", systemImage: "fork.knife")
                }
            
            Text("Statistics View")
                .tabItem {
                    Label("Statistik", systemImage: "chart.xyaxis.line")
                }
            
            Text("Settings View")
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
