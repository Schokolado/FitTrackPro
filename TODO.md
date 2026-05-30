# FitTrackPro – TODO & Meilenstein-Checkliste

> Status-Legende: `[ ]` Offen · `[/]` In Arbeit · `[x]` Fertig

---

## Milestone 0 – Projektsetup & Fundament

- [ ] Xcode-Projekt erstellen (SwiftUI, SwiftData, iOS 17+, Bundle-ID `com.fittrackpro.app`)
- [x] Ordnerstruktur gemäß ARCHITEKTUR.md anlegen (inkl. Widget-Target)
- [ ] **Capabilities** im App-Target aktivieren:
  - [ ] `iCloud` → CloudKit, Container `iCloud.com.fittrackpro.app`
  - [ ] `App Groups` → `group.com.fittrackpro.app`
  - [ ] `Background Modes` → Remote notifications, Background processing
  - [ ] `HealthKit`
  - [ ] `Push Notifications`
- [ ] **WidgetKit Extension Target** anlegen (`FitTrackProWidget`)
  - [ ] App Group auch im Widget-Target aktivieren
- [ ] `Info.plist` Berechtigungen eintragen (HealthKit, Camera, Photo Library)
- [x] `de.lproj/` und `en.lproj/` Ordner + leere `Localizable.strings` und `InfoPlist.strings` anlegen
- [x] Design-System definieren (`Color+Theme.swift`, `View+Modifiers.swift`)
- [x] AppStorage-Keys für Einstellungen definieren
- [x] `FitTrackProApp.swift` mit `ModelContainer` (CloudKit `.automatic`) initialisieren
- [x] `AppRouter.swift` (TabView) mit Platzhalter-Tabs anlegen

---

## Milestone 1 – SwiftData Datenmodell (CloudKit Ready)

- [x] `Exercise.swift` – `@Model` inkl. `ExerciseCategory` Enum
- [x] `TrainingPlan.swift` – `@Model` mit `@Relationship` zu `PlanExercise` & `Session`
- [x] `PlanExercise.swift` – `@Model` mit `supersetGroup`-Logik
- [x] `WorkoutSession.swift` – `@Model` mit Mood/Intensity-Ratings
- [x] `WorkoutSet.swift` – `@Model` mit Soll/Ist-Werten
- [x] `FoodEntry.swift` – `@Model` mit Makros & `MealType` Enum
- [x] `DailyLog.swift` – `@Model` als Container für tägliche Einträge
- [x] `WeightEntry.swift` – `@Model`
- [x] Alle `@Relationship`-Verknüpfungen und Inverse testen
- [x] Modell in `FitTrackProApp.swift` registrieren

---

## Milestone 2 – Übungs-Mediathek

- [x] `DefaultExercises_de.json` und `DefaultExercises_en.json` mit Standardübungen befüllen (Maschinen, freie Gewichte, Kabelzug, Eigengewicht)
- [x] `SeedDataService.swift` implementieren (einmaliger Start-Seed, Sprachwahl via `Locale`)
- [x] `ExerciseLibraryView.swift` – Listenansicht mit Kategorie-Filter
- [x] `ExerciseLibraryViewModel.swift` – Suche, Filter, Sortierung
- [x] `ExerciseDetailView.swift` – Bilder, Notizen, externer Video-Link, lokale Mediapfade
- [x] Übung erstellen (Formular-View)
- [x] Übung umbenennen (In-Line Edit oder Sheet)
- [x] Übung löschen (Swipe-to-delete mit Bestätigung)
- [x] Reihenfolge ändern (Drag-to-reorder, sortOrder persistieren)
- [x] Bild/Video-Upload via `PhotosUI` (lokale Mediapfade) (als Platzhalter vorbereitet)
- [x] Externer Video-Link öffnen via `AVKit` / `SafariServices` (als Platzhalter vorbereitet)

---

## Milestone 3 – Trainingspläne

