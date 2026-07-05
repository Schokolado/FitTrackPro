import Foundation

struct EnergyCalculator {
    /// Berechnet den aktuellen Energie-Level ("Akku") für den heutigen Tag
    /// - Parameters:
    ///   - lastNightSleepHours: Stunden Schlaf der vergangenen Nacht
    ///   - sleepGoalHours: Das Schlafziel (z.B. 8.0)
    ///   - recoveryScore: Der Recovery-Score von heute (0-100)
    ///   - stepsToday: Heutige Schritte
    ///   - activeCaloriesToday: Heutige Aktivitätskalorien
    ///   - workoutsToday: Anzahl der Workouts heute
    ///   - wakeUpTime: Aufwachzeit (falls bekannt), sonst 7:00 Uhr
    static func calculate(
        lastNightSleepHours: Double?,
        sleepGoalHours: Double,
        recoveryScore: Double?,
        stepsToday: Int,
        activeCaloriesToday: Double?,
        workoutsToday: Int,
        wakeUpTime: Date? = nil
    ) -> EnergyResult {
        
        // --- 1. Startkapazität am Morgen ---
        // Gewichtung: 60% Schlaf, 40% Recovery (falls vorhanden, sonst 100% Schlaf)
        var morningCapacity = 100.0
        
        var sleepRatio = 1.0
        if let sleep = lastNightSleepHours {
            sleepRatio = min(sleep / max(sleepGoalHours, 1), 1.0)
        }
        let sleepPoints = sleepRatio * 100.0
        
        if let rec = recoveryScore {
            morningCapacity = (sleepPoints * 0.6) + (rec * 0.4)
        } else {
            morningCapacity = sleepPoints
        }
        
        // --- 2. Passiver Verbrauch (Zeit) ---
        // Annahme: Pro wacher Stunde verlieren wir ca. 2% Energie (bei 16h wach = 32% passiv)
        let now = Date()
        let calendar = Calendar.current
        var wakeDate = wakeUpTime
        
        if wakeDate == nil {
            // Default 7:00 AM
            wakeDate = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: now)
            if wakeDate! > now { // Wenn es vor 7 Uhr ist, nehmen wir 0 Stunden
                wakeDate = now
            }
        }
        
        var hoursAwake = now.timeIntervalSince(wakeDate!) / 3600.0
        if hoursAwake < 0 { hoursAwake = 0 }
        let passiveDrain = min(hoursAwake * 2.0, 40.0) // Max 40% passiver Drain
        
        // --- 3. Aktiver Verbrauch (Schritte / Kalorien) ---
        // Wenn wir activeCalories haben, nutzen wir diese. 
        // Annahme: 100 kcal = 2% Drain.
        // Wenn keine Kalorien: 1000 Schritte = 2% Drain.
        var stepsDrain = 0.0
        if let cal = activeCaloriesToday, cal > 0 {
            stepsDrain = (cal / 100.0) * 2.0
        } else {
            stepsDrain = (Double(stepsToday) / 1000.0) * 2.0
        }
        
        // --- 4. Training Verbrauch ---
        // 15% pro Workout
        let workoutDrain = Double(workoutsToday) * 15.0
        
        let morningCapInt = Int(round(morningCapacity))
        let passiveDrainInt = Int(round(passiveDrain))
        let stepsDrainInt = Int(round(stepsDrain))
        let workoutDrainInt = Int(round(workoutDrain))
        
        let totalDrainInt = passiveDrainInt + stepsDrainInt + workoutDrainInt
        var currentEnergyInt = morningCapInt - totalDrainInt
        
        // Clamp
        if currentEnergyInt < 0 { currentEnergyInt = 0 }
        if currentEnergyInt > 100 { currentEnergyInt = 100 }
        
        return EnergyResult(
            currentEnergy: currentEnergyInt,
            morningCapacity: morningCapInt,
            sleepPoints: Int(round(sleepPoints)),
            recoveryPoints: Int(round(recoveryScore ?? 100)),
            passiveDrain: passiveDrainInt,
            stepsDrain: stepsDrainInt,
            workoutDrain: workoutDrainInt,
            totalDrain: totalDrainInt,
            activeCaloriesBurned: activeCaloriesToday,
            steps: stepsToday,
            workoutsCount: workoutsToday,
            lastNightSleepHours: lastNightSleepHours,
            sleepGoalHours: sleepGoalHours,
            recoveryScore: recoveryScore
        )
    }
}
