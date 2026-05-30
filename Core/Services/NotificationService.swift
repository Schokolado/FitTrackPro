import Foundation
import UserNotifications
import os

class NotificationService {
    static let shared = NotificationService()
    private init() {}
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                AppLogger.services.info("Notification permission granted.")
            } else if let error = error {
                AppLogger.services.error("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleRestTimerNotification(duration: TimeInterval) {
        // Cancel previous rest timers
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["rest_timer"])
        
        let content = UNMutableNotificationContent()
        content.title = "Pause beendet!"
        content.body = "Mach dich bereit für den nächsten Satz."
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: duration, repeats: false)
        let request = UNNotificationRequest(identifier: "rest_timer", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                AppLogger.services.error("Failed to schedule notification: \(error.localizedDescription)")
            }
        }
    }
    
    func cancelRestTimerNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["rest_timer"])
    }
}
