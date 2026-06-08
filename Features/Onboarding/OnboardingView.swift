import SwiftUI
import SwiftData

struct OnboardingView: View {
    @AppStorage(AppStorageKeys.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @Environment(\.modelContext) private var modelContext
    @State private var currentPage = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $currentPage) {
                OnboardingWelcomeBackPage(currentPage: $currentPage) {
                    Task {
                        // 1. Pull data from iCloud
                        await MainActor.run {
                            CloudProfileService.shared.pullCloudToLocal()
                        }
                        
                        // 2. Apple Health Berechtigungen anfragen
                        try? await HealthKitService.shared.requestAuthorization()
                        
                        await MainActor.run {
                            UserDefaults.standard.set(true, forKey: AppStorageKeys.healthKitEnabled)
                            UserDefaults.standard.set(true, forKey: "autoSyncHealthKit")
                        }
                        
                        // 3. Historische Daten importieren
                        do {
                            let imported = try await HealthKitService.shared.importHistoricalWeights()
                            await MainActor.run {
                                let descriptor = FetchDescriptor<WeightEntry>()
                                let existingWeights = (try? modelContext.fetch(descriptor)) ?? []
                                
                                for item in imported {
                                    let exists = existingWeights.contains {
                                        abs($0.timestamp.timeIntervalSince1970 - item.timestamp.timeIntervalSince1970) < 60 &&
                                        abs($0.weightKg - item.weightKg) < 0.1
                                    }
                                    if !exists {
                                        let entry = WeightEntry(weightKg: item.weightKg, timestamp: item.timestamp, notes: "Aus Apple Health importiert")
                                        entry.syncedToHealthKit = true
                                        modelContext.insert(entry)
                                    }
                                }
                                
                                // Auch das Onboarding-Gewicht als ersten Eintrag setzen, falls HealthKit leer war
                                if imported.isEmpty {
                                    let weight = CloudProfileService.shared.getCloudWeight()
                                    if weight > 0 {
                                        let exists = existingWeights.contains { abs($0.weightKg - weight) < 0.1 }
                                        if !exists {
                                            let entry = WeightEntry(weightKg: weight, timestamp: Date(), notes: "Aus iCloud wiederhergestellt")
                                            modelContext.insert(entry)
                                        }
                                    }
                                }
                                
                                try? modelContext.save()
                            }
                        } catch {
                            print("Failed to import historical weights: \(error)")
                        }
                        
                        // 4. Onboarding beenden
                        await MainActor.run {
                            hasCompletedOnboarding = true
                        }
                    }
                }
                .tag(-1)
                
                OnboardingWelcomePage(currentPage: $currentPage)
                    .tag(0)
                OnboardingProfilePage(currentPage: $currentPage)
                    .tag(1)
                OnboardingBodyPage(currentPage: $currentPage)
                    .tag(2)
                OnboardingGoalsPage(currentPage: $currentPage)
                    .tag(3)
                OnboardingFinishPage { useHealthKit in
                    Task {
                        if useHealthKit {
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
                                    let descriptor = FetchDescriptor<WeightEntry>()
                                    let existingWeights = (try? modelContext.fetch(descriptor)) ?? []
                                    
                                    for item in imported {
                                        let exists = existingWeights.contains {
                                            abs($0.timestamp.timeIntervalSince1970 - item.timestamp.timeIntervalSince1970) < 60 &&
                                            abs($0.weightKg - item.weightKg) < 0.1
                                        }
                                        if !exists {
                                            let entry = WeightEntry(weightKg: item.weightKg, timestamp: item.timestamp, notes: "Aus Apple Health importiert")
                                            entry.syncedToHealthKit = true
                                            modelContext.insert(entry)
                                        }
                                    }
                                    try? modelContext.save()
                                }
                            } catch {
                                print("Failed to import historical weights during onboarding: \(error)")
                            }
                        } else {
                            await MainActor.run {
                                UserDefaults.standard.set(false, forKey: AppStorageKeys.healthKitEnabled)
                            }
                        }
                        
                        await MainActor.run {
                            // Push new profile to iCloud
                            CloudProfileService.shared.pushLocalToCloud()
                            
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

            // Page dots indicator (nur für reguläres Onboarding 0-3 anzeigen)
            if currentPage >= 0 && currentPage < 4 {
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
        .onAppear {
            if CloudProfileService.shared.hasCloudProfile() {
                currentPage = -1
            }
        }
    }
}
