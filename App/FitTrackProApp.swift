import SwiftUI
import SwiftData

@main
struct FitTrackProApp: App {
    @State private var modelContainer: ModelContainer?
    @StateObject private var themeManager = ThemeManager()
    @AppStorage(AppStorageKeys.hasCompletedOnboarding) private var hasCompletedOnboarding = false

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
                                let schema = Schema([
                                    Exercise.self,
                                    TrainingPlan.self,
                                    PlanGroup.self,
                                    PlanExercise.self,
                                    WorkoutSession.self,
                                    WorkoutSet.self,
                                    FoodEntry.self,
                                    DailyLog.self,
                                    WeightEntry.self,
                                    StepEntry.self,
                                    SavedFood.self,
                                    Recipe.self,
                                    RecipeIngredient.self
                                ])
                                let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .automatic)
                                
                                do {
                                    let newContainer = try ModelContainer(for: schema, configurations: [config])
                                    
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
                    
                    if let uiImage = UIImage(named: "LaunchLogoV3_raw.png") {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                            .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 8)
                            .scaleEffect(isPulsing ? 1.05 : 0.95)
                    } else {
                        ProgressView()
                    }
                }
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
                
                // Der Text
                if showText {
                    Text("FitTrackPro")
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

