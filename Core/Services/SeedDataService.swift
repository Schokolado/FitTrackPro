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
    
    private let hasSeededMobilityPlansKey = "hasSeededMobilityPlansV2"
    
    func seedExercisesIfNeeded(context: ModelContext) {
        let lang = Locale.current.language.languageCode?.identifier == "de" ? "de" : "en"
        var seedData: [SeedExercise] = []
        
        if let url = Bundle.main.url(forResource: "DefaultExercises_\(lang)", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([SeedExercise].self, from: data) {
            seedData = decoded
        } else {
            print("Warning: Could not load DefaultExercises_\(lang).json from bundle, using built-in mobility fallback.")
        }
        
        // Always ensure built-in mobility exercises are included even if JSON fails
        let mobilitySeeds = Self.builtInMobilitySeeds
        let seedNamesInJson = Set(seedData.map { $0.name })
        for m in mobilitySeeds where !seedNamesInJson.contains(m.name) {
            seedData.append(m)
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
            allExercises.first { !$0.isCustom && $0.name.localizedCaseInsensitiveContains(keyword) }
                ?? allExercises.first { $0.name.localizedCaseInsensitiveContains(keyword) }
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
    
    static let builtInMobilitySeeds: [SeedExercise] = [
        SeedExercise(
            name: "Couch Stretch (Hüftbeuger-Dehnung)",
            category: "Mobilität",
            defaultRestDuration: 15,
            sortOrder: 80,
            notes: "Ziel / Fokus: Hüftbeuger entlasten, Becken aufrichten und LWS entlasten.\nDauer / Umfang: 2 Min. pro Seite (4 Min. gesamt).\nAusführung: Knie nah an eine Wand oder Couch stellen, oberer Fuß aufstellen, Becken aufrichten und den Po der hinteren Seite fest anspannen.",
            isTimeBased: true,
            timeUnit: "Min"
        ),
        SeedExercise(
            name: "Taube / Pigeon Pose (Gluteus & Piriformis)",
            category: "Mobilität",
            defaultRestDuration: 15,
            sortOrder: 81,
            notes: "Ziel / Fokus: Dehnung von Gluteus & Piriformis, Entlastung des Iliosakralgelenks (ISG).\nDauer / Umfang: 1,5–2 Min. pro Seite (3–4 Min. gesamt).\nAusführung: Vorderes Bein angewinkelt vor dem Körper ablegen, hinteres Bein weit nach hinten ausstrecken. Oberkörper kontrolliert nach vorne neigen.",
            isTimeBased: true,
            timeUnit: "Min"
        ),
        SeedExercise(
            name: "90/90 Hüftrotation (Hüftgelenke)",
            category: "Mobilität",
            defaultRestDuration: 15,
            sortOrder: 82,
            notes: "Ziel / Fokus: Verbesserung der Innen- und Außenrotation der Hüftgelenke.\nDauer / Umfang: 1,5–2 Min. (dynamisch).\nAusführung: Auf den Boden setzen, beide Beine im 90-Grad-Winkel ablegen. Dynamisch und geführt von links nach rechts rotieren.",
            isTimeBased: true,
            timeUnit: "Min"
        ),
        SeedExercise(
            name: "Triggerpunkt-Behandlung (Gluteus & Piriformis)",
            category: "Mobilität",
            defaultRestDuration: 15,
            sortOrder: 83,
            notes: "Ziel / Fokus: Myofasziale Verklebungen & Triggerpunkte im Gesäß lösen.\nDauer / Umfang: 2–3 Min.\nAusführung: Mit einer Gesäßhälfte auf einen Lacrosse- oder Tennisball setzen, schmerzhafte Punkte suchen und 30–60 Sekunden gezielt unter tiefem Ausatmen halten.",
            isTimeBased: true,
            timeUnit: "Min"
        ),
        SeedExercise(
            name: "Plank mit Beckenkippung (Posterior Pelvic Tilt)",
            category: "Mobilität",
            defaultRestDuration: 30,
            sortOrder: 84,
            notes: "Ziel / Fokus: Tiefe Rumpfmuskulatur aktivieren, Beckenstabilisierung gegen Hohlkreuz.\nDauer / Umfang: 2 Sätze á 45 Sek.\nAusführung: Unterarmstütz halten, dabei das Becken aktiv nach hinten kippen (Po fest anspannen, Bauchnabel nach innen ziehen).",
            isTimeBased: true,
            timeUnit: "Sek"
        ),
        SeedExercise(
            name: "BWS-Extension (auf Faszienrolle)",
            category: "Mobilität",
            defaultRestDuration: 15,
            sortOrder: 85,
            notes: "Ziel / Fokus: Aufrichtung der Brustwirbelsäule, Gegenmaßnahme bei Rundrücken.\nDauer / Umfang: 2 Min. (10–12 Wdh.).\nAusführung: Faszienrolle auf Höhe der Schulterblätter unter die BWS legen, Hände an den Hinterkopf nehmen und sanft nach hinten über die Rolle lehnen.",
            isTimeBased: false,
            timeUnit: "Wdh"
        ),
        SeedExercise(
            name: "Thorax-Rotation (Open Book / Buch öffnen)",
            category: "Mobilität",
            defaultRestDuration: 15,
            sortOrder: 86,
            notes: "Ziel / Fokus: Rotationsfähigkeit der Brustwirbelsäule verbessern.\nDauer / Umfang: 10 Wdh. pro Seite (ca. 2–3 Min.).\nAusführung: Seitenlage, Knie um 90° angezogen. Der obere Arm dreht in einem großen Bogen nach hinten auf, der Blick folgt der Hand.",
            isTimeBased: false,
            timeUnit: "Wdh"
        ),
        SeedExercise(
            name: "Doorway Chest Stretch (Brustöffner)",
            category: "Mobilität",
            defaultRestDuration: 15,
            sortOrder: 87,
            notes: "Ziel / Fokus: Dehnung des großen und kleinen Brustmuskels (Pectoralis), Schulteröffnung.\nDauer / Umfang: 1–1,5 Min. pro Seite (3 Min. gesamt).\nAusführung: Unterarm an einen Türrahmen legen, einen Schritt nach vorne machen und den Oberkörper leicht eindrehen, bis eine Dehnung spürbar ist.",
            isTimeBased: true,
            timeUnit: "Min"
        ),
        SeedExercise(
            name: "Chin Tucks & Wall Slides (Nacken & Rücken)",
            category: "Mobilität",
            defaultRestDuration: 30,
            sortOrder: 88,
            notes: "Ziel / Fokus: Nacken entlasten, tiefere Nackenbeuger stärken, unterer Trapez & Rhomboiden aktivieren.\nDauer / Umfang: 2 Sätze á 12 Wdh. (ca. 3 Min.).\nAusführung: Chin Tucks: Doppelkinn-Aktivierung für die tiefen Nackenbeuger. Wall Slides: Aufrecht an der Wand für den unteren Trapez und die Rhomboiden.",
            isTimeBased: false,
            timeUnit: "Wdh"
        ),
        SeedExercise(
            name: "Faszienbehandlung (Oberer Rücken)",
            category: "Mobilität",
            defaultRestDuration: 15,
            sortOrder: 89,
            notes: "Ziel / Fokus: Lösen von Verspannungen der paravertebralen Muskulatur im oberen Rücken.\nDauer / Umfang: 3 Min.\nAusführung: Muskelstränge links und rechts der Wirbelsäule mit dem Duoball ausrollen, dabei die Dornfortsätze aussparen.",
            isTimeBased: true,
            timeUnit: "Min"
        ),
        SeedExercise(
            name: "Katze-Kuh & Threading the Needle",
            category: "Mobilität",
            defaultRestDuration: 15,
            sortOrder: 90,
            notes: "Ziel / Fokus: Mobilisierung und Durchbewegung von BWS & LWS.\nDauer / Umfang: 10 Wiederholungen.\nAusführung: Im Vierfüßlerstand im Wechsel Rücken runden (Katze) und leicht durchhängen lassen (Kuh), danach einen Arm unter dem Körper durchfädeln (Threading the Needle).",
            isTimeBased: false,
            timeUnit: "Wdh"
        ),
        SeedExercise(
            name: "Glute Bridge mit Miniband",
            category: "Mobilität",
            defaultRestDuration: 30,
            sortOrder: 91,
            notes: "Ziel / Fokus: Gezielte Aktivierung der Gesäßmuskulatur vor Kniebeugen oder Kreuzheben.\nDauer / Umfang: 2 Sätze á 15 Wiederholungen.\nAusführung: Rückenlage, Miniband oberhalb der Knie, Knie nach außen drücken und das Becken hochdrücken, bis Oberschenkel und Oberkörper eine Linie bilden.",
            isTimeBased: false,
            timeUnit: "Wdh"
        ),
        SeedExercise(
            name: "Pallof Press / Deadbugs",
            category: "Mobilität",
            defaultRestDuration: 30,
            sortOrder: 92,
            notes: "Ziel / Fokus: Antirotation & Rumpfstabilität aufbauen ohne Überlastung der Hüftbeuger.\nDauer / Umfang: 2 Sätze á 10–12 Wiederholungen.\nAusführung: Pallof Press am Kabelzug/Band gegen Rotation halten oder Deadbugs kontrolliert diagonal Arm und Bein absenken, LWS bleibt fest am Boden.",
            isTimeBased: false,
            timeUnit: "Wdh"
        ),
        SeedExercise(
            name: "Dynamische Hüftkreise & Beinschwünge",
            category: "Mobilität",
            defaultRestDuration: 15,
            sortOrder: 93,
            notes: "Ziel / Fokus: Dynamische Bereitstellung des vollen Bewegungsausmaßes (Range of Motion).\nDauer / Umfang: 10–12 Wdh. pro Seite.\nAusführung: Einbeinig stehen (ggf. abstützen), freies Bein kontrolliert vor- und zurückschwingen sowie weite Hüftkreise nach außen und innen durchführen.",
            isTimeBased: false,
            timeUnit: "Wdh"
        )
    ]
}
