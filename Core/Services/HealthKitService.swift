import Foundation
import HealthKit
import SwiftData
import WidgetKit

enum WorkoutCalorieSource: String {
    case healthKitActiveEnergy = "Apple Watch / Health"
    case heartRateFormula = "Herzfrequenz"
    case metEstimate = "MET-Schätzung"
}

struct WorkoutCalorieEstimate {
    let calories: Double
    let averageHeartRate: Double?
    let source: WorkoutCalorieSource
}

enum HealthKitError: Error {
    case notAvailable
    case notAuthorized
    case saveFailed(Error)
}

final class HealthKitService {
    static let shared = HealthKitService()
    
    private let healthStore = HKHealthStore()
    
    // Wir schreiben Workouts und Gewicht (ohne Kalorien für Workouts)
    private let typesToWrite: Set<HKSampleType> = {
        var types: Set<HKSampleType> = []
        let workoutType = HKObjectType.workoutType()
        types.insert(workoutType)
        
        if let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass) {
            types.insert(weightType)
        }
        
        if let energyType = HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed) { types.insert(energyType) }
        if let carbsType = HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates) { types.insert(carbsType) }
        if let proteinType = HKObjectType.quantityType(forIdentifier: .dietaryProtein) { types.insert(proteinType) }
        if let fatType = HKObjectType.quantityType(forIdentifier: .dietaryFatTotal) { types.insert(fatType) }
        if let waterType = HKObjectType.quantityType(forIdentifier: .dietaryWater) { types.insert(waterType) }
        
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        types.insert(sleepType)
        
        return types
    }()
    
    // Lese-Berechtigungen für Schritte
    private let typesToRead: Set<HKObjectType> = {
        var types: Set<HKObjectType> = []
        if let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) {
            types.insert(stepType)
        }
        if let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass) {
            types.insert(weightType)
        }
        if let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            types.insert(hrvType)
        }
        if let rhrType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) {
            types.insert(rhrType)
        }
        if let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) {
            types.insert(hrType)
        }
        if let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergyType)
        }
        if let vo2MaxType = HKObjectType.quantityType(forIdentifier: .vo2Max) {
            types.insert(vo2MaxType)
        }
        if let bodyFatType = HKObjectType.quantityType(forIdentifier: .bodyFatPercentage) {
            types.insert(bodyFatType)
        }
        if let waistType = HKObjectType.quantityType(forIdentifier: .waistCircumference) {
            types.insert(waistType)
        }
        
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        types.insert(sleepType)
        
        return types
    }()
    
    private init() {}
    
    /// Prüft ob HealthKit auf dem Gerät (oder Simulator) verfügbar ist
    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
    
    /// Fragt den Nutzer nach Schreibberechtigungen für Workouts und Gewicht
    func requestAuthorization() async throws {
        guard isAvailable else { throw HealthKitError.notAvailable }
        
        do {
            try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
        } catch {
            throw HealthKitError.notAuthorized
        }
    }
    
    /// Exportiert ein abgeschlossenes Workout (inkl. verbrannter Kalorien, falls vorhanden)
    func exportWorkout(session: WorkoutSession) async throws {
        guard isAvailable else { throw HealthKitError.notAvailable }
        
        let exists = try await checkWorkoutExists(uuid: session.id.uuidString)
        if exists { return }
        
        let start = session.startTime
        let end = session.endTime ?? Date()
        let energyQuantity: HKQuantity? = session.burnedCalories.flatMap {
            $0 > 0 ? HKQuantity(unit: .kilocalorie(), doubleValue: $0) : nil
        }
        
        // Workout erstellen (Krafttraining)
        let workout = HKWorkout(
            activityType: .traditionalStrengthTraining,
            start: start,
            end: end,
            workoutEvents: nil,
            totalEnergyBurned: energyQuantity,
            totalDistance: nil,
            metadata: [
                HKMetadataKeyExternalUUID: session.id.uuidString,
                HKMetadataKeyWorkoutBrandName: "FitTrackPro",
                "PlanName": session.plan?.name ?? "Freies Workout",
                "TotalReps": calculateTotalReps(for: session),
                "TotalVolumeKG": calculateVolume(for: session)
            ]
        )
        
        do {
            try await healthStore.save(workout)
        } catch {
            throw HealthKitError.saveFailed(error)
        }
    }
    
    // MARK: - Live Workout Session (HKWorkoutSession für Background-Survival)

    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?

    /// Startet eine HKWorkoutSession. Hält die App dauerhaft im Hintergrund am Leben.
    func startLiveWorkoutSession(startDate: Date) {
        guard isAvailable else { return }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            self.workoutSession = session
            self.workoutBuilder = builder

            session.startActivity(with: startDate)
            builder.beginCollection(withStart: startDate) { _, error in
                if let error = error {
                    print("HKLiveWorkoutBuilder beginCollection error: \(error)")
                }
            }
        } catch {
            print("HKWorkoutSession start error: \(error)")
        }
    }

    /// Pausiert die HKWorkoutSession (z.B. wenn der Nutzer das Workout pausiert).
    func pauseLiveWorkoutSession() {
        workoutSession?.pause()
    }

    /// Setzt die HKWorkoutSession fort.
    func resumeLiveWorkoutSession() {
        workoutSession?.resume()
    }

    /// Beendet die HKWorkoutSession und speichert das Workout in Apple Health.
    func endLiveWorkoutSession(endDate: Date, sessionId: String, planName: String) {
        guard let session = workoutSession, let builder = workoutBuilder else { return }

        session.end()

        builder.endCollection(withEnd: endDate) { [weak self] _, error in
            if let error = error {
                print("HKLiveWorkoutBuilder endCollection error: \(error)")
                return
            }

            builder.finishWorkout { workout, error in
                if let error = error {
                    print("HKLiveWorkoutBuilder finishWorkout error: \(error)")
                }
                // Workout ist jetzt automatisch in Apple Health gespeichert
                self?.workoutSession = nil
                self?.workoutBuilder = nil
            }
        }
    }

    /// Bricht eine laufende Session ersatzlos ab (z.B. wenn Workout verworfen wird).
    func discardLiveWorkoutSession() {
        workoutBuilder?.discardWorkout()
        workoutSession?.end()
        workoutSession = nil
        workoutBuilder = nil
    }

    /// Exportiert einen Gewichtseintrag
    func exportWeight(entry: WeightEntry) async throws {
        guard isAvailable else { throw HealthKitError.notAvailable }
        
        let exists = try await checkWeightExists(uuid: entry.id.uuidString)
        if exists { return }
        
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            throw HealthKitError.notAvailable
        }
        
        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: entry.weightKg)
        
        let sample = HKQuantitySample(
            type: weightType,
            quantity: quantity,
            start: entry.timestamp,
            end: entry.timestamp,
            metadata: [
                HKMetadataKeyExternalUUID: entry.id.uuidString,
                "Notes": entry.notes,
                "Source": "FitTrackPro"
            ]
        )
        
        do {
            try await healthStore.save(sample)
        } catch {
            throw HealthKitError.saveFailed(error)
        }
    }
    
    /// Exportiert einen Ernährungseintrag (Makros)
    func exportNutrition(entry: FoodEntry) async throws {
        guard isAvailable else { throw HealthKitError.notAvailable }
        
        // Wir erstellen eine eindeutige ID pro Makro-Typ, um Duplikate zu vermeiden
        let baseUUID = entry.id.uuidString
        let energyUUID = "\(baseUUID)-energy"
        let carbsUUID = "\(baseUUID)-carbs"
        let proteinUUID = "\(baseUUID)-protein"
        let fatUUID = "\(baseUUID)-fat"
        
        var samples: [HKQuantitySample] = []
        
        if let energyType = HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed),
           !(try await checkNutritionExists(uuid: energyUUID, type: energyType)) {
            let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: entry.calories)
            samples.append(HKQuantitySample(type: energyType, quantity: quantity, start: entry.timestamp, end: entry.timestamp, metadata: [HKMetadataKeyExternalUUID: energyUUID, "FoodName": entry.name]))
        }
        
        if let carbsType = HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates),
           !(try await checkNutritionExists(uuid: carbsUUID, type: carbsType)) {
            let quantity = HKQuantity(unit: .gram(), doubleValue: entry.carbsGrams)
            samples.append(HKQuantitySample(type: carbsType, quantity: quantity, start: entry.timestamp, end: entry.timestamp, metadata: [HKMetadataKeyExternalUUID: carbsUUID, "FoodName": entry.name]))
        }
        
        if let proteinType = HKObjectType.quantityType(forIdentifier: .dietaryProtein),
           !(try await checkNutritionExists(uuid: proteinUUID, type: proteinType)) {
            let quantity = HKQuantity(unit: .gram(), doubleValue: entry.proteinGrams)
            samples.append(HKQuantitySample(type: proteinType, quantity: quantity, start: entry.timestamp, end: entry.timestamp, metadata: [HKMetadataKeyExternalUUID: proteinUUID, "FoodName": entry.name]))
        }
        
        if let fatType = HKObjectType.quantityType(forIdentifier: .dietaryFatTotal),
           !(try await checkNutritionExists(uuid: fatUUID, type: fatType)) {
            let quantity = HKQuantity(unit: .gram(), doubleValue: entry.fatGrams)
            samples.append(HKQuantitySample(type: fatType, quantity: quantity, start: entry.timestamp, end: entry.timestamp, metadata: [HKMetadataKeyExternalUUID: fatUUID, "FoodName": entry.name]))
        }
        
        if !samples.isEmpty {
            do {
                try await healthStore.save(samples)
            } catch {
                throw HealthKitError.saveFailed(error)
            }
        }
    }
    
    /// Löscht die zu einem FoodEntry gehörigen HealthKit-Einträge
    func deleteNutrition(entry: FoodEntry) async throws {
        guard isAvailable else { return }
        
        let baseUUID = entry.id.uuidString
        let uuids = [
            "\(baseUUID)-energy",
            "\(baseUUID)-carbs",
            "\(baseUUID)-protein",
            "\(baseUUID)-fat"
        ]
        
        let types: [HKQuantityType] = [
            HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed),
            HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates),
            HKObjectType.quantityType(forIdentifier: .dietaryProtein),
            HKObjectType.quantityType(forIdentifier: .dietaryFatTotal)
        ].compactMap { $0 }
        
        for type in types {
            let predicate = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeyExternalUUID, allowedValues: uuids)
            let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
                let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: samples ?? [])
                    }
                }
                healthStore.execute(query)
            }
            if !samples.isEmpty {
                try await healthStore.delete(samples)
            }
        }
    }
    
    /// Aktualisiert einen Ernährungseintrag in HealthKit
    func updateNutrition(entry: FoodEntry) async throws {
        try await deleteNutrition(entry: entry)
        try await exportNutrition(entry: entry)
    }
    
    // Hilfsmethoden für Metadaten
    private func calculateTotalReps(for session: WorkoutSession) -> Int {
        let completedSets = (session.sets ?? []).filter { $0.isCompleted }
        return completedSets.reduce(0) { $0 + $1.actualReps }
    }
    
    private func calculateVolume(for session: WorkoutSession) -> Double {
        let completedSets = (session.sets ?? []).filter { $0.isCompleted }
        return completedSets.reduce(0.0) { $0 + ($1.actualWeight * Double($1.actualReps)) }
    }
    
    // Abfrage auf Duplikate
    func checkWorkoutExists(uuid: String) async throws -> Bool {
        guard isAvailable else { return false }
        let predicate = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeyExternalUUID, allowedValues: [uuid])
        let workoutType = HKObjectType.workoutType()
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: 1, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let exists = (samples?.count ?? 0) > 0
                continuation.resume(returning: exists)
            }
            healthStore.execute(query)
        }
    }
    
    func checkWeightExists(uuid: String) async throws -> Bool {
        guard isAvailable else { return false }
        guard let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass) else { return false }
        let predicate = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeyExternalUUID, allowedValues: [uuid])
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: weightType, predicate: predicate, limit: 1, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let exists = (samples?.count ?? 0) > 0
                continuation.resume(returning: exists)
            }
            healthStore.execute(query)
        }
    }
    
    func checkNutritionExists(uuid: String, type: HKQuantityType) async throws -> Bool {
        guard isAvailable else { return false }
        let predicate = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeyExternalUUID, allowedValues: [uuid])
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let exists = (samples?.count ?? 0) > 0
                continuation.resume(returning: exists)
            }
            healthStore.execute(query)
        }
    }
    
    /// Liest die Schritte für einen bestimmten Tag aus
    private var stepObserverQuery: HKObserverQuery?

    /// Aktiviert automatische Hintergrund-Updates für Schritte (für das iOS Home-Screen Widget)
    func startStepBackgroundObserver() {
        guard isAvailable, stepObserverQuery == nil else { return }
        guard UserDefaults.standard.bool(forKey: AppStorageKeys.healthKitEnabled) else { return }
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }

        healthStore.enableBackgroundDelivery(for: stepType, frequency: .immediate) { _, error in
            if let error = error {
                print("HealthKit step background delivery error: \(error)")
            }
        }

        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, completionHandler, error in
            guard let self = self, error == nil else {
                completionHandler()
                return
            }

            Task {
                defer { completionHandler() }
                guard let steps = try? await self.fetchSteps() else { return }
                let todayStr = Date().iso8601String()
                let standard = UserDefaults.standard
                standard.set(steps, forKey: "cached_today_steps")
                standard.set(todayStr, forKey: "cached_today_steps_date")

                if let shared = UserDefaults(suiteName: "group.com.riccardopfeiler.FitTrackPro") {
                    shared.set(steps, forKey: "cached_today_steps")
                    shared.set(todayStr, forKey: "cached_today_steps_date")
                }

                await MainActor.run {
                    WidgetCenter.shared.reloadTimelines(ofKind: "StepsWidget")
                    WidgetCenter.shared.reloadTimelines(ofKind: "FitTrackProWidget")
                }
            }
        }

        self.stepObserverQuery = query
        healthStore.execute(query)
    }

    func fetchSteps(for date: Date = Date()) async throws -> Int {
        guard isAvailable else { throw HealthKitError.notAvailable }
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return 0
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let sum = result?.sumQuantity() else {
                    continuation.resume(returning: 0)
                    return
                }
                
                let steps = Int(sum.doubleValue(for: HKUnit.count()))
                continuation.resume(returning: steps)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Liest historische Schrittdaten für einen bestimmten Zeitraum aus
    func fetchStepsHistory(startDate: Date, endDate: Date = Date()) async throws -> [(date: Date, steps: Int)] {
        guard isAvailable else { throw HealthKitError.notAvailable }
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return []
        }
        
        let calendar = Calendar.current
        let startOfStart = calendar.startOfDay(for: startDate)
        let endOfEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate))!
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfStart, end: endOfEnd, options: .strictStartDate)
        
        var interval = DateComponents()
        interval.day = 1
        
        let query = HKStatisticsCollectionQuery(quantityType: stepType,
                                                quantitySamplePredicate: predicate,
                                                options: .cumulativeSum,
                                                anchorDate: startOfStart,
                                                intervalComponents: interval)
        
        return try await withCheckedThrowingContinuation { continuation in
            query.initialResultsHandler = { query, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let results = results else {
                    continuation.resume(returning: [])
                    return
                }
                
                var dailySteps: [(Date, Int)] = []
                results.enumerateStatistics(from: startOfStart, to: endOfEnd) { statistics, stop in
                    if let sum = statistics.sumQuantity() {
                        let steps = Int(sum.doubleValue(for: HKUnit.count()))
                        dailySteps.append((statistics.startDate, steps))
                    } else {
                        dailySteps.append((statistics.startDate, 0))
                    }
                }
                
                continuation.resume(returning: dailySteps)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Importiert historische Gewichtsdaten aus Apple Health, die nicht von dieser App stammen.
    func importHistoricalWeights() async throws -> [(timestamp: Date, weightKg: Double)] {
        guard isAvailable else { throw HealthKitError.notAvailable }
        guard let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass) else { return [] }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: weightType, predicate: nil, limit: 100, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let quantitySamples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let bundleId = Bundle.main.bundleIdentifier ?? ""
                let foreignSamples = quantitySamples.filter { sample in
                    sample.sourceRevision.source.bundleIdentifier != bundleId
                }
                
                let result: [(Date, Double)] = foreignSamples.map { sample in
                    let weight = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
                    return (sample.startDate, weight)
                }
                
                continuation.resume(returning: result)
            }
            healthStore.execute(query)
        }
    }

    /// Importiert neue Gewichtseinträge aus Apple Health direkt in SwiftData und vermeidet Duplikate.
    @MainActor
    func importNewWeights(into modelContext: ModelContext) async throws -> Int {
        let imported = try await importHistoricalWeights()
        let existingWeights = (try? modelContext.fetch(FetchDescriptor<WeightEntry>())) ?? []
        var importedCount = 0

        for item in imported {
            let exists = existingWeights.contains {
                abs($0.timestamp.timeIntervalSince1970 - item.timestamp.timeIntervalSince1970) < 60 &&
                abs($0.weightKg - item.weightKg) < 0.1
            }
            if !exists {
                let entry = WeightEntry(weightKg: item.weightKg, timestamp: item.timestamp, notes: "Aus Apple Health importiert")
                entry.syncedToHealthKit = true
                modelContext.insert(entry)
                importedCount += 1
            }
        }

        if importedCount > 0 {
            try? modelContext.save()
        }
        return importedCount
    }
    
    // MARK: - Water & Sleep Export
    
    func saveWaterIntake(ml: Double, date: Date) async throws {
        guard isAvailable else { throw HealthKitError.notAvailable }
        guard let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else {
            throw HealthKitError.notAvailable
        }
        
        let quantity = HKQuantity(unit: .literUnit(with: .milli), doubleValue: ml)
        let sample = HKQuantitySample(type: waterType, quantity: quantity, start: date, end: date)
        
        do {
            try await healthStore.save(sample)
        } catch {
            throw HealthKitError.saveFailed(error)
        }
    }
    
    func deleteWaterIntake(ml: Double, date: Date) async throws {
        guard isAvailable else { return }
        guard let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: date, end: date, options: .strictStartDate)
        
        let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
            let query = HKSampleQuery(sampleType: waterType, predicate: predicate, limit: 10, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples ?? [])
                }
            }
            healthStore.execute(query)
        }
        
        for sample in samples {
            if let quantitySample = sample as? HKQuantitySample {
                let sampleMl = quantitySample.quantity.doubleValue(for: .literUnit(with: .milli))
                if abs(sampleMl - ml) < 0.1 {
                    try await healthStore.delete(sample)
                }
            }
        }
    }
    
    func saveSleep(bedTime: Date, wakeTime: Date) async throws {
        guard isAvailable else { throw HealthKitError.notAvailable }
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthKitError.notAvailable
        }
        
        let sample = HKCategorySample(type: sleepType, value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue, start: bedTime, end: wakeTime)
        
        do {
            try await healthStore.save(sample)
        } catch {
            throw HealthKitError.saveFailed(error)
        }
    }
    
    // MARK: - Recovery Imports
    
    func fetchSleepData(for date: Date) async throws -> SleepDaySummary? {
        guard isAvailable else { throw HealthKitError.notAvailable }
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        
        let calendar = Calendar.current
        // Ein "Schlaftag" nach Apple Health Logik geht typischerweise von 18:00 Uhr des Vortags bis 18:00 Uhr des aktuellen Tags
        let boundaryToday = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: date)!
        let boundaryYesterday = calendar.date(byAdding: .day, value: -1, to: boundaryToday)!
        
        let predicate = HKQuery.predicateForSamples(withStart: boundaryYesterday, end: boundaryToday, options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let sleepSamples = samples as? [HKCategorySample], !sleepSamples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let allSleepPhases = sleepSamples.filter { 
                    $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.awake.rawValue
                }
                
                guard !allSleepPhases.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                
                var remIntervals: [DateInterval] = []
                var coreIntervals: [DateInterval] = []
                var deepIntervals: [DateInterval] = []
                var awakeIntervals: [DateInterval] = []
                var unspecifiedIntervals: [DateInterval] = []
                
                for sample in allSleepPhases {
                    let interval = DateInterval(start: sample.startDate, end: sample.endDate)
                    switch sample.value {
                    case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                        remIntervals.append(interval)
                    case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                        coreIntervals.append(interval)
                    case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                        deepIntervals.append(interval)
                    case HKCategoryValueSleepAnalysis.awake.rawValue:
                        awakeIntervals.append(interval)
                    case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                        unspecifiedIntervals.append(interval)
                    default:
                        break
                    }
                }
                
                // Helper to merge overlapping intervals
                func merge(_ intervals: [DateInterval]) -> [DateInterval] {
                    guard !intervals.isEmpty else { return [] }
                    let sorted = intervals.sorted { $0.start < $1.start }
                    var merged: [DateInterval] = [sorted[0]]
                    for i in 1..<sorted.count {
                        let current = sorted[i]
                        let last = merged.last!
                        if current.start <= last.end {
                            if current.end > last.end {
                                merged[merged.count - 1] = DateInterval(start: last.start, end: current.end)
                            }
                        } else {
                            merged.append(current)
                        }
                    }
                    return merged
                }
                
                // Helper to calculate total duration in minutes
                func duration(of intervals: [DateInterval]) -> Double {
                    intervals.reduce(0) { $0 + $1.duration } / 60.0
                }
                
                let mergedRem = merge(remIntervals)
                let mergedCore = merge(coreIntervals)
                let mergedDeep = merge(deepIntervals)
                let mergedAwake = merge(awakeIntervals)
                
                // Detailed phases all together
                let allDetailed = merge(mergedRem + mergedCore + mergedDeep)
                
                // Filter out unspecified intervals that overlap with detailed phases
                var validUnspecified: [DateInterval] = []
                for unspec in merge(unspecifiedIntervals) {
                    var currentStart = unspec.start
                    let currentEnd = unspec.end
                    var hasOverlap = false
                    
                    for detailed in allDetailed {
                        if detailed.end <= currentStart || detailed.start >= currentEnd {
                            continue // No overlap
                        }
                        // Overlap exists, we simply drop this unspecified sample for basic processing 
                        // (Apple Health usually entirely overrides unspecified if detailed exists in the same night)
                        hasOverlap = true
                        break
                    }
                    if !hasOverlap {
                        validUnspecified.append(unspec)
                    }
                }
                
                let rem = duration(of: mergedRem)
                let core = duration(of: mergedCore)
                let deep = duration(of: mergedDeep)
                let awake = duration(of: mergedAwake)
                let unspecified = duration(of: validUnspecified)
                
                let totalDuration = rem + core + deep + unspecified
                
                // --- Session Grouping ---
                // We combine all actual sleep intervals (detailed + valid unspecified)
                // If the gap between one sleep interval and the next is > 60 minutes, it's a new session.
                let allSleepIntervals = merge(allDetailed + validUnspecified)
                var sessions: [SleepSession] = []
                
                if !allSleepIntervals.isEmpty {
                    var currentSessionStart = allSleepIntervals[0].start
                    var currentSessionEnd = allSleepIntervals[0].end
                    var currentSessionDuration: Double = allSleepIntervals[0].duration
                    
                    for i in 1..<allSleepIntervals.count {
                        let interval = allSleepIntervals[i]
                        let gap = interval.start.timeIntervalSince(currentSessionEnd)
                        
                        if gap > 3600 { // 60 minutes gap threshold
                            // Close current session
                            sessions.append(SleepSession(
                                startDate: currentSessionStart,
                                endDate: currentSessionEnd,
                                durationMinutes: currentSessionDuration / 60.0
                            ))
                            // Start new session
                            currentSessionStart = interval.start
                            currentSessionEnd = interval.end
                            currentSessionDuration = interval.duration
                        } else {
                            // Extend current session
                            currentSessionEnd = interval.end
                            currentSessionDuration += interval.duration
                        }
                    }
                    
                    // Add the last session
                    sessions.append(SleepSession(
                        startDate: currentSessionStart,
                        endDate: currentSessionEnd,
                        durationMinutes: currentSessionDuration / 60.0
                    ))
                }
                
                let sorted = allSleepPhases.sorted(by: { $0.startDate < $1.startDate })
                let bedTime = sorted.first!.startDate
                let wakeTime = sorted.last!.endDate
                
                let summary = SleepDaySummary(
                    date: date,
                    bedTime: bedTime,
                    wakeTime: wakeTime,
                    totalDurationMinutes: totalDuration,
                    awakeMinutes: awake,
                    remMinutes: rem,
                    coreMinutes: core,
                    deepMinutes: deep,
                    unspecifiedMinutes: unspecified,
                    sessions: sessions
                )
                
                continuation.resume(returning: summary)
            }
            healthStore.execute(query)
        }
    }
    
    func fetchSleepHistory(days: Int) async throws -> [SleepDaySummary] {
        guard isAvailable else { throw HealthKitError.notAvailable }
        
        var history: [SleepDaySummary] = []
        let calendar = Calendar.current
        let today = Date()
        
        for i in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            if let sleep = try? await fetchSleepData(for: date) {
                history.append(sleep)
            }
        }
        
        return history
    }
    
    func fetchHRV(for date: Date) async throws -> Double? {
        guard isAvailable else { return nil }
        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return nil }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: hrvType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                if let avg = result?.averageQuantity() {
                    continuation.resume(returning: avg.doubleValue(for: HKUnit.secondUnit(with: .milli)))
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }
    
    func fetchRestingHeartRate(for date: Date) async throws -> Double? {
        guard isAvailable else { return nil }
        guard let rhrType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else { return nil }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: rhrType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                if let avg = result?.averageQuantity() {
                    continuation.resume(returning: avg.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute())))
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }
    
    func fetchHRVBaseline(days: Int = 7, upTo date: Date = Date()) async throws -> Double? {
        guard isAvailable else { return nil }
        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return nil }
        
        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: date) // Baseline = bis gestern
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate)!
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: hrvType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                if let avg = result?.averageQuantity() {
                    continuation.resume(returning: avg.doubleValue(for: HKUnit.secondUnit(with: .milli)))
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }
    
    func fetchRHRBaseline(days: Int = 7, upTo date: Date = Date()) async throws -> Double? {
        guard isAvailable else { return nil }
        guard let rhrType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else { return nil }
        
        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: date)
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate)!
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: rhrType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                if let avg = result?.averageQuantity() {
                    continuation.resume(returning: avg.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute())))
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }
    
    /// Holt die verbrannten Aktivitätskalorien für einen Tag
    func fetchActiveEnergyBurned(for date: Date) async throws -> Double {
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        return try await fetchActiveEnergyBurned(from: start, to: end)
    }

    /// Holt die verbrannten Aktivitätskalorien in einem beliebigen Zeitfenster (z. B. während eines Workouts)
    func fetchActiveEnergyBurned(from start: Date, to end: Date) async throws -> Double {
        guard isAvailable else { throw HealthKitError.notAvailable }
        guard let type = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else { throw HealthKitError.notAvailable }
        guard end > start else { return 0.0 }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let sum = result?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) ?? 0.0
                continuation.resume(returning: sum)
            }
            healthStore.execute(query)
        }
    }

    /// Holt die durchschnittliche Herzfrequenz (bpm) im angegebenen Zeitfenster
    func fetchAverageHeartRate(from start: Date, to end: Date) async throws -> Double? {
        guard isAvailable else { throw HealthKitError.notAvailable }
        guard let type = HKObjectType.quantityType(forIdentifier: .heartRate) else { throw HealthKitError.notAvailable }
        guard end > start else { return nil }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: result?.averageQuantity()?.doubleValue(for: bpmUnit))
            }
            healthStore.execute(query)
        }
    }

    /// Ermittelt verbrannte Workout-Kalorien in absteigender Genauigkeit:
    /// 1. Apple Watch / HealthKit Active Energy im Workout-Zeitfenster
    /// 2. Keytel-Herzfrequenzformel aus Ø-Puls im Zeitfenster
    /// 3. Krafttraining-MET-Schätzung auf Basis von Dauer, Gewicht & RPE
    func resolveWorkoutCalories(
        startTime: Date,
        endTime: Date,
        rpeIntensity: Int?,
        weightKg: Double?,
        birthDateTimestamp: Double,
        biologicalSex: String,
        healthKitEnabled: Bool
    ) async -> WorkoutCalorieEstimate {
        let durationMinutes = max(1.0, endTime.timeIntervalSince(startTime) / 60.0)
        let effectiveWeight = (weightKg ?? 0) > 0 ? weightKg! : 75.0
        var avgHR: Double? = nil

        if healthKitEnabled && isAvailable {
            avgHR = try? await fetchAverageHeartRate(from: startTime, to: endTime)
            if let hkActive = try? await fetchActiveEnergyBurned(from: startTime, to: endTime), hkActive >= 5 {
                return WorkoutCalorieEstimate(
                    calories: hkActive.rounded(),
                    averageHeartRate: avgHR,
                    source: .healthKitActiveEnergy
                )
            }
        }

        if let avgHR, avgHR >= 45 {
            let ageYears: Double = {
                guard birthDateTimestamp > 0 else { return 30 }
                let birth = Date(timeIntervalSince1970: birthDateTimestamp)
                let years = Calendar.current.dateComponents([.year], from: birth, to: startTime).year ?? 30
                return Double(min(max(years, 14), 100))
            }()

            let maleKcalPerMin = (-55.0969 + (0.6309 * avgHR) + (0.1988 * effectiveWeight) + (0.2017 * ageYears)) / 4.184
            let femaleKcalPerMin = (-20.4022 + (0.4472 * avgHR) - (0.1263 * effectiveWeight) + (0.074 * ageYears)) / 4.184
            let kcalPerMin: Double
            switch biologicalSex {
            case "male": kcalPerMin = maleKcalPerMin
            case "female": kcalPerMin = femaleKcalPerMin
            default: kcalPerMin = (maleKcalPerMin + femaleKcalPerMin) / 2.0
            }

            let totalHRCalories = max(durationMinutes, kcalPerMin * durationMinutes)
            return WorkoutCalorieEstimate(
                calories: totalHRCalories.rounded(),
                averageHeartRate: avgHR,
                source: .heartRateFormula
            )
        }

        let met: Double
        switch rpeIntensity ?? 3 {
        case 1: met = 3.0
        case 2: met = 3.8
        case 3: met = 4.8
        case 4: met = 5.5
        case 5...: met = 6.2
        default: met = 4.5
        }
        let estimated = (met * 3.5 * effectiveWeight / 200.0) * durationMinutes
        return WorkoutCalorieEstimate(
            calories: max(1.0, estimated.rounded()),
            averageHeartRate: avgHR,
            source: .metEstimate
        )
    }

    /// Holt den aktuellsten VO2max-Wert (ml/(kg·min)) aus den letzten `days` Tagen
    func fetchLatestVO2Max(days: Int = 90) async throws -> Double? {
        let unit = HKUnit.literUnit(with: .milli)
            .unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: HKUnit.minute()))
        return try await fetchLatestQuantitySample(identifier: .vo2Max, unit: unit, days: days)
    }

    /// Holt den aktuellsten Körperfettanteil in % (z. B. 15.4) aus den letzten `days` Tagen
    func fetchLatestBodyFatPercent(days: Int = 90) async throws -> Double? {
        guard let ratio = try await fetchLatestQuantitySample(identifier: .bodyFatPercentage, unit: .percent(), days: days) else {
            return nil
        }
        return ratio * 100.0
    }

    /// Holt den aktuellsten Taillenumfang in cm aus den letzten `days` Tagen
    func fetchLatestWaistCm(days: Int = 90) async throws -> Double? {
        try await fetchLatestQuantitySample(identifier: .waistCircumference, unit: .meterUnit(with: .centi), days: days)
    }

    private func fetchLatestQuantitySample(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        days: Int
    ) async throws -> Double? {
        guard isAvailable else { return nil }
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }

        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: quantityType, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: sample.quantity.doubleValue(for: unit))
            }
            healthStore.execute(query)
        }
    }
}
