# FitTrackPro – Konsolidiertes Backlog & Roadmap

> **Single Source of Truth** – Konsolidiert aus dem bisherigen `Feature_Backlog.md`, `FEATURE_REQUESTS.md` und `TODO.md` (Stand: 2026-11-11).  
> Status-Legende: `[ ]` Offen · `[x]` Erledigt

---

## 1. Offene Features & UX (Klein bis Mittel)

- [ ] **Farbhierarchie im aktiven Workout** *(Design)*
  - Klare Farbtrennung zwischen Satzpausen-Timer (`WorkoutTimerHeaderView`), „Workout angehalten“ (Orange) und „Workout beenden“ (Grün in `WorkoutSessionView`), z. B. Indigo/Cyan/`Color.brand` für Satzpause und Grün exklusiv für Start/Abschluss.
- [ ] **Optional: Übergang zum Dashboard nach Workout-Abschluss** *(Klein)*
  - Prüfen/umsetzen, ob nach dem Speichern in `WorkoutSummaryView` (`.workoutFinished`) auf den Home-/Dashboard-Tab gewechselt werden soll.

---

## 2. Größere Features & Auswertungen

- [ ] **Visualisierung der Trainingshistorie** *(Mittel)*
  - Balken- und Liniendiagramme direkt in der Trainingshistorie (`WorkoutHistoryView` / `ExerciseHistoryView`, z. B. gehobenes Volumen über Zeit, 1RM-Fortschritt).
- [ ] **Erweiterte Statistik: Trainings-Kalender** *(Mittel)*
  - Übersichts-Kalender für absolvierte Trainingstage *(Hinweis: Muskelgruppen-Balance / „Muscle Fokus“ ist bereits umgesetzt).*
- [ ] **Share Workout inkl. Selfie-Foto** *(Mittel)*
  - Nach Workout-Abschluss und in der Historie eine Share-Grafik mit Workout-Stats + optionalem Selfie (Frontkamera/Galerie) per `ImageRenderer` rendern und über `ShareSheet` teilen, ohne das Foto dauerhaft zu speichern.
- [ ] **„Was ist letzte Nacht passiert?“ (Schlaf-Einflüsse)** *(Mittel / iOS-Restriktionen)*
  - Automatische Hinweise auf mögliche Schlaf-Faktoren: späte Mahlzeiten (aus `FoodEntry`-Zeitstempeln), Umgebungslautstärke (`environmentalAudioExposure` via HealthKit) sowie Hinweis zu iOS-Limitierungen bei Screen-Time/Handynutzung.
- [ ] **Interaktives Workout Live Activity (Lockscreen)** *(Mittel)*
  - `AppIntents` in `FitTrackProWidgetLiveActivity` ergänzen, um Workouts und Pausen-Timer direkt vom Sperrbildschirm / aus der Dynamic Island zu pausieren oder zu stoppen.
- [ ] **Interaktives Pull-to-Minimize für `WorkoutSessionView`** *(Mittel)*
  - Umbau vom `.fullScreenCover` auf ein Custom-Overlay (`ZStack` im `AppRouter`), damit die Ansicht per Finger-Drag fließend in den Mini-Player gezogen werden kann.
- [ ] **Widgets erweitern & verfeinern** *(Mittel)*
  - Design-Polishing bestehender Widgets sowie zusätzliche Formate (z. B. großes Widget oder dedizierte Workout-/Makro-Widgets).
- [ ] **Fitbit Integration** *(Groß)*
  - Direkte Anbindung an die Fitbit Web API via OAuth2 (Schritte, Schlaf, Herzfrequenz) als Alternative zu Apple HealthKit.

---

## 3. Technische Aufgaben, Produkt & Release

- [ ] **Widget-Refresh nach allen Daten-Events vervollständigen**
  - `WidgetDataSync.sync()` nach Mahlzeit-, Gewichts- (`WeightEntryFormView` enthält noch `// TODO`) und Workout-Logs zuverlässig auslösen.
