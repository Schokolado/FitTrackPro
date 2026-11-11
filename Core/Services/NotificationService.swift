import Foundation
import SwiftData
import UserNotifications

class NotificationService {
    static let shared = NotificationService()
    private init() {}

    private enum ReminderID {
        static let restTimer = "rest_timer"
        static let workoutPrefix = "reminder_workout_"
        static let macroToday = "reminder_macro_today"
        static let macroTomorrow = "reminder_macro_tomorrow"
        static let stepsToday = "reminder_steps_today"
        static let stepsTomorrow = "reminder_steps_tomorrow"
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("Notification permission granted.")
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    func scheduleRestTimerNotification(duration: TimeInterval) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [ReminderID.restTimer])

        let content = UNMutableNotificationContent()
        content.title = "Pause beendet!"
        content.body = "Mach dich bereit für den nächsten Satz."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: duration, repeats: false)
        let request = UNNotificationRequest(identifier: ReminderID.restTimer, content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error.localizedDescription)")
            }
        }
    }

    func cancelRestTimerNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [ReminderID.restTimer])
    }

    // MARK: - Konfigurierbare Erinnerungen (Workouts, Makros, Schritte)

    /// Aktualisiert alle geplanten Erinnerungen basierend auf aktuellen Einstellungen und heutigen Daten.
    @MainActor
    func syncReminders(modelContext: ModelContext) {
        let defaults = UserDefaults.standard
        let now = Date()
        let todayString = now.iso8601String()

        scheduleWorkoutReminders(defaults: defaults)

        let foodEntries = (try? modelContext.fetch(FetchDescriptor<FoodEntry>())) ?? []
        let todayFoods = foodEntries.filter {
            $0.dailyLog?.dateString == todayString || Calendar.current.isDateInToday($0.timestamp)
        }
        let consumedProtein = todayFoods.reduce(0.0) { $0 + $1.proteinGrams }
        let consumedCalories = todayFoods.reduce(0.0) { $0 + $1.calories }

        let goalProtein = defaults.object(forKey: "nutritionGoalProtein") as? Double ?? 150
        let goalCalories = defaults.object(forKey: AppStorageKeys.dailyCalorieGoal) as? Double ?? 2500
        scheduleMacroReminders(
            defaults: defaults,
            remainingProtein: max(0, goalProtein - consumedProtein),
            remainingCalories: max(0, goalCalories - consumedCalories),
            now: now
        )

        let manualSteps = ((try? modelContext.fetch(FetchDescriptor<StepEntry>())) ?? [])
            .filter { $0.dateString == todayString }
            .reduce(0) { $0 + $1.steps }
        let cachedDate = defaults.string(forKey: "cached_today_steps_date") ?? ""
        let healthSteps = cachedDate == todayString ? defaults.integer(forKey: "cached_today_steps") : 0
        let stepGoal = defaults.object(forKey: AppStorageKeys.dailyStepGoal) as? Int ?? 10000
        let remainingSteps = max(0, stepGoal - (healthSteps + manualSteps))

        scheduleStepReminders(
            defaults: defaults,
            remainingSteps: remainingSteps,
            stepGoal: stepGoal,
            now: now
        )
    }

    private func scheduleWorkoutReminders(defaults: UserDefaults) {
        let center = UNUserNotificationCenter.current()
        let allIDs = (1...7).map { "\(ReminderID.workoutPrefix)\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: allIDs)

        guard defaults.bool(forKey: AppStorageKeys.workoutReminderEnabled) else { return }

        let hour = defaults.object(forKey: AppStorageKeys.workoutReminderHour) as? Int ?? 17
        let minute = defaults.object(forKey: AppStorageKeys.workoutReminderMinute) as? Int ?? 0
        let weekdaysCSV = defaults.string(forKey: AppStorageKeys.workoutReminderWeekdays) ?? "2,4,6"
        let weekdays = weekdaysCSV.split(separator: ",").compactMap { Int($0) }.filter { (1...7).contains($0) }

        for weekday in weekdays {
            let content = UNMutableNotificationContent()
            content.title = "Zeit für dein Workout"
            content.body = "Starte jetzt deine geplante Trainingseinheit und bleib am Ball!"
            content.sound = .default

            var components = DateComponents()
            components.weekday = weekday
            components.hour = hour
            components.minute = minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: "\(ReminderID.workoutPrefix)\(weekday)", content: content, trigger: trigger)
            center.add(request)
        }
    }

    private func scheduleMacroReminders(
        defaults: UserDefaults,
        remainingProtein: Double,
        remainingCalories: Double,
        now: Date
    ) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [ReminderID.macroToday, ReminderID.macroTomorrow])

        guard defaults.bool(forKey: AppStorageKeys.macroReminderEnabled) else { return }

        let hour = defaults.object(forKey: AppStorageKeys.macroReminderHour) as? Int ?? 19
        let minute = defaults.object(forKey: AppStorageKeys.macroReminderMinute) as? Int ?? 30

        if let todayFireDate = futureFireDateToday(hour: hour, minute: minute, now: now),
           remainingProtein > 5 || remainingCalories > 100 {
            let body: String
            if remainingProtein > 5 && remainingCalories > 100 {
                body = "Dir fehlen heute noch \(Int(remainingProtein)) g Protein und \(Int(remainingCalories)) kcal bis zu deinem Ziel."
            } else if remainingProtein > 5 {
                body = "Dir fehlen heute noch \(Int(remainingProtein)) g Protein bis zu deinem Tagesziel!"
            } else {
                body = "Dir fehlen heute noch \(Int(remainingCalories)) kcal bis zu deinem Tagesziel."
            }

            scheduleOneShotCalendarNotification(
                id: ReminderID.macroToday,
                title: "Makro- & Protein-Check",
                body: body,
                fireDate: todayFireDate
            )
        }

        if let tomorrowDate = tomorrowFireDate(hour: hour, minute: minute, now: now) {
            scheduleOneShotCalendarNotification(
                id: ReminderID.macroTomorrow,
                title: "Makro- & Protein-Check",
                body: "Prüfe dein Protein- und Kalorienziel für heute, damit du im Plan bleibst.",
                fireDate: tomorrowDate
            )
        }
    }

    private func scheduleStepReminders(
        defaults: UserDefaults,
        remainingSteps: Int,
        stepGoal: Int,
        now: Date
    ) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [ReminderID.stepsToday, ReminderID.stepsTomorrow])

        guard defaults.bool(forKey: AppStorageKeys.stepReminderEnabled) else { return }

        let hour = defaults.object(forKey: AppStorageKeys.stepReminderHour) as? Int ?? 20
        let minute = defaults.object(forKey: AppStorageKeys.stepReminderMinute) as? Int ?? 0

        if let todayFireDate = futureFireDateToday(hour: hour, minute: minute, now: now),
           remainingSteps > 0 {
            scheduleOneShotCalendarNotification(
                id: ReminderID.stepsToday,
                title: "Schrittziel noch offen",
                body: "Noch \(remainingSteps) Schritte bis zu deinem Tagesziel von \(stepGoal)!",
                fireDate: todayFireDate
            )
        }

        if let tomorrowDate = tomorrowFireDate(hour: hour, minute: minute, now: now) {
            scheduleOneShotCalendarNotification(
                id: ReminderID.stepsTomorrow,
                title: "Schrittziel im Blick",
                body: "Schaffst du heute dein Schrittziel von \(stepGoal) Schritten?",
                fireDate: tomorrowDate
            )
        }
    }

    private func futureFireDateToday(hour: Int, minute: Int, now: Date) -> Date? {
        guard let candidate = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: now),
              candidate > now else {
            return nil
        }
        return candidate
    }

    private func tomorrowFireDate(hour: Int, minute: Int, now: Date) -> Date? {
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) else { return nil }
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: tomorrow)
    }

    private func scheduleOneShotCalendarNotification(id: String, title: String, body: String, fireDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
