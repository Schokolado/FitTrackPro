import SwiftUI

struct OnboardingView: View {
    @AppStorage(AppStorageKeys.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @Environment(\.modelContext) private var modelContext
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
                            // Apple Health aktivieren und AutoSync einschalten
                            UserDefaults.standard.set(true, forKey: AppStorageKeys.healthKitEnabled)
                            UserDefaults.standard.set(true, forKey: "autoSyncHealthKit")
                        }
                        
                        // Historische Gewichtsdaten aus Apple Health importieren
                        do {
                            let imported = try await HealthKitService.shared.importHistoricalWeights()
                            await MainActor.run {
                                for item in imported {
                                    let entry = WeightEntry(weightKg: item.weightKg, timestamp: item.timestamp, notes: "Aus Apple Health importiert")
                                    entry.syncedToHealthKit = true
                                    modelContext.insert(entry)
                                }
                                try? modelContext.save()
                            }
                        } catch {
                            print("Failed to import historical weights during onboarding: \(error)")
                        }
                        
                        await MainActor.run {
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
