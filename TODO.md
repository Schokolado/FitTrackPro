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
- [x] Anzeige: "Zuletzt absolviert" Datum auf der Plankarte
- [x] `PlanDetailView.swift` – Übungen im Plan anzeigen & bearbeiten
- [x] Übungen zum Plan hinzufügen (aus Mediathek auswählen)
- [x] Soll-Werte pro Übung setzen (Sätze, Wiederholungen, Gewicht, Pausendauer)
- [x] Übungen im Plan per Drag-to-reorder sortieren
- [x] Übungen aus dem Plan entfernen
- [x] Supersatz-Verknüpfung erstellen / lösen (UI: Toggle oder Gruppierung)

---

## Milestone 4 – Workout-Modus (Kern-Feature)

- [x] `WorkoutSessionViewModel.swift` – Zustandsmaschine für den Workout-Ablauf
- [x] `WorkoutSessionView.swift` als `.fullScreenCover`
- [x] Workout-Timer (Gesamtzeit, läuft im Hintergrund weiter)
- [x] Aktuelle Uhrzeit permanent anzeigen (Header)
- [x] Satz-Zeilen mit Soll-Werten (prefilled) und Ist-Werten (editierbar)
- [x] „Confirm/Check"-Button pro Satz
- [x] Nach Bestätigung: Pausen-Timer starten (übungsspezifische Dauer)
- [x] Push-Benachrichtigung bei Ablauf des Pausen-Timers (`NotificationService`)
- [x] Manueller Pausen-Timer (Top of Screen, unabhängig)
- [x] Supersatz-Darstellung (visuell gruppierte Übungen)
- [x] Workout abbrechen (Alert + Fortschritt verwerfen)
- [x] Hintergrundverarbeitung: Timer läuft weiter wenn App minimiert
- [x] `WorkoutSetRowView.swift` – einzelne Satz-Zeile

---

## Milestone 5 – Workout-Abschluss & Rating

- [x] `WorkoutSummaryView.swift`
- [x] Anzeige der Dauer, absolvierten Übungen und bewegtem Gesamtgewicht (Volumen)
- [x] Abfrage von Stimmung (1-5 Sterne/Emojis)
- [x] Abfrage von Intensität (1-5 RPE Scale oder Text)
- [x] Notizfeld (optional)
- [x] Speichern der `WorkoutSession` (Zeitstempel `endTime` setzen) und Schließen des Full-Screen-Covers
- [x] Konfetti-Animation / Erfolgs-Feedback beim Abschluss
- [ ] Übergang zum Dashboard nach Abschluss
- [ ] Conditional: „An Apple Health senden"-Button (wenn manueller Sync aktiviert)

---

## Milestone 6 – Ernährungs-Tracker

- [x] `NutritionDashboardView.swift` – Tagesübersicht (Ringe/Balken für Makros)
- [x] `FoodLogView.swift` – Liste der heutigen Einträge nach Mahlzeit
- [x] `FoodEntryFormView.swift` – Eintrag erstellen/bearbeiten (manuell)
- [x] **Barcode-Scanner** (`BarcodeScannerView.swift`):
  - [x] `AVCaptureSession`-Setup als `UIViewControllerRepresentable`
  - [x] Unterstützte Formate: EAN-13, EAN-8, UPC-A, Code128
  - [x] Scan-Ergebnis → OpenFoodFacts API-Call
  - [x] Ergebnis-Sheet: Produkt-Preview + Mengen-Stepper (g)
  - [x] Makros proportional zur eingegebenen Menge berechnen
  - [x] Fallback auf manuelle Eingabe wenn Produkt nicht gefunden
- [x] `FoodAPIService.swift` – OpenFoodFacts REST API (actor-basiert)
  - [x] `OFFResponse`, `OFFProduct`, `OFFNutriments` Decodable-Structs
  - [x] Error-Handling (Netzwerk, kein Produkt, ungültiger Barcode)
- [x] Kalorien-Ziel setzen (in Einstellungen oder direkt im View)
- [x] Makro-Ziele setzen (Protein, Kohlenhydrate, Fett)
- [x] Fortschrittsbalken/-ringe für Kalorien und Makros
- [x] Tagesrückblick speichern in `DailyLog`
- [x] Navigation zwischen Tagen (DatePicker)
- [ ] `WidgetDataService` nach Mahlzeit-Log aktualisieren

---

## Milestone 7 – Gewichtstracker

- [x] `WeightTrackerView.swift` – Eingabe und Historie
- [x] Gewichtseintrag erstellen
- [x] Gewichtseintrag bearbeiten/löschen
- [x] Verlaufsdiagramm (Swift Charts, Liniendiagramm)
- [x] Aktuelles Gewicht im Dashboard anzeigen
- [ ] `WidgetDataService` nach Gewichtseintrag aktualisieren

---

## Milestone 8 – Dashboard

