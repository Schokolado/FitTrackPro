import Foundation
import SwiftData

struct SeedExercise: Codable {
    let name: String
    let category: String
    let defaultRestDuration: Double
    let sortOrder: Int
    var notes: String?
    var isTimeBased: Bool?
    var timeUnit: String?
}

@MainActor
class SeedDataService {
    static let shared = SeedDataService()
    private init() {}
    
    private let hasSeededMobilityPlansKey = "hasSeededMobilityPlansV1"
    
    func seedExercisesIfNeeded(context: ModelContext) {
        let lang = Locale.current.language.languageCode?.identifier == "de" ? "de" : "en"
        guard let url = Bundle.main.url(forResource: "DefaultExercises_\(lang)", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let seedData = try? JSONDecoder().decode([SeedExercise].self, from: data) else {
            print("Failed to load seed data from DefaultExercises_\(lang).json")
            return
        }
        
        let fetchDescriptor = FetchDescriptor<Exercise>()
        let existingExercises = (try? context.fetch(fetchDescriptor)) ?? []
        let existingNames = Set(existingExercises.map { $0.name })
        
        for seed in seedData {
            if !existingNames.contains(seed.name) {
                let category = seed.category
                let exercise = Exercise(
                    name: seed.name,
                    category: category,
                    notes: seed.notes ?? "",
                    defaultRestDuration: seed.defaultRestDuration,
                    isCustom: false,
                    sortOrder: seed.sortOrder,
                    isTimeBased: seed.isTimeBased ?? false,
                    timeUnit: seed.timeUnit ?? "Min"
                )
                context.insert(exercise)
            }
        }
        
        do {
            try context.save()
        } catch {
            print("Failed to save seed data: \(error)")
        }
        
        seedMobilityPlansIfNeeded(context: context)
    }
    
    func seedMobilityPlansIfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: hasSeededMobilityPlansKey) else { return }
        
        let groupDescriptor = FetchDescriptor<PlanGroup>()
        let existingGroups = (try? context.fetch(groupDescriptor)) ?? []
        
        let mobilityGroup: PlanGroup
        if let existing = existingGroups.first(where: {
            $0.name.lowercased() == "mobilität" || $0.name.lowercased() == "mobility"
        }) {
            mobilityGroup = existing
        } else {
            let newGroup = PlanGroup(name: "Mobilität", sortOrder: existingGroups.count)
            context.insert(newGroup)
            mobilityGroup = newGroup
        }
        
        let planDescriptor = FetchDescriptor<TrainingPlan>()
        let existingPlans = (try? context.fetch(planDescriptor)) ?? []
        let existingPlanNames = Set(existingPlans.map { $0.name })
        
        let exerciseDescriptor = FetchDescriptor<Exercise>()
        let allExercises = (try? context.fetch(exerciseDescriptor)) ?? []
        
        func findExercise(_ keyword: String) -> Exercise? {
            allExercises.first { $0.name.localizedCaseInsensitiveContains(keyword) }
        }
        
        struct PlanSeedSpec {
            let name: String
            let notes: String
            let exercises: [(keyword: String, sets: Int, reps: Int, rest: TimeInterval, note: String)]
        }
        
        let specs: [PlanSeedSpec] = [
            PlanSeedSpec(
                name: "Mobility A: Unterkörper, ISG & Hüfte",
                notes: "Fokus: Hüftbeuger entlasten, Piriformis dehnen, ISG mobilisieren & Triggerpunkte lösen.\nDauer: ca. 15 Minuten.\nIdeal im Wechsel mit Tag B für eine gesunde Hüfte und einen entspannten unteren Rücken.",
                exercises: [
                    ("Couch Stretch", 2, 2, 15, "2 Min. pro Seite (4 Min. gesamt)"),
                    ("Taube / Pigeon Pose", 2, 2, 15, "1,5–2 Min. pro Seite (3–4 Min. gesamt)"),
                    ("90/90 Hüftrotation", 1, 2, 15, "1,5–2 Min. dynamisch"),
                    ("Triggerpunkt-Behandlung", 1, 3, 15, "2–3 Min. mit Lacrosse-/Tennisball (30–60s pro Punkt)"),
                    ("Plank mit Beckenkippung", 2, 45, 30, "2 Sätze á 45 Sek.")
                ]
            ),
            PlanSeedSpec(
                name: "Mobility B: Oberkörper, BWS & Haltung",
                notes: "Fokus: Brustwirbelsäule aufrichten, Brustmuskulatur dehnen, Nacken entlasten & Trapez aktivieren.\nDauer: ca. 15 Minuten.\nIdeal im Wechsel mit Tag A gegen Rundrücken und Nackenverspannungen.",
                exercises: [
                    ("BWS-Extension", 1, 12, 15, "2 Min. (10–12 Wdh.)"),
                    ("Thorax-Rotation", 2, 10, 15, "10 Wdh. pro Seite (ca. 2–3 Min.)"),
                    ("Doorway Chest Stretch", 2, 2, 15, "1–1,5 Min. pro Seite (3 Min. gesamt)"),
                    ("Chin Tucks & Wall Slides", 2, 12, 30, "2 Sätze á 12 Wdh. (ca. 3 Min.)"),
                    ("Faszienbehandlung (Oberer Rücken)", 1, 3, 15, "3 Min. mit Duoball (Dornfortsätze aussparen)")
                ]
            ),
            PlanSeedSpec(
                name: "Mobility C: Gym-Warm-up & Rumpf-Aktivierung",
                notes: "Fokus: Gezielte Vorbereitung der Gelenke und Rumpfmuskulatur direkt vor dem Krafttraining.\nDauer: ca. 10–15 Minuten (vor dem Workout).\nOptimal vor Kniebeugen, Kreuzheben und schweren Verbundübungen.",
                exercises: [
                    ("Katze-Kuh & Threading the Needle", 1, 10, 15, "10 Wdh. – Mobilisierung von BWS & LWS"),
                    ("Glute Bridge mit Miniband", 2, 15, 30, "2 Sätze á 15 Wdh. – Gesäß-Aktivierung"),
                    ("Pallof Press / Deadbugs", 2, 12, 30, "2 Sätze á 10–12 Wdh. – Rumpfstabilität"),
                    ("Dynamische Hüftkreise & Beinschwünge", 2, 10, 15, "Ergänzend für volle Range of Motion")
                ]
            )
        ]
        
        var sortIdx = existingPlans.count
        for spec in specs {
            if !existingPlanNames.contains(spec.name) {
                let plan = TrainingPlan(
                    name: spec.name,
                    notes: spec.notes,
                    sortOrder: sortIdx,
                    group: mobilityGroup
                )
                context.insert(plan)
                sortIdx += 1
                
                for (exIdx, exSpec) in spec.exercises.enumerated() {
                    if let ex = findExercise(exSpec.keyword) {
                        let planEx = PlanExercise(
                            sortOrder: exIdx,
                            targetSets: exSpec.sets,
                            targetReps: exSpec.reps,
                            targetWeight: nil,
                            restDuration: exSpec.rest,
                            planSpecificNotes: exSpec.note,
                            plan: plan,
                            exercise: ex
                        )
                        context.insert(planEx)
                    }
                }
            }
        }
        
        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: hasSeededMobilityPlansKey)
        } catch {
            print("Failed to save mobility plans: \(error)")
        }
    }
}