- [x] `TrainingPlansView.swift` – Liste aller Pläne
- [x] Plan erstellen (Name + initiale Übungsauswahl)
- [x] Plan umbenennen
- [x] Plan duplizieren
- [x] Plan löschen
- [x] `PlanDetailView.swift` – Übungen im Plan anzeigen & bearbeiten
- [x] Übungen zum Plan hinzufügen (aus Mediathek auswählen)
- [x] Soll-Werte pro Übung setzen (Sätze, Wiederholungen, Gewicht, Pausendauer)
- [x] Übungen im Plan per Drag-to-reorder sortieren
- [x] Übungen aus dem Plan entfernen
- [x] Supersatz-Verknüpfung erstellen / lösen (UI: Toggle oder Gruppierung)

---

## Milestone 4 – Workout-Modus (Kern-Feature)

- [ ] `WorkoutSessionViewModel.swift` – Zustandsmaschine für den Workout-Ablauf
- [ ] `WorkoutSessionView.swift` als `.fullScreenCover`
- [ ] Workout-Timer (Gesamtzeit, läuft im Hintergrund weiter)
- [ ] Aktuelle Uhrzeit permanent anzeigen (Header)
- [ ] Satz-Zeilen mit Soll-Werten (prefilled) und Ist-Werten (editierbar)
- [ ] „Confirm/Check"-Button pro Satz
- [ ] Nach Bestätigung: Pausen-Timer starten (übungsspezifische Dauer)
- [ ] Push-Benachrichtigung bei Ablauf des Pausen-Timers (`NotificationService`)
- [ ] Manueller Pausen-Timer (Top of Screen, unabhängig)
- [ ] Supersatz-Darstellung (visuell gruppierte Übungen)
- [ ] Workout abbrechen (Alert + Fortschritt verwerfen)
- [ ] Hintergrundverarbeitung: Timer läuft weiter wenn App minimiert
- [ ] `WorkoutSetRowView.swift` – einzelne Satz-Zeile

---

## Milestone 5 – Workout-Abschluss & Rating

- [ ] `WorkoutSummaryView.swift` – Zusammenfassung nach Training
- [ ] Mood-Rating (1–5, Emoji/Sterne)
- [ ] Intensitäts-Rating (1–5)
- [ ] Optionale Notiz zum Training
- [ ] Workout in SwiftData persistieren
- [ ] `WidgetDataService` nach Workout-Abschluss aktualisieren
- [ ] Übergang zum Dashboard nach Abschluss
- [ ] Conditional: „An Apple Health senden"-Button (wenn manueller Sync aktiviert)

---

## Milestone 6 – Ernährungs-Tracker

- [ ] `NutritionDashboardView.swift` – Tagesübersicht (Ringe/Balken für Makros)
- [ ] `FoodLogView.swift` – Liste der heutigen Einträge nach Mahlzeit
- [ ] `FoodEntryFormView.swift` – Eintrag erstellen/bearbeiten (manuell)
- [ ] **Barcode-Scanner** (`BarcodeScannerView.swift`):
  - [ ] `AVCaptureSession`-Setup als `UIViewControllerRepresentable`
  - [ ] Unterstützte Formate: EAN-13, EAN-8, UPC-A, Code128
  - [ ] Scan-Ergebnis → OpenFoodFacts API-Call
  - [ ] Ergebnis-Sheet: Produkt-Preview + Mengen-Stepper (g)
  - [ ] Makros proportional zur eingegebenen Menge berechnen
  - [ ] Fallback auf manuelle Eingabe wenn Produkt nicht gefunden
- [ ] `FoodAPIService.swift` – OpenFoodFacts REST API (actor-basiert)
  - [ ] `OFFResponse`, `OFFProduct`, `OFFNutriments` Decodable-Structs
  - [ ] Error-Handling (Netzwerk, kein Produkt, ungültiger Barcode)