- [x] `DashboardView.swift` – Homescreen mit modernem Design
- [x] Widget: Kalorienbilanz (heute)
- [x] Widget: Schrittzähler (Mock-UI mit Ring)
- [x] Widget: Aktuelles Körpergewicht
- [x] Widget: Trainingsleistung / Nächstes Workout
- [x] Widget: Heutige Stimmung / Mood
- [x] Quick-Action: Workout starten
- [x] Quick-Action: Mahlzeit loggen
- [x] Begrüßungstext mit Tageszeit (Guten Morgen/Abend etc.)

---

## Milestone 9 – Statistik & Analyse

- [x] `StatisticsView.swift` – Übersicht mit Filter-Optionen
- [x] `StatisticsViewModel.swift` – Aggregationslogik
- [x] Filterung nach Übung
- [x] Filterung nach Plan
- [x] Filterung nach Zeitraum (frei wählbar)
- [x] Diagramm: Volumen über Zeit (Swift Charts, Balkendiagramm)
- [x] Diagramm: Max. Gewicht über Zeit (verschoben ins Dashboard)
- [x] Diagramm: Sätze und Wiederholungen über Zeit
- [x] `ExerciseProgressChart.swift` – Wiederverwendbare Chart-Komponente
- [x] `PlanProgressView.swift` – Plan-spezifische Auswertung

---

## Milestone 10 – PDF-Export

- [x] `PDFExportService.swift` implementieren
- [x] Export 1: Leerer Trainingsplan (Tabelle: Übung, Sätze, Wdh., Gewicht, Notizen)
- [x] Export 2: Historischer Plan mit Steigerungskurve
  - [x] Swift Chart als `UIImage` rendern
  - [x] In PDF einbetten
  - [x] Workout-Historie tabellarisch listen
- [x] Share Sheet (`UIActivityViewController`) zum Teilen/Speichern
- [x] PDF-Export in Plan-Detailansicht zugänglich machen

---

## Milestone 11 – Apple Health Integration

- [x] `HealthKitService.swift` implementieren
- [x] Berechtigungen anfragen (Workout, Gewicht)
- [x] Workout-Daten exportieren (`HKWorkout`) - **OHNE** Kalorien
- [x] Gewicht exportieren (`HKQuantitySample`)
- [x] Einstellungen: Toggle „Automatisch synchronisieren"
- [x] Automatischer Sync nach Workout-Abschluss (wenn aktiviert)
- [x] Manueller Sync-Button nach Workout (wenn deaktiviert)
- [x] Sync-Status pro Session tracken (`syncedToHealthKit: Bool`)
- [ ] Zukünftig: Gewicht aus Apple Health einlesen und jeweilige Einträge erstellen (Notiz: "Import aus Health")
- [ ] Zukünftig: Kalorien und Makro Export in Apple Health
- [ ] Zukünftig: Kalorienangabe bei Workout (evtl. berechnen durch Apple Watch Daten, Statistik, prüfen was möglich ist)

---

## Milestone 12 – Einstellungen

- [x] `SettingsView.swift` – vollständige Einstellungsseite
- [x] HealthKit Sync-Modus (Auto / Manuell)
- [x] Kalorien- und Makroziele
- [x] Standard-Pausendauer konfigurieren
- [x] Benachrichtigungen aktivieren/deaktivieren
- [x] iCloud-Sync Status anzeigen (CloudKit-Badge: Synced / Syncing / Offline)
- [x] App-Version und Build-Nummer anzeigen
- [x] Datenschutzerklärung verlinken

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

- [x] `FitTrackProWidgetBundle.swift` – `@main` WidgetBundle
- [x] `WidgetDataService.swift` – App Group Shared UserDefaults
- [x] **Widget 1 – Kalorienbilanz (systemSmall)**:
  - [x] Kreisdiagramm / Ring mit Kalorien-Fortschritt
  - [x] Makro-Mini-Balken (P / K / F)
  - [x] Deep Link: Tap öffnet Ernährungs-Tab
- [x] **Widget 2 – Fitness-Dashboard (systemMedium)**:
  - [x] Kalorien-Ring (links)
  - [x] Letztes Workout (Name + Datum, Mitte)
  - [x] Aktuelles Gewicht (rechts)
  - [x] Deep Link: Tap öffnet Dashboard
- [x] `TimelineProvider` mit 15-Minuten-Refresh
- [x] Widget-Preview in Xcode Canvas testen
- [x] Widget-Refresh nach allen relevanten Daten-Events (Meal, Workout, Weight)

---

## Milestone 15 – Lokalisierung (DE + EN) ✅

- [x] Extrahieren aller Texte aus dem Projekt
- [x] `de.lproj/Localizable.strings` befüllen (via Code Keys)
- [x] `en.lproj/Localizable.strings` befüllen (via Übersetzungen)
- [x] `de.lproj/InfoPlist.strings` (Permissions-Texte auf Deutsch)
- [x] `en.lproj/InfoPlist.strings` (Permissions-Texte auf Englisch)
- [x] Dynamische Texte (Interpolationen) anpassen
- [x] Seed-Daten anpassen (JSON für EN und DE)

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

