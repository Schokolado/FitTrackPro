import SwiftUI
import SwiftData

@main
struct FitTrackProApp: App {
    @State private var modelContainer: ModelContainer?
    @StateObject private var themeManager = ThemeManager()
    @AppStorage(AppStorageKeys.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ZStack {
                if let container = modelContainer {
                    AppRouter()
                        .environmentObject(themeManager)
                        .environment(WorkoutManager.shared)
                        .fullScreenCover(isPresented: Binding(
                            get: { !hasCompletedOnboarding },
                            set: { _ in }
                        )) {
                            OnboardingView()
                        }
                        .modelContainer(container)
                        .transition(AnyTransition.opacity)
                } else {
                    SplashScreenView()
                        .transition(AnyTransition.opacity)
                        .onAppear {
                            Task.detached(priority: .userInitiated) {
                                do {
                                    let newContainer = try SharedContainer.create()
                                    
                                    // Seed default exercises during splash screen
                                    await MainActor.run {
                                        let context = newContainer.mainContext
                                        SeedDataService.shared.seedExercisesIfNeeded(context: context)
                                    }
                                    
                                    // Give the splash screen a minimum of 2 seconds to show off the cool animation
                                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                                    
                                    await MainActor.run {
                                        withAnimation(.easeInOut(duration: 0.6)) {
                                            self.modelContainer = newContainer
                                        }
                                    }
                                } catch {
                                    fatalError("Could not create ModelContainer: \(error)")
                                }
                            }
                        }
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .background || newPhase == .inactive {
                    WidgetDataSync.sync()
                }
            }
        }
    }
}

struct SplashScreenView: View {
    @State private var isAnimating = false
    @State private var isPulsing = false
    @State private var showText = false
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                
                // Das Logo bleibt immer exakt im absoluten Zentrum des Bildschirms
                ZStack {
                    // Expanding outer ring (Ripple effect)
                    Circle()
                        .fill(Color.brand.opacity(0.3))
                        .frame(width: 140, height: 140)
                        .scaleEffect(isAnimating ? 1.5 : 0.8)
                        .opacity(isAnimating ? 0 : 1)
                    
                    Image("VigrLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 8)
                        .scaleEffect(isPulsing ? 1.05 : 0.95)
                }
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
                
                // Der Text
                if showText {
                    Text("Vigr")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundColor(.primary)
                        .transition(AnyTransition.opacity.combined(with: .move(edge: .bottom)))
                        .position(x: geo.size.width / 2, y: geo.size.height / 2 + 130)
                }
            }
        }
        .ignoresSafeArea(.all)
        .onAppear {
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3)) {
                showText = true
            }
        }
    }
}

import WidgetKit

struct WidgetDataSync {
    static func sync() {
        let standard = UserDefaults.standard
        let shared = UserDefaults(suiteName: "group.com.riccardopfeiler.FitTrackPro")
        
        let keys = [
            "dailyCalorieGoal", 
            "nutritionGoalProtein", 
            "nutritionGoalCarbs", 
            "nutritionGoalFat", 
            "daily_step_goal", 
            "dailyStepGoal"
        ]
        
        for key in keys {
            if standard.object(forKey: key) != nil {
                shared?.set(standard.object(forKey: key), forKey: key)
            }
        }
        
        WidgetCenter.shared.reloadAllTimelines()
    }
}