- [ ] Kalorien-Ziel setzen (in Einstellungen oder direkt im View)
- [ ] Makro-Ziele setzen (Protein, Kohlenhydrate, Fett)
- [ ] Fortschrittsbalken/-ringe für Kalorien und Makros
- [ ] Tagesrückblick speichern in `DailyLog`
- [ ] Navigation zwischen Tagen (DatePicker)
- [ ] `WidgetDataService` nach Mahlzeit-Log aktualisieren

---

## Milestone 7 – Gewichtstracker

- [ ] `WeightTrackerView.swift` – Eingabe und Historie
- [ ] Gewichtseintrag erstellen
- [ ] Gewichtseintrag bearbeiten/löschen
- [ ] Verlaufsdiagramm (Swift Charts, Liniendiagramm)
- [ ] Aktuelles Gewicht im Dashboard anzeigen
- [ ] `WidgetDataService` nach Gewichtseintrag aktualisieren

---

## Milestone 8 – Dashboard

- [ ] `DashboardView.swift` – Homescreen mit modernem Design
- [ ] Widget: Kalorienbilanz (heute)
- [ ] Widget: Aktuelles Körpergewicht
- [ ] Widget: Heutige Stimmung / Mood
- [ ] Widget: Trainingsleistung (letzte 30 Tage, frei wählbar)
- [ ] Quick-Action: Workout starten
- [ ] Quick-Action: Mahlzeit loggen
- [ ] Begrüßungstext mit Tageszeit (Guten Morgen/Abend etc.)

---

## Milestone 9 – Statistik & Analyse

- [ ] `StatisticsView.swift` – Übersicht mit Filter-Optionen
- [ ] `StatisticsViewModel.swift` – Aggregationslogik
- [ ] Filterung nach Übung
- [ ] Filterung nach Plan
- [ ] Filterung nach Zeitraum (frei wählbar)
- [ ] Diagramm: Volumen über Zeit (Swift Charts, Balkendiagramm)
- [ ] Diagramm: Max. Gewicht über Zeit (Liniendiagramm)
- [ ] Diagramm: Sätze und Wiederholungen über Zeit
- [ ] `ExerciseProgressChart.swift` – Wiederverwendbare Chart-Komponente
- [ ] `PlanProgressView.swift` – Plan-spezifische Auswertung

---

## Milestone 10 – PDF-Export

- [ ] `PDFExportService.swift` implementieren
- [ ] Export 1: Leerer Trainingsplan (Tabelle: Übung, Sätze, Wdh., Gewicht, Notizen)
- [ ] Export 2: Historischer Plan mit Steigerungskurve
  - [ ] Swift Chart als `UIImage` rendern
  - [ ] In PDF einbetten
  - [ ] Workout-Historie tabellarisch listen
- [ ] Share Sheet (`UIActivityViewController`) zum Teilen/Speichern
- [ ] PDF-Export in Plan-Detailansicht zugänglich machen

---

## Milestone 11 – Apple Health Integration

- [ ] `HealthKitService.swift` implementieren
- [ ] Berechtigungen anfragen (Workout, Kalorien, Gewicht)
- [ ] Workout-Daten exportieren (`HKWorkout`)
- [ ] Kalorien exportieren (`HKQuantitySample`)
- [ ] Gewicht exportieren (`HKQuantitySample`)
- [ ] Einstellungen: Toggle „Automatisch synchronisieren"
- [ ] Automatischer Sync nach Workout-Abschluss (wenn aktiviert)
- [ ] Manueller Sync-Button nach Workout (wenn deaktiviert)
- [ ] Sync-Status pro Session tracken (`syncedToHealthKit: Bool`)

---

## Milestone 12 – Einstellungen

- [ ] `SettingsView.swift` – vollständige Einstellungsseite
- [ ] HealthKit Sync-Modus (Auto / Manuell)
- [ ] Kalorien- und Makroziele
- [ ] Standard-Pausendauer konfigurieren
- [ ] Benachrichtigungen aktivieren/deaktivieren
- [ ] iCloud-Sync Status anzeigen (CloudKit-Badge: Synced / Syncing / Offline)
- [ ] App-Version und Build-Nummer anzeigen
- [ ] Datenschutzerklärung verlinken