- [ ] **CloudKit Sync & Fehlerbehandlung testen**
  - Multi-Device-Sync-Test, Offline-Queue-Test, Konflikt-Test (gleichzeitiges Schreiben auf zwei Geräten) und sauberer Fallback/Hinweis, falls iCloud abgemeldet ist.
- [ ] **Polish & QA**
  - Light/Dark Mode vollständig prüfen.
  - Accessibility (VoiceOver, Dynamic Type) prüfen.
  - Empty States für alle Listen und Detailansichten vervollständigen.
  - Robuste Fehlerbehandlung (SwiftData, HealthKit, CloudKit, OpenFoodFacts-API).
  - Performance-Optimierung (`@Query`-Filterung, Lazy Loading) & MetricKit-Crash-Reporting prüfen.
  - TestFlight-Build erstellen und auf echten Geräten testen.
- [ ] **App-Rebranding vereinheitlichen**
  - Finalen App-Namen konsistent über Bundle/Assets/Strings ziehen (aktuell gemischt `FitTrackPro` vs. `Vantage` in `App/Info.plist`).
- [ ] **Monetarisierung / Pro-Version (Optional)**
  - In-App-Käufe (StoreKit 2), FatSecret-Datenbank-Integration, Premium-Pläne, alternatives App-Icon, Apple Watch Companion App, Spenden/Werbung *(Hinweis: „Dashboard-Widgets anordnen“ ist bereits frei verfügbar umgesetzt).*
- [ ] **App Store Release**
  - App Store Connect einrichten, Device- und Widget-Screenshots erstellen, Datenschutzerklärung (HealthKit + CloudKit Pflicht), App Privacy Nutrition Label und App Review Checkliste abarbeiten.

---

## 4. Erledigt (Verifizierter Stand)

### Kern-Meilensteine & Plattform
- [x] **Projektsetup & Entitlements:** Xcode-Projekt, `FitTrackProWidget`-Extension, App Groups (`group.com.riccardopfeiler.FitTrackPro`), HealthKit, CloudKit (`iCloud.com.riccardopfeiler.FitTrackPro`), Push Notifications, `LaunchScreen.storyboard` & App Icon, Lokalisierung (DE + EN).
- [x] **Datenmodell & Persistence:** Alle SwiftData-`@Model`-Klassen (`Exercise`, `TrainingPlan`, `PlanExercise`, `WorkoutSession`, `WorkoutSet`, `FoodEntry`, `SavedFood`, `Recipe`, `DailyLog`, `WeightEntry`, `StepEntry`, `WaterEntry`, `SleepEntry`) im gemeinsamen `SharedContainer`.
- [x] **Training & Workouts:** Übungs-Mediathek mit Seed-Daten (inkl. Mobility & Rich-Markdown-Notizen), Trainingspläne (inkl. Plan-Fokus, Übungs- & Satzanzahl-Header in `PlanDetailView` und PDF-Export), Live-Workout-Modus mit Supersätzen, Pausen-Timer-Notifications, Mini-Player, `WorkoutSummaryView` (inkl. „In Apple Health eintragen“-Toggle) & `HKWorkoutSession` (`6cf7996`).
- [x] **Ernährung & Körperdaten:** Makro-/Kalorien-Dashboard, Barcode-Scanner (`AVFoundation` + OpenFoodFacts), Gespeicherte Lebensmittel & Rezepte, Gewichtstracker mit Chart, Wasser-, Schlaf- und Schritt-Tracker.
- [x] **Dashboard, Widgets & iCloud:** Modulares Dashboard mit Drag-&-Drop-Anordnung und iCloud-Layout-Sync (`6174778`), Home- & Lockscreen-Widgets (`FitTrackProWidget`, `StepsWidget`), Live Activity Anzeige (`FitTrackProWidgetLiveActivity`) sowie CloudKit-Statusprüfung (`CKContainer.default().accountStatus()`) in `SettingsView`.

