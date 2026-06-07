import Foundation
import HealthKit

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
    
    /// Exportiert ein abgeschlossenes Workout ohne Kalorien
    func exportWorkout(session: WorkoutSession) async throws {
        guard isAvailable else { throw HealthKitError.notAvailable }
        
        let exists = try await checkWorkoutExists(uuid: session.id.uuidString)
        if exists { return }
        
        let start = session.startTime
        let end = session.endTime ?? Date()
        
        // Workout erstellen (Krafttraining)
        let workout = HKWorkout(
            activityType: .traditionalStrengthTraining,
            start: start,
            end: end,
            workoutEvents: nil,
            totalEnergyBurned: nil, // OHNE Kalorien, gem. Anforderung
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
    
    /// Importiert historische Gewichtsdaten aus Apple Health, die nicht von dieser App stammen.
    func importHistoricalWeights() async throws -> [(timestamp: Date, weightKg: Double)] {
        guard isAvailable else { throw HealthKitError.notAvailable }
        guard let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass) else { return [] }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: weightType, predicate: nil, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
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
}
