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
    private let hasUpgradedMobilityNotesKey = "hasUpgradedMobilityNotesV3"
    private let hasSeededDefaultFoodsKey = "hasSeededDefaultFoodsV1"
    
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
        upgradeMobilityNotesIfNeeded(context: context)
        seedDefaultFoodsIfNeeded(context: context)
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
        
        let specs = Self.mobilityPlanSpecs
        
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
    
    /// Upgrades existing plain-text mobility notes to the richly formatted markdown versions once.
    func upgradeMobilityNotesIfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: hasUpgradedMobilityNotesKey) else { return }
        
        // 1. Upgrade standard mobility exercises
        let exerciseDescriptor = FetchDescriptor<Exercise>()
        if let allExercises = try? context.fetch(exerciseDescriptor) {
            for ex in allExercises where !ex.isCustom {
                if let formatted = defaultExerciseNotes(for: ex.name),
                   ex.notes.isEmpty || !ex.notes.contains("### ") {
                    ex.notes = formatted
                }
            }
        }
        
        // 2. Upgrade standard mobility training plans and their exercises
        let planDescriptor = FetchDescriptor<TrainingPlan>()
        if let allPlans = try? context.fetch(planDescriptor) {
            for plan in allPlans {
                if let formattedPlanNotes = defaultPlanNotes(for: plan.name),
                   plan.notes.isEmpty || !plan.notes.contains("## ") {
                    plan.notes = formattedPlanNotes
                }
                for planEx in plan.planExercises ?? [] {
                    if let exName = planEx.exercise?.name,
                       let formattedExNote = defaultPlanExerciseNotes(planName: plan.name, exerciseName: exName),
                       planEx.planSpecificNotes.isEmpty || !planEx.planSpecificNotes.contains("**") {
                        planEx.planSpecificNotes = formattedExNote
                    }
                }
            }
        }
        
        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: hasUpgradedMobilityNotesKey)
        } catch {
            print("Failed to upgrade mobility notes: \(error)")
        }
    }
    
    // MARK: - Factory Default Notes Lookup
    
    func defaultExerciseNotes(for exerciseName: String) -> String? {
        let lower = exerciseName.lowercased()
        if let exact = Self.builtInMobilitySeeds.first(where: { $0.name.lowercased() == lower }),
           let notes = exact.notes, !notes.isEmpty {
            return notes
        }
        if let matched = Self.builtInMobilitySeeds.first(where: {
            lower.contains($0.name.components(separatedBy: " (").first?.lowercased() ?? "")
        }), let notes = matched.notes, !notes.isEmpty {
            return notes
        }
        return nil
    }
    
    func defaultPlanNotes(for planName: String) -> String? {
        let lower = planName.lowercased()
        return Self.mobilityPlanSpecs.first(where: { $0.name.lowercased() == lower })?.notes
    }
    
    func defaultPlanExerciseNotes(planName: String, exerciseName: String) -> String? {
        let lowerPlan = planName.lowercased()
        guard let spec = Self.mobilityPlanSpecs.first(where: { $0.name.lowercased() == lowerPlan }) else {
            return nil
        }
        let lowerEx = exerciseName.lowercased()
        return spec.exercises.first(where: { lowerEx.contains($0.keyword.lowercased()) })?.note
    }
    
    struct PlanSeedSpec {
        let name: String
        let notes: String
        let exercises: [(keyword: String, sets: Int, reps: Int, rest: TimeInterval, note: String)]
    }
    
    static let mobilityPlanSpecs: [PlanSeedSpec] = [
        PlanSeedSpec(
            name: "Mobility A: Unterkörper, ISG & Hüfte",
            notes: """
            # Tag A: Unterkörper, ISG & Hüfte
            **Dauer:** ca. 15 Minuten

            ## 🎯 Fokus & Ziel
            - Hüftbeuger entlasten & Becken aufrichten
            - Piriformis & Gluteus gezielt dehnen
            - ISG mobilisieren & myofasziale Triggerpunkte lösen

            ---
            *Ideal im Wechsel mit Tag B für eine bewegliche Hüfte und einen entspannten unteren Rücken.*
            """,
            exercises: [
                ("Couch Stretch", 2, 2, 15, "**2 Min. pro Seite** *(4 Min. gesamt)*\nBecken aktiv aufrichten & hinteren Po fest anspannen."),
                ("Taube / Pigeon Pose", 2, 2, 15, "**1,5–2 Min. pro Seite** *(3–4 Min. gesamt)*\nOberkörper kontrolliert nach vorne neigen."),
                ("90/90 Hüftrotation", 1, 2, 15, "**1,5–2 Min.** *(dynamisch)*\nBeide Beine im 90°-Winkel geführt rotieren."),
                ("Triggerpunkt-Behandlung", 1, 3, 15, "**2–3 Min.** mit Lacrosse-/Tennisball\nSchmerzhafte Punkte **30–60 Sek.** unter tiefem Ausatmen halten."),
                ("Plank mit Beckenkippung", 2, 45, 30, "**2 Sätze á 45 Sek.**\nBecken aktiv nach hinten kippen *(Posterior Pelvic Tilt)*.")
            ]
        ),
        PlanSeedSpec(
            name: "Mobility B: Oberkörper, BWS & Haltung",
            notes: """
            # Tag B: Oberkörper, BWS & Haltung
            **Dauer:** ca. 15 Minuten

            ## 🎯 Fokus & Ziel
            - Brustwirbelsäule (BWS) aufrichten gegen Rundrücken
            - Brustmuskulatur dehnen & Schultern öffnen
            - Nacken entlasten & unteren Trapez aktivieren

            ---
            *Ideal im Wechsel mit Tag A für aufrechte Haltung und weniger Nackenverspannungen.*
            """,
            exercises: [
                ("BWS-Extension", 1, 12, 15, "**2 Min.** *(10–12 Wdh.)*\nFaszienrolle auf Höhe der Schulterblätter positionieren."),
                ("Thorax-Rotation", 2, 10, 15, "**10 Wdh. pro Seite** *(ca. 2–3 Min.)*\nBlick folgt beim Aufdrehen stets der Hand."),
                ("Doorway Chest Stretch", 2, 2, 15, "**1–1,5 Min. pro Seite** *(3 Min. gesamt)*\nUnterarm am Türrahmen, Oberkörper leicht eindrehen."),
                ("Chin Tucks & Wall Slides", 2, 12, 30, "**2 Sätze á 12 Wdh.** *(ca. 3 Min.)*\nDoppelkinn-Aktivierung & saubere Wall Slides."),
                ("Faszienbehandlung (Oberer Rücken)", 1, 3, 15, "**3 Min.** mit Duoball\nDornfortsätze der Wirbelsäule unbedingt aussparen.")
            ]
        ),
        PlanSeedSpec(
            name: "Mobility C: Gym-Warm-up & Rumpf-Aktivierung",
            notes: """
            # Tag C: Gym-Warm-up & Rumpf-Aktivierung
            **Dauer:** ca. 10–15 Minuten *(direkt vor dem Krafttraining)*

            ## 🎯 Fokus & Ziel
            - Gezielte Vorbereitung aller wichtigen Gelenke vor Belastung
            - Aktivierung der Gesäß- und tiefen Rumpfmuskulatur

            ---
            *Optimal direkt vor Kniebeugen, Kreuzheben und schweren Verbundübungen.*
            """,
            exercises: [
                ("Katze-Kuh & Threading the Needle", 1, 10, 15, "**10 Wdh.**\nMobilisierung und Durchbewegung von BWS & LWS."),
                ("Glute Bridge mit Miniband", 2, 15, 30, "**2 Sätze á 15 Wdh.**\nGezielte Gesäß-Aktivierung vor Kniebeugen & Kreuzheben."),
                ("Pallof Press / Deadbugs", 2, 12, 30, "**2 Sätze á 10–12 Wdh.**\nRumpfstabilität ohne Überlastung der Hüftbeuger."),
                ("Dynamische Hüftkreise & Beinschwünge", 2, 10, 15, "**10–12 Wdh. pro Seite**\nVolles Bewegungsausmaß *(Range of Motion)* dynamisch öffnen.")
            ]
        )
    ]
    
    static let builtInMobilitySeeds: [SeedExercise] = [
        SeedExercise(
            name: "Couch Stretch (Hüftbeuger-Dehnung)",
            category: "Mobilität",
            defaultRestDuration: 15,
            sortOrder: 80,
            notes: """
            ### 🎯 Ziel / Fokus
            Hüftbeuger entlasten, Becken aufrichten und LWS entlasten.

            ### ⏱️ Dauer / Umfang
            **2 Min. pro Seite** *(4 Min. gesamt)*

            ### 📋 Ausführung
            - Knie nah an eine Wand oder Couch stellen
            - Oberen Fuß an der Wand aufstellen
            - Becken aufrichten und den Po der hinteren Seite fest anspannen
            """,
            isTimeBased: true,
            timeUnit: "Min"
        ),
        SeedExercise(
            name: "Taube / Pigeon Pose (Gluteus & Piriformis)",
            category: "Mobilität",
            defaultRestDuration: 15,
            sortOrder: 81,
            notes: """
            ### 🎯 Ziel / Fokus
            Dehnung von Gluteus & Piriformis, Entlastung des Iliosakralgelenks (ISG).

            ### ⏱️ Dauer / Umfang
            **1,5–2 Min. pro Seite** *(3–4 Min. gesamt)*

            ### 📋 Ausführung
            - Vorderes Bein angewinkelt vor dem Körper ablegen
            - Hinteres Bein weit nach hinten ausstrecken
            - Oberkörper kontrolliert und ruhig nach vorne neigen
            """,
            isTimeBased: true,
            timeUnit: "Min"
        ),
        SeedExercise(
            name: "90/90 Hüftrotation (Hüftgelenke)",
            category: "Mobilität",
            defaultRestDuration: 15,
            sortOrder: 82,
            notes: """
            ### 🎯 Ziel / Fokus
            Verbesserung der Innen- und Außenrotation der Hüftgelenke.

            ### ⏱️ Dauer / Umfang
            **1,5–2 Min.** *(dynamisch)*

            ### 📋 Ausführung
            - Auf den Boden setzen, beide Beine im **90-Grad-Winkel** ablegen
            - Dynamisch und geführt von links nach rechts rotieren
            """,
            isTimeBased: true,
            timeUnit: "Min"
        ),
        SeedExercise(
            name: "Triggerpunkt-Behandlung (Gluteus & Piriformis)",
            category: "Mobilität",
            defaultRestDuration: 15,
            sortOrder: 83,
            notes: """
            ### 🎯 Ziel / Fokus
            Myofasziale Verklebungen & Triggerpunkte im Gesäß lösen.

            ### ⏱️ Dauer / Umfang
            **2–3 Min.**

            ### 📋 Ausführung
            - Mit einer Gesäßhälfte auf einen Lacrosse- oder Tennisball setzen
            - Schmerzhafte Punkte gezielt suchen
            - **30–60 Sekunden** pro Punkt unter tiefem Ausatmen halten
            """,
            isTimeBased: true,
            timeUnit: "Min"
        ),
        SeedExercise(
            name: "Plank mit Beckenkippung (Posterior Pelvic Tilt)",
            category: "Mobilität",
            defaultRestDuration: 30,
            sortOrder: 84,
            notes: """
            ### 🎯 Ziel / Fokus
            Tiefe Rumpfmuskulatur aktivieren & Becken gegen Hohlkreuz stabilisieren.

            ### ⏱️ Dauer / Umfang
            **2 Sätze á 45 Sek.**

            ### 📋 Ausführung
            - Unterarmstütz sauber halten
            - Becken aktiv nach hinten kippen *(Posterior Pelvic Tilt)*
            - Po fest anspannen und Bauchnabel nach innen ziehen
            """,
            isTimeBased: true,
            timeUnit: "Sek"
        ),
        SeedExercise(
            name: "BWS-Extension (auf Faszienrolle)",
            category: "Mobilität",
            defaultRestDuration: 15,
            sortOrder: 85,
            notes: """
            ### 🎯 Ziel / Fokus
            Aufrichtung der Brustwirbelsäule, Gegenmaßnahme bei Rundrücken.

            ### ⏱️ Dauer / Umfang
            **2 Min.** *(10–12 Wdh.)*

            ### 📋 Ausführung
            - Faszienrolle auf Höhe der Schulterblätter unter die BWS legen
            - Hände an den Hinterkopf nehmen
            - Sanft und kontrolliert nach hinten über die Rolle lehnen
            """,
            isTimeBased: false,
            timeUnit: "Wdh"
        ),
        SeedExercise(
            name: "Thorax-Rotation (Open Book / Buch öffnen)",
            category: "Mobilität",
            defaultRestDuration: 15,
            sortOrder: 86,
            notes: """
            ### 🎯 Ziel / Fokus
            Rotationsfähigkeit der Brustwirbelsäule verbessern.

            ### ⏱️ Dauer / Umfang
            **10 Wdh. pro Seite** *(ca. 2–3 Min.)*

            ### 📋 Ausführung
            - Seitenlage einnehmen, Knie um **90°** anziehen
            - Oberen Arm in einem großen Bogen nach hinten aufdrehen
            - Der Blick folgt durchgehend der Hand
            """,
            isTimeBased: false,
            timeUnit: "Wdh"
        ),
        SeedExercise(
            name: "Doorway Chest Stretch (Brustöffner)",
            category: "Mobilität",
            defaultRestDuration: 15,
            sortOrder: 87,
            notes: """
            ### 🎯 Ziel / Fokus
            Dehnung des großen & kleinen Brustmuskels *(Pectoralis)*, Schulteröffnung.

            ### ⏱️ Dauer / Umfang
            **1–1,5 Min. pro Seite** *(3 Min. gesamt)*

            ### 📋 Ausführung
            - Unterarm an einen Türrahmen legen
            - Einen Schritt nach vorne machen
            - Oberkörper leicht eindrehen, bis eine angenehme Dehnung spürbar ist
            """,
            isTimeBased: true,
            timeUnit: "Min"
        ),
        SeedExercise(
            name: "Chin Tucks & Wall Slides (Nacken & Rücken)",
            category: "Mobilität",
            defaultRestDuration: 30,
            sortOrder: 88,
            notes: """
            ### 🎯 Ziel / Fokus
            Nacken entlasten, tiefe Nackenbeuger stärken, unteren Trapez & Rhomboiden aktivieren.

            ### ⏱️ Dauer / Umfang
            **2 Sätze á 12 Wdh.** *(ca. 3 Min.)*

            ### 📋 Ausführung
            - **Chin Tucks:** Gezielte Doppelkinn-Aktivierung für die tiefen Nackenbeuger
            - **Wall Slides:** Aufrecht an der Wand Arme hoch- und tiefgleiten für unteren Trapez & Rhomboiden
            """,
            isTimeBased: false,
            timeUnit: "Wdh"
        ),
        SeedExercise(
            name: "Faszienbehandlung (Oberer Rücken)",
            category: "Mobilität",
            defaultRestDuration: 15,
            sortOrder: 89,
            notes: """
            ### 🎯 Ziel / Fokus
            Lösen von Verspannungen der paravertebralen Muskulatur im oberen Rücken.

            ### ⏱️ Dauer / Umfang
            **3 Min.**

            ### 📋 Ausführung
            - Muskelstränge links und rechts der Wirbelsäule mit dem Duoball ausrollen
            - **Wichtig:** Die Dornfortsätze der Wirbelsäule dabei aussparen
            """,
            isTimeBased: true,
            timeUnit: "Min"
        ),
        SeedExercise(
            name: "Katze-Kuh & Threading the Needle",
            category: "Mobilität",
            defaultRestDuration: 15,
            sortOrder: 90,
            notes: """
            ### 🎯 Ziel / Fokus
            Mobilisierung und Durchbewegung von Brust- und Lendenwirbelsäule (BWS & LWS).

            ### ⏱️ Dauer / Umfang
            **10 Wiederholungen**

            ### 📋 Ausführung
            - Im Vierfüßlerstand im Wechsel Rücken runden *(Katze)* und leicht durchhängen *(Kuh)*
            - Anschließend einen Arm rotierend unter dem Körper durchfädeln *(Threading the Needle)*
            """,
            isTimeBased: false,
            timeUnit: "Wdh"
        ),
        SeedExercise(
            name: "Glute Bridge mit Miniband",
            category: "Mobilität",
            defaultRestDuration: 30,
            sortOrder: 91,
            notes: """
            ### 🎯 Ziel / Fokus
            Gezielte Aktivierung der Gesäßmuskulatur vor Kniebeugen oder Kreuzheben.

            ### ⏱️ Dauer / Umfang
            **2 Sätze á 15 Wiederholungen**

            ### 📋 Ausführung
            - Rückenlage, Miniband oberhalb der Knie platzieren
            - Knie aktiv nach außen gegen das Band drücken
            - Becken hochdrücken, bis Oberschenkel und Oberkörper eine Linie bilden
            """,
            isTimeBased: false,
            timeUnit: "Wdh"
        ),
        SeedExercise(
            name: "Pallof Press / Deadbugs",
            category: "Mobilität",
            defaultRestDuration: 30,
            sortOrder: 92,
            notes: """
            ### 🎯 Ziel / Fokus
            Antirotation & Rumpfstabilität aufbauen ohne Überlastung der Hüftbeuger.

            ### ⏱️ Dauer / Umfang
            **2 Sätze á 10–12 Wiederholungen**

            ### 📋 Ausführung
            - **Pallof Press:** Am Kabelzug oder Band stabil gegen die Rotation halten
            - **Deadbugs:** Kontrolliert diagonal Arm und Bein absenken – **LWS bleibt fest am Boden**
            """,
            isTimeBased: false,
            timeUnit: "Wdh"
        ),
        SeedExercise(
            name: "Dynamische Hüftkreise & Beinschwünge",
            category: "Mobilität",
            defaultRestDuration: 15,
            sortOrder: 93,
            notes: """
            ### 🎯 Ziel / Fokus
            Dynamische Bereitstellung des vollen Bewegungsausmaßes *(Range of Motion)*.

            ### ⏱️ Dauer / Umfang
            **10–12 Wdh. pro Seite**

            ### 📋 Ausführung
            - Einbeinig stehen *(bei Bedarf leicht abstützen)*
            - Freies Bein kontrolliert vor- und zurückschwingen
            - Weite Hüftkreise nach außen und innen durchführen
            """,
            isTimeBased: false,
            timeUnit: "Wdh"
        )
    ]
    
    // MARK: - Default Staple Foods
    
    struct SeedFood {
        let name: String
        let calories: Double
        let protein: Double
        let carbs: Double
        let fat: Double
    }
    
    func seedDefaultFoodsIfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: hasSeededDefaultFoodsKey) else { return }
        
        let descriptor = FetchDescriptor<SavedFood>()
        let existingFoods = (try? context.fetch(descriptor)) ?? []
        let existingNames = Set(existingFoods.map { $0.name.lowercased() })
        
        for (idx, item) in Self.defaultStapleFoods.enumerated() {
            if !existingNames.contains(item.name.lowercased()) {
                let food = SavedFood(
                    name: item.name,
                    caloriesPer100g: item.calories,
                    proteinPer100g: item.protein,
                    carbsPer100g: item.carbs,
                    fatPer100g: item.fat
                )
                // Place seeded staple foods chronologically behind user-created items
                food.createdAt = Date(timeIntervalSince1970: 1_700_000_000 + Double(idx))
                context.insert(food)
            }
        }
        
        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: hasSeededDefaultFoodsKey)
        } catch {
            print("Failed to save default foods: \(error)")
        }
    }
    
    static let defaultStapleFoods: [SeedFood] = [
        // Fleisch, Fisch & Eier
        SeedFood(name: "Hähnchenbrustfilet (roh)", calories: 110, protein: 23.0, carbs: 0.0, fat: 1.5),
        SeedFood(name: "Putenbrustfilet (roh)", calories: 106, protein: 24.0, carbs: 0.0, fat: 1.0),
        SeedFood(name: "Rinderhackfleisch (mager, 5% Fett)", calories: 137, protein: 21.0, carbs: 0.0, fat: 5.0),
        SeedFood(name: "Lachsfilet (frisch)", calories: 208, protein: 20.0, carbs: 0.0, fat: 13.0),
        SeedFood(name: "Thunfisch (im eigenen Saft)", calories: 111, protein: 25.5, carbs: 0.0, fat: 1.0),
        SeedFood(name: "Hühnerei (ganz)", calories: 155, protein: 13.0, carbs: 1.1, fat: 11.0),
        SeedFood(name: "Eiklar / Eiweiß (flüssig)", calories: 48, protein: 11.0, carbs: 0.7, fat: 0.1),
        
        // Milchprodukte & Protein
        SeedFood(name: "Magerquark", calories: 67, protein: 12.0, carbs: 4.1, fat: 0.2),
        SeedFood(name: "Skyr (Natur)", calories: 63, protein: 11.0, carbs: 4.0, fat: 0.2),
        SeedFood(name: "Griechischer Joghurt (0,2% Fett)", calories: 57, protein: 10.0, carbs: 3.6, fat: 0.2),
        SeedFood(name: "Naturjoghurt (1,5% Fett)", calories: 48, protein: 3.8, carbs: 4.7, fat: 1.5),
        SeedFood(name: "Körniger Frischkäse (fettarm)", calories: 98, protein: 12.5, carbs: 3.3, fat: 4.0),
        SeedFood(name: "Mozzarella Light", calories: 157, protein: 20.0, carbs: 2.0, fat: 8.5),
        SeedFood(name: "Milch (1,5% Fett)", calories: 47, protein: 3.4, carbs: 4.8, fat: 1.5),
        SeedFood(name: "Haferdrink (ungesüßt)", calories: 43, protein: 0.8, carbs: 6.5, fat: 1.5),
        SeedFood(name: "Whey Protein Pulver (Standard)", calories: 375, protein: 80.0, carbs: 5.0, fat: 3.0),
        
        // Getreide, Beilagen & Brot
        SeedFood(name: "Haferflocken (zart)", calories: 372, protein: 13.5, carbs: 58.7, fat: 7.0),
        SeedFood(name: "Basmatireis (trocken)", calories: 350, protein: 7.5, carbs: 77.5, fat: 0.7),
        SeedFood(name: "Basmatireis (gekocht)", calories: 121, protein: 2.7, carbs: 26.0, fat: 0.3),
        SeedFood(name: "Nudeln / Pasta (trocken)", calories: 355, protein: 12.0, carbs: 71.0, fat: 1.5),
        SeedFood(name: "Nudeln / Pasta (gekocht)", calories: 150, protein: 5.0, carbs: 30.0, fat: 0.7),
        SeedFood(name: "Kartoffeln (roh)", calories: 73, protein: 2.0, carbs: 15.0, fat: 0.1),
        SeedFood(name: "Süßkartoffel (roh)", calories: 86, protein: 1.6, carbs: 20.0, fat: 0.1),
        SeedFood(name: "Vollkornbrot", calories: 215, protein: 7.5, carbs: 41.0, fat: 1.5),
        SeedFood(name: "Reiswaffeln (ungesalzen)", calories: 387, protein: 8.0, carbs: 81.5, fat: 2.8),
        
        // Obst & Gemüse
        SeedFood(name: "Banane", calories: 89, protein: 1.1, carbs: 22.8, fat: 0.3),
        SeedFood(name: "Apfel", calories: 52, protein: 0.3, carbs: 13.8, fat: 0.2),
        SeedFood(name: "Heidelbeeren / Blaubeeren", calories: 57, protein: 0.7, carbs: 14.5, fat: 0.3),
        SeedFood(name: "Erdbeeren", calories: 32, protein: 0.7, carbs: 7.7, fat: 0.3),
        SeedFood(name: "Brokkoli", calories: 34, protein: 2.8, carbs: 6.6, fat: 0.4),
        SeedFood(name: "Spinat (frisch)", calories: 23, protein: 2.9, carbs: 3.6, fat: 0.4),
        SeedFood(name: "Tomate", calories: 18, protein: 0.9, carbs: 3.9, fat: 0.2),
        SeedFood(name: "Gurke", calories: 15, protein: 0.7, carbs: 3.6, fat: 0.1),
        SeedFood(name: "Paprika (rot)", calories: 31, protein: 1.0, carbs: 6.0, fat: 0.3),
        SeedFood(name: "Karotte / Möhre", calories: 41, protein: 0.9, carbs: 9.6, fat: 0.2),
        
        // Fette, Nüsse & Hülsenfrüchte
        SeedFood(name: "Avocado", calories: 160, protein: 2.0, carbs: 8.5, fat: 14.7),
        SeedFood(name: "Olivenöl", calories: 884, protein: 0.0, carbs: 0.0, fat: 100.0),
        SeedFood(name: "Butter", calories: 741, protein: 0.7, carbs: 0.6, fat: 82.0),
        SeedFood(name: "Erdnussbutter (100% Natur)", calories: 588, protein: 25.0, carbs: 12.0, fat: 50.0),
        SeedFood(name: "Mandeln", calories: 579, protein: 21.2, carbs: 9.5, fat: 49.9),
        SeedFood(name: "Walnüsse", calories: 654, protein: 15.2, carbs: 7.0, fat: 65.2),
        SeedFood(name: "Kichererbsen (gekocht)", calories: 164, protein: 8.9, carbs: 27.4, fat: 2.6),
        SeedFood(name: "Tofu (Natur)", calories: 125, protein: 13.0, carbs: 1.9, fat: 7.0)
    ]
}
