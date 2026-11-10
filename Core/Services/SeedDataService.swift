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
}
