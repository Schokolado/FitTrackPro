import SwiftUI

struct OnboardingView: View {
    @AppStorage(AppStorageKeys.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @State private var currentPage = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $currentPage) {
                OnboardingWelcomePage(currentPage: $currentPage)
                    .tag(0)
                OnboardingProfilePage(currentPage: $currentPage)
                    .tag(1)
                OnboardingBodyPage(currentPage: $currentPage)
                    .tag(2)
                OnboardingGoalsPage(currentPage: $currentPage)
                    .tag(3)
                OnboardingFinishPage {
                    Task {
                        // Apple Health Berechtigungen anfragen
                        try? await HealthKitService.shared.requestAuthorization()
                        
                        await MainActor.run {
                            // Apple Health in den App-Einstellungen als "Aktiviert" markieren
                            UserDefaults.standard.set(true, forKey: AppStorageKeys.healthKitEnabled)
                            // Onboarding beenden
                            hasCompletedOnboarding = true
                        }
                    }
                }
                .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)
            .ignoresSafeArea()

            // Page dots indicator
            if currentPage < 4 {
                HStack(spacing: 8) {
                    ForEach(0..<4) { index in
                        Circle()
                            .fill(index == currentPage ? Color.white : Color.white.opacity(0.4))
                            .frame(width: index == currentPage ? 10 : 7, height: index == currentPage ? 10 : 7)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                .padding(.bottom, 48)
            }
        }
    }
}