---

## Milestone 13 – CloudKit Sync & Testing

- [ ] CloudKit-Konfiguration im `ModelContainer` verifizieren
- [ ] `CKContainer` korrekt in App-Capabilities konfiguriert
- [ ] Sync-Test: Daten auf Gerät 1 erstellen → auf Gerät 2 erscheinen
- [ ] Offline-Test: Ohne Internetverbindung schreiben → nach Reconnect sync
- [ ] Conflict-Test: Gleichzeitig auf zwei Geräten schreiben
- [ ] iCloud-Status in `SettingsView` anzeigen (`CKAccountStatus`)
- [ ] Fehlerbehandlung wenn iCloud nicht angemeldet (Fallback auf lokale DB)

---

## Milestone 14 – WidgetKit Extension

- [ ] `FitTrackProWidgetBundle.swift` – `@main` WidgetBundle
- [ ] `WidgetDataService.swift` – App Group Shared UserDefaults
- [ ] **Widget 1 – Kalorienbilanz (systemSmall)**:
  - [ ] Kreisdiagramm / Ring mit Kalorien-Fortschritt
  - [ ] Makro-Mini-Balken (P / K / F)
  - [ ] Deep Link: Tap öffnet Ernährungs-Tab
- [ ] **Widget 2 – Fitness-Dashboard (systemMedium)**:
  - [ ] Kalorien-Ring (links)
  - [ ] Letztes Workout (Name + Datum, Mitte)
  - [ ] Aktuelles Gewicht (rechts)
  - [ ] Deep Link: Tap öffnet Dashboard
- [ ] `TimelineProvider` mit 15-Minuten-Refresh
- [ ] Widget-Preview in Xcode Canvas testen
- [ ] Widget-Refresh nach allen relevanten Daten-Events (Meal, Workout, Weight)

---

## Milestone 15 – Lokalisierung (DE + EN)

- [ ] Alle View-Strings aus den Views extrahieren
- [ ] `de.lproj/Localizable.strings` vollständig befüllen
- [ ] `en.lproj/Localizable.strings` vollständig befüllen
- [ ] `de.lproj/InfoPlist.strings` (Permissions-Texte auf Deutsch)
- [ ] `en.lproj/InfoPlist.strings` (Permissions-Texte auf Englisch)
- [ ] Notification-Texte lokalisieren (`NotificationService`)
- [ ] PDF-Export-Kopf-/Fußzeilen lokalisieren
- [ ] Widget-Beschriftungen lokalisieren
- [ ] Seed-Daten: `DefaultExercises_de.json` + `DefaultExercises_en.json`
- [ ] Gerät auf Englisch umstellen → komplette App durchklicken

---

## Milestone 16 – Polish & QA

- [ ] Light/Dark Mode vollständig getestet
- [ ] Accessibility (VoiceOver, Dynamic Type) geprüft
- [ ] Edge Cases: Leere Zustände (Empty States) für alle Listen
- [ ] Fehlerbehandlung (SwiftData, HealthKit, CloudKit, Netzwerk/API)
- [ ] Performance-Optimierung (lazy loading, Query-Optimierung)
- [ ] App Icon & Launch Screen erstellen
- [ ] TestFlight-Build erstellen und testen
- [ ] Crash-Reporting prüfen (MetricKit)

---

## Milestone 17 – App Store Release

- [ ] App Store Connect einrichten
- [ ] Screenshots für alle Gerätegrößen (iPhone 15 Pro Max, iPhone SE)
- [ ] Widget-Screenshots
- [ ] Datenschutzerklärung (HealthKit + CloudKit Pflicht)
- [ ] App Privacy Nutrition Label ausfüllen
- [ ] App Review Checkliste abarbeiten
- [ ] Release