### Zuletzt umgesetzte Backlog-Features
- [x] **Performance: Timer-Auskopplung** (`10f7242`) – `WorkoutTimerViewModel` + natives `Text(timerInterval:)`.
- [x] **Balance der Trainingseinheiten nach Muskelgruppe** (`6b79d08`, `ac1e2af`, `b0a5f1f`, `28b273c`) – Inline- & Detail-Auswertung nach Sätzen, Volumen und Übungen inkl. Plan-Fokus.
- [x] **Belastung / Erholung / Schlaf & Aktivitätszusammenfassung** (`6b79d08`, `ac1e2af`) – Vital-Ringe und Tages-/Wochenzusammenfassung in `RecoveryView`.
- [x] **Trainingsbelastung & Fitness-Status (inkl. 6-Wochen-Verlauf)** (`c9425cc`) – Akute vs. chronische Belastung und Status-Timeline.
- [x] **Biologisches Alter / Fitness-Alter** (`7498e28`, `db5e286`, `4c5deda`) – Berechnung mit HealthKit-`VO2max`, Ruhepuls, Schritten, Trainingsfrequenz, Schlaf sowie Körperfettanteil / Waist-to-Height-Ratio (mit BMI-Fallback).
- [x] **Dynamische Farbgebung für Kalorien-Kreis (Dashboard & Ernährung)** (`d027585`) – `CalorieRingEvaluator` mit Warnfarben (Rot bei Überschuss, Orange bei abendlichem/vergangenem Defizit, Grün im Zielkorridor) auf Basis der konfigurierbaren Toleranz (`nutritionTolerance`) und Abend-Uhrzeit (`calorieWarningEveningHour`) in `SettingsView`.
- [x] **Verbrannte Kalorien direkt im Dashboard & Ernährungs-Tab anzeigen** (`b8bbc92`) – Anzeige der aktiven HealthKit-Kalorien (`fetchActiveEnergyBurned(for:)`), geschätztem Tagesumsatz (`EnergyCalculator.estimatedBMR` + Aktiv) und Tagesbilanz in `NutritionSummaryCard`, `NutritionSummaryCardSmall` und `NutritionDashboardView`.
- [x] **Push-Benachrichtigungen / Reminder** (`4a78b25`) – Konfigurierbare Erinnerungen für Workout-Tage/Uhrzeit, Makro-/Protein-Restbedarf und Schrittziel in `SettingsView` & `NotificationService` (automatischer Tages-Sync bei App-Wechsel).
- [x] **Apple Health Erweiterungen** – Manueller „Import aus Health“-Abgleich für Gewicht (`HealthKitService.importNewWeights`, `WeightTrackerView`, `SettingsView`), Kalorien-/Makro-Export (`exportNutrition` inkl. Sammel-Abgleich) sowie Auslesen/Berechnen verbrannter Workout-Kalorien aus Apple Watch Active Energy, Herzfrequenz (Keytel) oder MET-Schätzung inkl. `HKWorkout`-Export (`WorkoutSummaryView`, `WorkoutHistoryView`).
- [x] **Vitalität-Tab (ehem. Akku / Recovery)** (`593c9e9`, `56c6db2`) – Eigenständiger 4. Tab in der Navigationsleiste (`AppRouter`, `VitalityView`) mit Segment-Wechsel zwischen **Erholung** (`RecoveryView`) und **Tagesenergie** (`EnergyDetailView`) sowie umbenannten Dashboard-Karten.
- [x] **Voraussichtliche Trainingsdauer anzeigen** (`2795f2b`) – Schätzung aus Sätzen, Ziel-Wdh./Zeit (`usesTimeInput`) und Pausenzeiten (`TrainingPlan.estimatedDurationText`), angezeigt in `PlanCard` (`TrainingPlansView`) und `PlanDetailView`.
- [x] **Chart X-Achsen-Beschriftungen am Rand korrigieren** – Nach innen verankerte Rand-Labels (`ChartAxisHelper` / `edgeSafeDateXAxis` in `View+Modifiers.swift`) inkl. `.chartPlotStyle { $0.clipped() }` für `WeightTrackerView`, `ExerciseProgressChart`, `PlanProgressView`, `StepTrackerView`, `WaterTrackerView`, `SleepTrackerView` und `RecoveryFactorDetailView`.
