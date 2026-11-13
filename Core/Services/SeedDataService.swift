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
    private let hasUpgradedMobilityPlansKey = "hasUpgradedMobilityPlansV4"
    private let hasSeededDefaultFoodsKey = "hasSeededDefaultFoodsV3"
    
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
        upgradeMobilityPlansIfNeeded(context: context)
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
            allExercises.first { !$0.isCustom && $0.name.localizedStandardCompare(keyword) == .orderedSame }
                ?? allExercises.first { !$0.isCustom && $0.name.localizedCaseInsensitiveContains(keyword) && !$0.name.contains("&") }
                ?? allExercises.first { !$0.isCustom && $0.name.localizedCaseInsensitiveContains(keyword) }
                ?? allExercises.first { $0.name.localizedCaseInsensitiveContains(keyword) }
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
                            supersetGroup: exSpec.supersetGroup,
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
    
    /// Upgrades standard mobility plans for existing installations:
    /// - Separates combined legacy exercises (Chin Tucks & Wall Slides, Katze-Kuh & Threading the Needle, Pallof Press / Deadbugs, Hüftkreise & Beinschwünge)
    /// - Adds the dedicated Lower Body & Hamstring stretch plan ("Mobility D")
    func upgradeMobilityPlansIfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: hasUpgradedMobilityPlansKey) else { return }
        
        let groupDescriptor = FetchDescriptor<PlanGroup>()
        let existingGroups = (try? context.fetch(groupDescriptor)) ?? []
        let mobilityGroup = existingGroups.first(where: {
            $0.name.lowercased() == "mobilität" || $0.name.lowercased() == "mobility"
        })
        
        let planDescriptor = FetchDescriptor<TrainingPlan>()
        let existingPlans = (try? context.fetch(planDescriptor)) ?? []
        let allExercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        
        func findExercise(_ keyword: String) -> Exercise? {
            allExercises.first { !$0.isCustom && $0.name.localizedStandardCompare(keyword) == .orderedSame }
                ?? allExercises.first { !$0.isCustom && $0.name.localizedCaseInsensitiveContains(keyword) && !$0.name.contains("&") && !$0.name.contains("/") }
                ?? allExercises.first { !$0.isCustom && $0.name.localizedCaseInsensitiveContains(keyword) }
                ?? allExercises.first { $0.name.localizedCaseInsensitiveContains(keyword) }
        }
        
        // Upgrade Tag B if it still has combined Chin Tucks & Wall Slides
        if let planB = existingPlans.first(where: { $0.name.contains("Mobility B") }) {
            var exercises = (planB.planExercises ?? []).sorted(by: { $0.sortOrder < $1.sortOrder })
            if let oldIdx = exercises.firstIndex(where: { $0.exercise?.name.contains("&") == true && $0.exercise?.name.contains("Chin") == true }) {
                let oldEx = exercises[oldIdx]
                context.delete(oldEx)
                exercises.remove(at: oldIdx)
                
                var newItems: [PlanExercise] = []
                if let chinEx = findExercise("Chin Tucks") {
                    newItems.append(PlanExercise(
                        sortOrder: oldIdx,
                        targetSets: 2,
                        targetReps: 12,
                        restDuration: 15,
                        planSpecificNotes: "**2 Sätze á 12 Wdh.**\nDoppelkinn-Aktivierung für die tiefen Nackenbeuger.",
                        plan: planB,
                        exercise: chinEx
                    ))
                }
                if let wallEx = findExercise("Wall Slides") {
                    newItems.append(PlanExercise(
                        sortOrder: oldIdx + 1,
                        targetSets: 2,
                        targetReps: 12,
                        restDuration: 30,
                        planSpecificNotes: "**2 Sätze á 12 Wdh.**\nAufrechte Wall Slides für unteren Trapez & Rhomboiden.",
                        plan: planB,
                        exercise: wallEx
                    ))
                }
                for (offset, item) in newItems.enumerated() {
                    context.insert(item)
                    exercises.insert(item, at: oldIdx + offset)
                }
                for (idx, ex) in exercises.enumerated() {
                    ex.sortOrder = idx
                }
                planB.planExercises = exercises
            }
        }
        
        // Upgrade Tag C if it still has combined exercises
        if let planC = existingPlans.first(where: { $0.name.contains("Mobility C") }) {
            var exercises = (planC.planExercises ?? []).sorted(by: { $0.sortOrder < $1.sortOrder })
            var hasChanges = false
            
            // 1. Replace Katze-Kuh & Threading the Needle
            if let oldIdx = exercises.firstIndex(where: { $0.exercise?.name.contains("Katze") == true && $0.exercise?.name.contains("&") == true }) {
                let oldEx = exercises[oldIdx]
                context.delete(oldEx)
                exercises.remove(at: oldIdx)
                var added: [PlanExercise] = []
                if let katze = findExercise("Katze-Kuh") {
                    added.append(PlanExercise(sortOrder: oldIdx, targetSets: 1, targetReps: 10, restDuration: 15, planSpecificNotes: "**10–12 Wdh.**\nMobilisierung von BWS & LWS im Vierfüßlerstand.", plan: planC, exercise: katze))
                }
                if let thread = findExercise("Threading the Needle") {
                    added.append(PlanExercise(sortOrder: oldIdx + 1, targetSets: 1, targetReps: 10, restDuration: 15, planSpecificNotes: "**10 Wdh. pro Seite**\nRotations-Mobilisierung der Brustwirbelsäule.", plan: planC, exercise: thread))
                }
                for (offset, item) in added.enumerated() {
                    context.insert(item)
                    exercises.insert(item, at: oldIdx + offset)
                }
                hasChanges = true
            }
            
            // 2. Replace Pallof Press / Deadbugs
            if let oldIdx = exercises.firstIndex(where: { $0.exercise?.name.contains("Pallof") == true && ($0.exercise?.name.contains("/") == true || $0.exercise?.name.contains("Deadbug") == true) }) {
                let oldEx = exercises[oldIdx]
                context.delete(oldEx)
                exercises.remove(at: oldIdx)
                var added: [PlanExercise] = []
                if let pallof = findExercise("Pallof Press") {
                    added.append(PlanExercise(sortOrder: oldIdx, targetSets: 2, targetReps: 12, restDuration: 30, planSpecificNotes: "**2 Sätze á 10–12 Wdh.**\nRumpfstabilität ohne Überlastung der Hüftbeuger.", plan: planC, exercise: pallof))
                }
                if let deadbug = findExercise("Deadbugs") {
                    added.append(PlanExercise(sortOrder: oldIdx + 1, targetSets: 2, targetReps: 12, restDuration: 30, planSpecificNotes: "**2 Sätze á 12 Wdh.**\nDiagonale Rumpf-Aktivierung, LWS am Boden.", plan: planC, exercise: deadbug))
                }
                for (offset, item) in added.enumerated() {
                    context.insert(item)
                    exercises.insert(item, at: oldIdx + offset)
                }
                hasChanges = true
            }
            
            // 3. Replace Dynamische Hüftkreise & Beinschwünge
            if let oldIdx = exercises.firstIndex(where: { $0.exercise?.name.contains("Hüftkreise") == true && $0.exercise?.name.contains("&") == true }) {
                let oldEx = exercises[oldIdx]
                context.delete(oldEx)
                exercises.remove(at: oldIdx)
                var added: [PlanExercise] = []
                if let kreise = findExercise("Dynamische Hüftkreise") {
                    added.append(PlanExercise(sortOrder: oldIdx, targetSets: 1, targetReps: 10, restDuration: 15, planSpecificNotes: "**10–12 Wdh. pro Seite**\nHüftgelenke vor Belastung dynamisch schmieren.", plan: planC, exercise: kreise))
                }
                if let schwung = findExercise("Dynamische Beinschwünge") {
                    added.append(PlanExercise(sortOrder: oldIdx + 1, targetSets: 1, targetReps: 10, restDuration: 15, planSpecificNotes: "**10–12 Wdh. pro Seite**\nDynamische Hamstring- & Hüftbeuger-Dehnung.", plan: planC, exercise: schwung))
                }
                for (offset, item) in added.enumerated() {
                    context.insert(item)
                    exercises.insert(item, at: oldIdx + offset)
                }
                hasChanges = true
            }
            
            if hasChanges {
                for (idx, ex) in exercises.enumerated() {
                    ex.sortOrder = idx
                }
                planC.planExercises = exercises
            }
        }
        
        // 4. Ensure Tag D exists
        let existingPlanNames = Set(existingPlans.map { $0.name })
        if let specD = Self.mobilityPlanSpecs.first(where: { $0.name.contains("Mobility D") }),
           !existingPlanNames.contains(specD.name) {
            let targetGroup = mobilityGroup ?? {
                let g = PlanGroup(name: "Mobilität", sortOrder: existingGroups.count)
                context.insert(g)
                return g
            }()
            let planD = TrainingPlan(
                name: specD.name,
                notes: specD.notes,
                sortOrder: existingPlans.count,
                group: targetGroup
            )
            context.insert(planD)
            for (exIdx, exSpec) in specD.exercises.enumerated() {
                if let ex = findExercise(exSpec.keyword) {
                    let planEx = PlanExercise(
                        sortOrder: exIdx,
                        supersetGroup: exSpec.supersetGroup,
                        targetSets: exSpec.sets,
                        targetReps: exSpec.reps,
                        targetWeight: nil,
                        restDuration: exSpec.rest,
                        planSpecificNotes: exSpec.note,
                        plan: planD,
                        exercise: ex
                    )
                    context.insert(planEx)
                }
            }
        }
        
        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: hasUpgradedMobilityPlansKey)
        } catch {
            print("Failed to upgrade mobility plans: \(error)")
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
    
    struct PlanExerciseSeedSpec {
        let keyword: String
        let sets: Int
        let reps: Int
        let rest: TimeInterval
        let note: String
        var supersetGroup: Int? = nil
    }
    
    struct PlanSeedSpec {
        let name: String
        let notes: String
        let exercises: [PlanExerciseSeedSpec]
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
                PlanExerciseSeedSpec(keyword: "Couch Stretch", sets: 2, reps: 2, rest: 15, note: "**2 Min. pro Seite** *(4 Min. gesamt)*\nBecken aktiv aufrichten & hinteren Po fest anspannen."),
                PlanExerciseSeedSpec(keyword: "Taube / Pigeon Pose", sets: 2, reps: 2, rest: 15, note: "**1,5–2 Min. pro Seite** *(3–4 Min. gesamt)*\nOberkörper kontrolliert nach vorne neigen."),
                PlanExerciseSeedSpec(keyword: "90/90 Hüftrotation", sets: 1, reps: 2, rest: 15, note: "**1,5–2 Min.** *(dynamisch)*\nBeide Beine im 90°-Winkel geführt rotieren."),
                PlanExerciseSeedSpec(keyword: "Triggerpunkt-Behandlung", sets: 1, reps: 3, rest: 15, note: "**2–3 Min.** mit Lacrosse-/Tennisball\nSchmerzhafte Punkte **30–60 Sek.** unter tiefem Ausatmen halten."),
                PlanExerciseSeedSpec(keyword: "Plank mit Beckenkippung", sets: 2, reps: 45, rest: 30, note: "**2 Sätze á 45 Sek.**\nBecken aktiv nach hinten kippen *(Posterior Pelvic Tilt)*.")
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
                PlanExerciseSeedSpec(keyword: "BWS-Extension", sets: 1, reps: 12, rest: 15, note: "**2 Min.** *(10–12 Wdh.)*\nFaszienrolle auf Höhe der Schulterblätter positionieren."),
                PlanExerciseSeedSpec(keyword: "Thorax-Rotation", sets: 2, reps: 10, rest: 15, note: "**10 Wdh. pro Seite** *(ca. 2–3 Min.)*\nBlick folgt beim Aufdrehen stets der Hand."),
                PlanExerciseSeedSpec(keyword: "Doorway Chest Stretch", sets: 2, reps: 2, rest: 15, note: "**1–1,5 Min. pro Seite** *(3 Min. gesamt)*\nUnterarm am Türrahmen, Oberkörper leicht eindrehen."),
                PlanExerciseSeedSpec(keyword: "Chin Tucks", sets: 2, reps: 12, rest: 15, note: "**2 Sätze á 12 Wdh.** *(ca. 2 Min.)*\nDoppelkinn-Aktivierung für die tiefen Nackenbeuger."),
                PlanExerciseSeedSpec(keyword: "Wall Slides", sets: 2, reps: 12, rest: 30, note: "**2 Sätze á 12 Wdh.** *(ca. 2–3 Min.)*\nAufrechte Wall Slides für unteren Trapez & Rhomboiden."),
                PlanExerciseSeedSpec(keyword: "Faszienbehandlung (Oberer Rücken)", sets: 1, reps: 3, rest: 15, note: "**3 Min.** mit Duoball\nDornfortsätze der Wirbelsäule unbedingt aussparen.")
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
                PlanExerciseSeedSpec(keyword: "Katze-Kuh", sets: 1, reps: 10, rest: 15, note: "**10–12 Wdh.**\nMobilisierung von BWS & LWS im Vierfüßlerstand."),
                PlanExerciseSeedSpec(keyword: "Threading the Needle", sets: 1, reps: 10, rest: 15, note: "**10 Wdh. pro Seite**\nRotations-Mobilisierung der Brustwirbelsäule."),
                PlanExerciseSeedSpec(keyword: "Glute Bridge mit Miniband", sets: 2, reps: 15, rest: 30, note: "**2 Sätze á 15 Wdh.**\nGezielte Gesäß-Aktivierung vor Kniebeugen & Kreuzheben."),
                PlanExerciseSeedSpec(keyword: "Pallof Press", sets: 2, reps: 12, rest: 30, note: "**2 Sätze á 10–12 Wdh.**\nRumpfstabilität ohne Überlastung der Hüftbeuger."),
                PlanExerciseSeedSpec(keyword: "Deadbugs", sets: 2, reps: 12, rest: 30, note: "**2 Sätze á 12 Wdh.**\nDiagonale Rumpf-Aktivierung, LWS fest am Boden."),
                PlanExerciseSeedSpec(keyword: "Dynamische Hüftkreise", sets: 1, reps: 10, rest: 15, note: "**10–12 Wdh. pro Seite**\nHüftgelenke vor Belastung dynamisch mobilisieren & schmieren."),
                PlanExerciseSeedSpec(keyword: "Dynamische Beinschwünge", sets: 1, reps: 10, rest: 15, note: "**10–12 Wdh. pro Seite**\nDynamische Hamstring- & Hüftbeuger-Dehnung vor Kniebeugen.")
            ]
        ),
        PlanSeedSpec(
            name: "Mobility D: Dehnen Unterkörper, Hamstrings & Hüfte",
            notes: """
            # Tag D: Dehnen Unterkörper, Hamstrings & Hüfte
            **Dauer:** ca. 15–20 Minuten

            ## 🎯 Fokus & Ziel
            - Intensive Dehnung der verkürzten Beinbeuger (Hamstrings)
            - Hüftöffnung und Entlastung des Beckens (Couch Stretch & Pigeon Pose)
            - Adduktoren dehnen & Beweglichkeit des Sprunggelenks (Wadendehnung)
            - Linderung von Spannung im unteren Rücken durch gezielte Bein- & Hüftentlastung

            ---
            *Perfekt an trainingsfreien Tagen, nach Lauf- und Beineinheiten oder abends zur Regeneration.*
            """,
            exercises: [
                PlanExerciseSeedSpec(keyword: "Dynamische Hüftkreise", sets: 1, reps: 10, rest: 15, note: "**10 Wdh. pro Seite**\nSanftes Aufwärmen und Schmieren der Hüftgelenke."),
                PlanExerciseSeedSpec(keyword: "Dynamische Beinschwünge", sets: 1, reps: 10, rest: 15, note: "**10–12 Wdh. pro Seite**\nDynamische Vorbereitung von Beinbeugern und Hüftstreckern."),
                PlanExerciseSeedSpec(keyword: "Hamstring-Dehnung", sets: 2, reps: 2, rest: 15, note: "**1,5–2 Min. pro Seite** *(3–4 Min. gesamt)*\nMit geradem Rücken aus der Hüfte nach vorne beugen."),
                PlanExerciseSeedSpec(keyword: "Couch Stretch", sets: 2, reps: 2, rest: 15, note: "**2 Min. pro Seite** *(4 Min. gesamt)*\nHüftbeuger und vorderen Oberschenkel tief dehnen."),
                PlanExerciseSeedSpec(keyword: "Taube / Pigeon Pose", sets: 2, reps: 2, rest: 15, note: "**1,5–2 Min. pro Seite** *(3–4 Min. gesamt)*\nGluteus & Piriformis intensiv dehnen, ISG entlasten."),
                PlanExerciseSeedSpec(keyword: "Adduktoren-Dehnung", sets: 2, reps: 2, rest: 15, note: "**1,5–2 Min.** in Frosch-Pose\nKnie weit öffnen, Gesäß vorsichtig nach hinten schieben."),
                PlanExerciseSeedSpec(keyword: "90/90 Hüftrotation", sets: 1, reps: 2, rest: 15, note: "**2 Min.** geführte Wechsel\nInnen- und Außenrotation der Hüfte ausgleichen."),
                PlanExerciseSeedSpec(keyword: "Wadendehnung", sets: 2, reps: 1, rest: 15, note: "**1–1,5 Min. pro Seite**\nHintere Ferse fest in den Boden drücken, Achillessehne dehnen.")
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
            name: "Chin Tucks (Doppelkinn-Aktivierung)",
            category: "Mobilität",
            defaultRestDuration: 15,
            sortOrder: 88,
            notes: """
            ### 🎯 Ziel / Fokus
            Nacken entlasten, tiefe Nackenbeuger stärken, Haltung verbessern.

            ### ⏱️ Dauer / Umfang
            **2 Sätze á 12 Wdh.** *(ca. 2 Min.)*

            ### 📋 Ausführung
            - Aufrecht stehen oder sitzen
            - Kinn waagerecht nach hinten-unten schieben (Doppelkinn formen)
            - Position 2–3 Sek. halten und kontrolliert lösen
            - Blick bleibt geradeaus gerichtet
            """,
            isTimeBased: false,
            timeUnit: "Wdh"
        ),
        SeedExercise(
            name: "Wall Slides (Schulter- & BWS-Aktivierung)",
            category: "Mobilität",
            defaultRestDuration: 30,
            sortOrder: 89,
            notes: """
            ### 🎯 Ziel / Fokus
            Aufrichtung der Brustwirbelsäule, Aktivierung von unterem Trapez und Rhomboiden.

            ### ⏱️ Dauer / Umfang
            **2 Sätze á 12 Wdh.** *(ca. 2–3 Min.)*

            ### 📋 Ausführung
            - Mit Rücken und Hinterkopf flach an eine Wand stellen
            - Arme in 90°-U-Haltung an die Wand anlegen
            - Unterarme und Handrücken an der Wand entlang nach oben gleiten lassen
            """,
            isTimeBased: false,
            timeUnit: "Wdh"
        ),
        SeedExercise(
            name: "Katze-Kuh (Cat-Cow)",
            category: "Mobilität",
            defaultRestDuration: 15,
            sortOrder: 91,
            notes: """
            ### 🎯 Ziel / Fokus
            Mobilisierung und Durchbewegung von Brust- und Lendenwirbelsäule (BWS & LWS).

            ### ⏱️ Dauer / Umfang
            **10–12 Wdh.** *(ca. 1–2 Min.)*

            ### 📋 Ausführung
            - Im Vierfüßlerstand: Mit der Einatmung Brustbein heben und Rücken leicht durchhängen lassen *(Kuh)*
            - Mit der Ausatmung Rücken maximal runden und Kinn zur Brust ziehen *(Katze)*
            """,
            isTimeBased: false,
            timeUnit: "Wdh"
        ),
        SeedExercise(
            name: "Threading the Needle (BWS-Rotation)",
            category: "Mobilität",
            defaultRestDuration: 15,
            sortOrder: 92,
            notes: """
            ### 🎯 Ziel / Fokus
            Rotation der Brustwirbelsäule, Öffnung der Schulter und Entlastung der Schulterblätter.

            ### ⏱️ Dauer / Umfang
            **10 Wdh. pro Seite** *(ca. 2 Min.)*

            ### 📋 Ausführung
            - Aus dem Vierfüßlerstand einen Arm zur Decke öffnen
            - Anschließend den Arm unter dem Brustkorb durchfädeln, bis Schulter und Kopf sanft ablegen
            - Tief und gleichmäßig in die Drehung atmen
            """,
            isTimeBased: false,
            timeUnit: "Wdh"
        ),
        SeedExercise(
            name: "Pallof Press (Kabelzug oder Band)",
            category: "Mobilität",
            defaultRestDuration: 30,
            sortOrder: 94,
            notes: """
            ### 🎯 Ziel / Fokus
            Antirotation & Rumpfstabilität aufbauen ohne Überlastung der Hüftbeuger.

            ### ⏱️ Dauer / Umfang
            **2 Sätze á 10–12 Wiederholungen**

            ### 📋 Ausführung
            - Seitlich zum Kabelzug oder Widerstandsband aufstellen, Griff vor die Brust halten
            - Arme kontrolliert gerade nach vorne strecken, Rotation im Rumpf aktiv verhindern
            - 1–2 Sekunden halten und langsam zurück zur Brust führen
            """,
            isTimeBased: false,
            timeUnit: "Wdh"
        ),
        SeedExercise(
            name: "Deadbugs (Käfer-Übung)",
            category: "Mobilität",
            defaultRestDuration: 30,
            sortOrder: 95,
            notes: """
            ### 🎯 Ziel / Fokus
            Tiefe Core-Stabilität und Koordination, Lendenwirbelsäule gegen Hohlkreuz stabilisieren.

            ### ⏱️ Dauer / Umfang
            **2 Sätze á 12 Wdh. (6 pro Seite)**

            ### 📋 Ausführung
            - In Rückenlage Beine im 90°-Winkel anheben, Arme senkrecht nach oben strecken
            - Diagonal gegengleichen Arm und Bein kontrolliert absenken
            - **Wichtig:** Unterer Rücken bleibt durchgehend flach auf den Boden gepresst
            """,
            isTimeBased: false,
            timeUnit: "Wdh"
        ),
        SeedExercise(
            name: "Dynamische Hüftkreise",
            category: "Mobilität",
            defaultRestDuration: 15,
            sortOrder: 96,
            notes: """
            ### 🎯 Ziel / Fokus
            Gelenkschmierung und Vorbereitung der Hüftinnen- und Außenrotation.

            ### ⏱️ Dauer / Umfang
            **10–12 Wdh. pro Seite**

            ### 📋 Ausführung
            - Aufrecht stehen, bei Bedarf leicht an einer Wand abstützen
            - Knie anheben und weite, geführte Kreise von innen nach außen und umgekehrt ziehen
            - Becken dabei möglichst stabil und gerade halten
            """,
            isTimeBased: false,
            timeUnit: "Wdh"
        ),
        SeedExercise(
            name: "Dynamische Beinschwünge",
            category: "Mobilität",
            defaultRestDuration: 15,
            sortOrder: 97,
            notes: """
            ### 🎯 Ziel / Fokus
            Dynamische Dehnung der Hamstrings (Beinbeuger) und Hüftbeuger vor dem Training.

            ### ⏱️ Dauer / Umfang
            **10–12 Wdh. pro Seite**

            ### 📋 Ausführung
            - Seitlich zur Wand stehen und mit einer Hand festhalten
            - Freies Bein kontrolliert vor- und zurückschwingen
            - Schwungamplitude stetig vergrößern, Oberkörper aufrecht halten
            """,
            isTimeBased: false,
            timeUnit: "Wdh"
        ),
        SeedExercise(
            name: "Hamstring-Dehnung (Beinbeuger)",
            category: "Mobilität",
            defaultRestDuration: 15,
            sortOrder: 98,
            notes: """
            ### 🎯 Ziel / Fokus
            Gezielte Dehnung der Ischiocruralen Muskulatur (Hamstrings / Beinbeuger), Linderung von Becken- und LWS-Spannung.

            ### ⏱️ Dauer / Umfang
            **1,5–2 Min. pro Seite** *(3–4 Min. gesamt)*

            ### 📋 Ausführung
            - Ein Bein auf einer leichten Erhöhung oder am Boden gerade ausstrecken, Zehen anziehen
            - Mit gerader Wirbelsäule aus der Hüfte nach vorne beugen
            - Sanften, tiefen Dehnreiz an der Oberschenkelrückseite halten und gleichmäßig atmen
            """,
            isTimeBased: true,
            timeUnit: "Min"
        ),
        SeedExercise(
            name: "Adduktoren-Dehnung (Frosch-Pose)",
            category: "Mobilität",
            defaultRestDuration: 15,
            sortOrder: 99,
            notes: """
            ### 🎯 Ziel / Fokus
            Öffnung der Hüfte, Dehnung der inneren Oberschenkelmuskeln (Adduktoren).

            ### ⏱️ Dauer / Umfang
            **1,5–2 Min.**

            ### 📋 Ausführung
            - Im Vierfüßlerstand Knie weit nach außen schieben, Unterschenkel parallel halten
            - Unterarme auflegen und das Gesäß vorsichtig nach hinten-unten schieben
            - Bei jedem Ausatmen die Dehnung in der Leistengegend vertiefen
            """,
            isTimeBased: true,
            timeUnit: "Min"
        ),
        SeedExercise(
            name: "Wadendehnung (an der Wand)",
            category: "Mobilität",
            defaultRestDuration: 15,
            sortOrder: 100,
            notes: """
            ### 🎯 Ziel / Fokus
            Dehnung von Wadenmuskulatur (Gastrocnemius & Soleus) und Achillessehne, Verbesserung der Sprunggelenksmobilität.

            ### ⏱️ Dauer / Umfang
            **1–1,5 Min. pro Seite** *(2–3 Min. gesamt)*

            ### 📋 Ausführung
            - Vor einer Wand aufstellen, Hände auf Schulterhöhe an die Wand stützen
            - Ein Bein in weitem Ausfallschritt nach hinten stellen, Ferse fest in den Boden drücken
            - Hinteres Knie durchstrecken und vorderes Knie beugen, bis ein deutlicher Zug in der Wade entsteht
            """,
            isTimeBased: true,
            timeUnit: "Min"
        ),
        // Legacy seeds for backward-compatible notes lookup
        SeedExercise(
            name: "Chin Tucks & Wall Slides (Nacken & Rücken)",
            category: "Mobilität",
            defaultRestDuration: 30,
            sortOrder: 188,
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
            name: "Katze-Kuh & Threading the Needle",
            category: "Mobilität",
            defaultRestDuration: 15,
            sortOrder: 190,
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
            name: "Pallof Press / Deadbugs",
            category: "Mobilität",
            defaultRestDuration: 30,
            sortOrder: 192,
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
            sortOrder: 193,
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
    
    struct SeedFood: Codable {
        let name: String
        let calories: Double
        let protein: Double
        let carbs: Double
        let fat: Double
    }
    
    func seedDefaultFoodsIfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: hasSeededDefaultFoodsKey) else { return }
        
        var foodsToSeed: [SeedFood] = []
        if let url = Bundle.main.url(forResource: "DefaultFoods_de", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([SeedFood].self, from: data) {
            foodsToSeed = decoded
        }
        
        if foodsToSeed.isEmpty {
            foodsToSeed = Self.defaultStapleFoods
        }
        
        let descriptor = FetchDescriptor<SavedFood>()
        let existingFoods = (try? context.fetch(descriptor)) ?? []
        let existingNames = Set(existingFoods.map { $0.name.lowercased() })
        
        for (idx, item) in foodsToSeed.enumerated() {
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
        SeedFood(name: "Tofu (Natur)", calories: 125, protein: 13.0, carbs: 1.9, fat: 7.0),
        
        // Österreichische Biere & Radler (Beliebteste Sorten & Marken)
        SeedFood(name: "Gösser Märzen", calories: 42, protein: 0.4, carbs: 3.2, fat: 0.0),
        SeedFood(name: "Gösser NaturRadler Zitrone", calories: 39, protein: 0.2, carbs: 5.8, fat: 0.0),
        SeedFood(name: "Wieselburger Stammbräu", calories: 45, protein: 0.5, carbs: 3.3, fat: 0.0),
        SeedFood(name: "Wieselburger Gold", calories: 43, protein: 0.5, carbs: 3.2, fat: 0.0),
        SeedFood(name: "Ottakringer Helles", calories: 42, protein: 0.4, carbs: 3.1, fat: 0.0),
        SeedFood(name: "Ottakringer Wiener Original", calories: 45, protein: 0.5, carbs: 3.4, fat: 0.0),
        SeedFood(name: "Stiegl Goldbräu", calories: 44, protein: 0.5, carbs: 3.4, fat: 0.0),
        SeedFood(name: "Stiegl Hell", calories: 40, protein: 0.4, carbs: 3.0, fat: 0.0),
        SeedFood(name: "Puntigamer (das bierige Bier)", calories: 42, protein: 0.4, carbs: 3.1, fat: 0.0),
        SeedFood(name: "Zipfer Urtyp", calories: 44, protein: 0.5, carbs: 3.2, fat: 0.0),
        SeedFood(name: "Murauer Märzen", calories: 43, protein: 0.4, carbs: 3.2, fat: 0.0),
        SeedFood(name: "Schwechater Bier", calories: 41, protein: 0.4, carbs: 3.0, fat: 0.0),
        SeedFood(name: "Heineken Premium Lager", calories: 42, protein: 0.4, carbs: 3.2, fat: 0.0),
        SeedFood(name: "Corona Extra", calories: 42, protein: 0.3, carbs: 4.0, fat: 0.0),
        SeedFood(name: "Alkoholfreies Bier (Gösser Naturgold / Null Komma Josef)", calories: 24, protein: 0.4, carbs: 5.2, fat: 0.0),
        
        // Österreichische Brote & Gebäck
        SeedFood(name: "Kaisersemmel / Handsemmel", calories: 260, protein: 8.5, carbs: 53.0, fat: 1.2),
        SeedFood(name: "Kornspitz", calories: 245, protein: 10.0, carbs: 44.0, fat: 2.5),
        SeedFood(name: "Schwarzbrot / Bauernbrot (österreichisch)", calories: 215, protein: 6.5, carbs: 42.0, fat: 1.2),
        SeedFood(name: "Roggenbrot (100% Roggen-Vollkorn)", calories: 210, protein: 6.0, carbs: 41.5, fat: 1.1),
        SeedFood(name: "Dinkelbrot / Dinkel-Vollkornbrot", calories: 225, protein: 9.0, carbs: 43.0, fat: 1.8),
        SeedFood(name: "Vintschgerl / Vinschgauer", calories: 230, protein: 7.5, carbs: 46.0, fat: 1.5),
        SeedFood(name: "Wachauer Laibchen", calories: 250, protein: 8.0, carbs: 50.0, fat: 1.3),
        SeedFood(name: "Salzstangerl", calories: 260, protein: 8.5, carbs: 52.0, fat: 1.5),
        SeedFood(name: "Mohnflesserl", calories: 275, protein: 9.0, carbs: 50.0, fat: 4.0),
        SeedFood(name: "Toastbrot / Buttertoast", calories: 265, protein: 8.0, carbs: 49.0, fat: 3.8),
        
        // Österreichische Klassiker, Fleisch & Wurst
        SeedFood(name: "Wiener Schnitzel (vom Kalb, paniert)", calories: 220, protein: 19.5, carbs: 11.5, fat: 11.0),
        SeedFood(name: "Wiener Schnitzel (vom Schwein / Schweinsschnitzel)", calories: 245, protein: 18.0, carbs: 12.0, fat: 14.5),
        SeedFood(name: "Putenschnitzel (paniert)", calories: 205, protein: 21.0, carbs: 11.5, fat: 8.5),
        SeedFood(name: "Leberkäse / Fleischkäse (gebacken)", calories: 280, protein: 12.0, carbs: 2.0, fat: 25.0),
        SeedFood(name: "Käseleberkäse", calories: 310, protein: 14.0, carbs: 2.0, fat: 28.0),
        SeedFood(name: "Pikantleberkäse", calories: 275, protein: 12.0, carbs: 3.0, fat: 24.0),
        SeedFood(name: "Frankfurter / Wiener Würstchen", calories: 265, protein: 13.0, carbs: 1.0, fat: 23.5),
        SeedFood(name: "Käsekrainer / Krainer („Eitrige“)", calories: 320, protein: 15.0, carbs: 1.5, fat: 29.0),
        SeedFood(name: "Debreziner", calories: 290, protein: 14.0, carbs: 1.0, fat: 26.0),
        SeedFood(name: "Knackwurst / Knacker", calories: 260, protein: 12.5, carbs: 1.5, fat: 23.0),
        SeedFood(name: "Extrawurst (für Wurstsemmel)", calories: 235, protein: 11.5, carbs: 2.0, fat: 20.5),
        SeedFood(name: "Tiroler Speck / Schinkenspeck", calories: 345, protein: 28.0, carbs: 0.5, fat: 26.0),
        SeedFood(name: "Tafelspitz (mageres Rindfleisch gekocht)", calories: 160, protein: 25.0, carbs: 0.0, fat: 6.5),
        SeedFood(name: "Wiener Saftgulasch", calories: 135, protein: 14.0, carbs: 4.5, fat: 7.0),
        SeedFood(name: "Berner Würstel (im Speckmantel)", calories: 335, protein: 15.5, carbs: 1.0, fat: 30.0),
        
        // Österreichische Milchprodukte & Käse
        SeedFood(name: "Speisetopfen mager (Topfen / Magerquark)", calories: 68, protein: 12.5, carbs: 3.5, fat: 0.3),
        SeedFood(name: "Topfen 20% (Brimsen / Bauern-Topfen)", calories: 105, protein: 11.5, carbs: 3.5, fat: 4.8),
        SeedFood(name: "Vorarlberger Bergkäse / Bergkäse", calories: 380, protein: 29.0, carbs: 0.1, fat: 30.0),
        SeedFood(name: "Emmentaler (österreichisch)", calories: 385, protein: 28.5, carbs: 0.1, fat: 30.5),
        SeedFood(name: "Gouda (45% F.i.T.)", calories: 360, protein: 24.5, carbs: 0.5, fat: 29.0),
        SeedFood(name: "Liptauer Aufstrich", calories: 195, protein: 8.5, carbs: 3.0, fat: 16.5),
        SeedFood(name: "Sauerrahm (15% Fett)", calories: 160, protein: 3.0, carbs: 4.0, fat: 15.0),
        SeedFood(name: "Schlagobers / Schlagsahne (36% Fett)", calories: 345, protein: 2.4, carbs: 3.2, fat: 36.0),
        SeedFood(name: "Buttermilch (österreichisch)", calories: 38, protein: 3.5, carbs: 4.0, fat: 0.9),
        
        // Beilagen, Suppen & Knödel
        SeedFood(name: "Erdäpfelsalat (mit Essig & Öl)", calories: 95, protein: 1.8, carbs: 13.5, fat: 3.8),
        SeedFood(name: "Erdäpfelpüree (mit Milch & Butter)", calories: 105, protein: 2.2, carbs: 14.5, fat: 4.2),
        SeedFood(name: "Semmelknödel", calories: 185, protein: 6.0, carbs: 30.0, fat: 4.5),
        SeedFood(name: "Kaspressknödel", calories: 240, protein: 11.0, carbs: 24.0, fat: 11.0),
        SeedFood(name: "Tiroler Speckknödel", calories: 215, protein: 8.5, carbs: 26.0, fat: 8.5),
        SeedFood(name: "Frittatensuppe (Bouillon mit Frittaten)", calories: 45, protein: 2.5, carbs: 4.0, fat: 2.0),
        SeedFood(name: "Grießnockerlsuppe", calories: 55, protein: 2.2, carbs: 6.0, fat: 2.5),
        SeedFood(name: "Spätzle / Nockerl (gekocht)", calories: 165, protein: 5.5, carbs: 30.0, fat: 2.2),
        SeedFood(name: "Käsespätzle / Kässpätzle", calories: 245, protein: 10.5, carbs: 24.0, fat: 12.0),
        SeedFood(name: "Steirisches Kürbiskernöl g.g.A.", calories: 884, protein: 0.0, carbs: 0.0, fat: 100.0),
        SeedFood(name: "Kürbiskerne (geröstet)", calories: 560, protein: 30.0, carbs: 10.0, fat: 46.0),
        SeedFood(name: "Steirischer Kren (frisch gerieben)", calories: 65, protein: 2.8, carbs: 10.5, fat: 0.8),
        SeedFood(name: "Sauerkraut (gedünstet)", calories: 25, protein: 1.5, carbs: 2.5, fat: 0.5),
        SeedFood(name: "Rotkraut / Blaukraut", calories: 55, protein: 1.2, carbs: 9.5, fat: 1.5),
        
        // Österreichische Mehlspeisen & Süßes
        SeedFood(name: "Kaiserschmarrn (mit Rosinen)", calories: 210, protein: 6.5, carbs: 30.0, fat: 7.0),
        SeedFood(name: "Zwetschkenröster", calories: 90, protein: 0.7, carbs: 21.0, fat: 0.2),
        SeedFood(name: "Apfelstrudel (mit Ziehteig)", calories: 185, protein: 2.5, carbs: 32.0, fat: 5.5),
        SeedFood(name: "Topfenstrudel", calories: 225, protein: 7.5, carbs: 28.0, fat: 9.5),
        SeedFood(name: "Sachertorte (Wiener Schokoladentorte)", calories: 380, protein: 4.5, carbs: 48.0, fat: 19.0),
        SeedFood(name: "Marillenknödel (Topfenteig)", calories: 175, protein: 4.5, carbs: 30.0, fat: 4.0),
        SeedFood(name: "Germknödel (mit Powidl)", calories: 210, protein: 5.0, carbs: 42.0, fat: 2.0),
        SeedFood(name: "Manner Schnitten (Neapolitaner)", calories: 505, protein: 5.5, carbs: 65.0, fat: 25.0),
        SeedFood(name: "Mozartkugeln", calories: 520, protein: 7.0, carbs: 56.0, fat: 29.0),
        SeedFood(name: "Powidl (Pflaumenmus ohne Zucker)", calories: 165, protein: 1.8, carbs: 38.0, fat: 0.5),
        SeedFood(name: "Marillenmarmelade", calories: 240, protein: 0.5, carbs: 58.0, fat: 0.1),
        SeedFood(name: "Topfengolatsche", calories: 310, protein: 8.0, carbs: 40.0, fat: 13.0),
        
        // Getränke & Kaffeehauskultur
        SeedFood(name: "Almdudler Original", calories: 33, protein: 0.0, carbs: 7.9, fat: 0.0),
        SeedFood(name: "Almdudler Zuckerfrei", calories: 2, protein: 0.0, carbs: 0.1, fat: 0.0),
        SeedFood(name: "Red Bull Energy Drink", calories: 46, protein: 0.0, carbs: 11.0, fat: 0.0),
        SeedFood(name: "Red Bull Sugarfree", calories: 3, protein: 0.0, carbs: 0.0, fat: 0.0),
        SeedFood(name: "Wiener Melange (mit geschäumter Milch)", calories: 42, protein: 2.0, carbs: 2.8, fat: 2.4),
        SeedFood(name: "Verlängerter Schwarz", calories: 2, protein: 0.1, carbs: 0.2, fat: 0.0),
        SeedFood(name: "Kleiner Brauner", calories: 25, protein: 0.5, carbs: 0.8, fat: 2.2),
        SeedFood(name: "Grüner Veltliner (Weißwein trocken)", calories: 72, protein: 0.1, carbs: 1.5, fat: 0.0),
        SeedFood(name: "Zweigelt / Blaufränkisch (Rotwein trocken)", calories: 78, protein: 0.1, carbs: 1.8, fat: 0.0),
        SeedFood(name: "Gspritzter / Weißer Spritzer", calories: 36, protein: 0.0, carbs: 0.8, fat: 0.0)
    ]
}
