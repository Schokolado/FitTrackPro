# FitTrackPro – Architektur-Dokumentation

> **Plattform:** iOS 17+  
> **Sprache:** Swift 5.9+  
> **UI-Framework:** SwiftUI  
> **Persistenz:** SwiftData + CloudKit  
> **Zieldatei:** Xcode-Projekt (Multi-Target: App + WidgetKit Extension)

---

## 0. Getroffene Architekturentscheidungen

| Feature | Entscheidung |
|---------|-------------|
| Barcode-Scanner | ✅ AVFoundation + OpenFoodFacts REST API |
| Cloud-Sync | ✅ SwiftData + CloudKit (`iCloud.com.fittrackpro.app`) |
| Home Screen Widget | ✅ WidgetKit Extension (Small + Medium) |
| Apple Watch | ❌ Vorerst nicht (Erweiterungspunkt dokumentiert) |
| Sprachen | ✅ DE + EN (`Localizable.strings`) |
| Gewichtseinheit | ✅ Nur kg (vorerst) |

---

## 1. Überblick & Designprinzipien

FitTrackPro ist eine native iOS-App, die Krafttraining-Tracking und Ernährungs-Management in einer kohärenten, modernen Oberfläche vereint. Die App folgt diesen Architekturprinzipien:

- **MVVM-Architektur** – klare Trennung von Daten (SwiftData-Modelle), Business Logic (ViewModels/ObservableObjects) und UI (SwiftUI Views).
- **SwiftData + CloudKit** – relationale Beziehungen über `@Relationship`, geräteübergreifender Sync via CloudKit.
- **Unidirektionaler Datenfluss** – ViewModels werden per `@Environment` oder `@StateObject` injiziert, Views sind passiv.
- **Modularität** – jede Feature-Gruppe lebt in einem eigenständigen Feature-Modul.
- **Multi-Target** – Haupt-App-Target + WidgetKit Extension teilen Daten via App Group.

---

## 2. App-Struktur (Ordnerstruktur)

```
FitTrackPro/
├── App/
│   ├── FitTrackProApp.swift          # @main, ModelContainer-Setup (mit CloudKit)
│   └── AppRouter.swift               # Zentrale Navigation / TabView
│
├── Core/
│   ├── Models/                       # SwiftData @Model-Klassen
│   │   ├── Exercise.swift
│   │   ├── TrainingPlan.swift
│   │   ├── WorkoutSession.swift
│   │   ├── WorkoutSet.swift
│   │   ├── Superset.swift
│   │   ├── FoodEntry.swift
│   │   ├── WeightEntry.swift
│   │   └── DailyLog.swift
│   ├── Services/
│   │   ├── HealthKitService.swift    # Apple Health Integration
│   │   ├── NotificationService.swift # UNUserNotificationCenter
│   │   ├── PDFExportService.swift    # PDF-Generierung
│   │   ├── SeedDataService.swift    # Vorinstallierte Übungen
│   │   ├── FoodAPIService.swift     # OpenFoodFacts REST API
│   │   └── WidgetDataService.swift  # App Group Shared Data für Widget
│   └── Extensions/
│       ├── Color+Theme.swift
│       ├── Date+Helpers.swift
│       └── View+Modifiers.swift
│
├── Features/
│   ├── Dashboard/
│   │   ├── DashboardView.swift
│   │   └── DashboardViewModel.swift
│   ├── Training/
│   │   ├── ExerciseLibrary/
│   │   │   ├── ExerciseLibraryView.swift
│   │   │   ├── ExerciseDetailView.swift
│   │   │   └── ExerciseLibraryViewModel.swift
│   │   ├── Plans/
│   │   │   ├── TrainingPlansView.swift
│   │   │   ├── PlanDetailView.swift
│   │   │   └── PlanViewModel.swift
│   │   └── Workout/
│   │       ├── WorkoutSessionView.swift
│   │       ├── WorkoutSetRowView.swift
│   │       ├── WorkoutTimerView.swift
│   │       ├── RestTimerView.swift
│   │       ├── WorkoutSummaryView.swift
│   │       └── WorkoutSessionViewModel.swift
│   ├── Nutrition/
│   │   ├── NutritionDashboardView.swift
│   │   ├── FoodLogView.swift
│   │   ├── FoodEntryFormView.swift
│   │   ├── BarcodeScannerView.swift  # AVFoundation UIViewControllerRepresentable
│   │   └── NutritionViewModel.swift
│   ├── Statistics/
│   │   ├── StatisticsView.swift
│   │   ├── ExerciseProgressChart.swift
│   │   ├── PlanProgressView.swift
│   │   └── StatisticsViewModel.swift
│   ├── WeightTracker/
│   │   ├── WeightTrackerView.swift
│   │   └── WeightTrackerViewModel.swift
│   └── Settings/
│       ├── SettingsView.swift
│       └── SettingsViewModel.swift
│
├── Resources/
│   ├── Assets.xcassets/
│   ├── de.lproj/
│   │   ├── Localizable.strings
│   │   └── InfoPlist.strings
│   ├── en.lproj/
│   │   ├── Localizable.strings
│   │   └── InfoPlist.strings
│   ├── DefaultExercises_de.json      # Seed-Daten (Deutsch)
│   └── DefaultExercises_en.json      # Seed-Daten (Englisch)
│
└── FitTrackProWidget/                # WidgetKit Extension Target
    ├── FitTrackProWidgetBundle.swift  # @main WidgetBundle
    ├── CalorieWidget.swift            # systemSmall: Kalorienbilanz
    ├── FitnessDashboardWidget.swift   # systemMedium: Dashboard
    ├── WidgetProvider.swift           # TimelineProvider
    └── WidgetEntryView.swift          # SwiftUI Widget Views
```

---

## 3. SwiftData Datenmodell & Beziehungen

### 3.1 Zentrale Modelle

```
Exercise  ─────────────────────────────────────────────────────────
│  id: UUID                                                        │
│  name: String                                                    │
│  category: ExerciseCategory (enum)                               │
│  notes: String?                                                  │
│  videoURL: URL? (extern)                                         │
│  localMediaPaths: [String] (Bild-/Videopfade, lokal)            │
│  restDuration: TimeInterval (Pausen-Timer-Vorgabe)              │
│  isCustom: Bool                                                  │
│  sortOrder: Int                                                   │
└──────────────────────────────────────────────────────────────────

TrainingPlan ──────────────────────────────────────────────────────
│  id: UUID                                                        │
│  name: String                                                    │
│  createdAt: Date                                                 │
│  sortOrder: Int                                                   │
│  planExercises: [PlanExercise]   ← Reihenfolge + Soll-Werte     │
│  sessions: [WorkoutSession]                                      │
└──────────────────────────────────────────────────────────────────

PlanExercise ──────────────────────────────────────────────────────
│  id: UUID                                                        │
│  plan: TrainingPlan              ← inverse Beziehung             │
│  exercise: Exercise                                              │
│  sortOrder: Int                                                   │
│  supersetGroup: Int?             ← nil = kein Supersatz          │
│  targetSets: Int                                                 │
│  targetReps: Int                                                 │
│  targetWeight: Double?                                           │
│  restDuration: TimeInterval      ← override oder Exercise-Default│
└──────────────────────────────────────────────────────────────────

WorkoutSession ────────────────────────────────────────────────────
│  id: UUID                                                        │
│  plan: TrainingPlan?             ← optional (freestyle)          │
│  startedAt: Date                                                 │
│  finishedAt: Date?                                               │
│  durationSeconds: TimeInterval                                   │
│  moodRating: Int? (1–5)                                         │
│  intensityRating: Int? (1–5)                                    │
│  notes: String?                                                  │
│  performedSets: [WorkoutSet]                                     │
│  syncedToHealthKit: Bool                                         │
└──────────────────────────────────────────────────────────────────

WorkoutSet ────────────────────────────────────────────────────────
│  id: UUID                                                        │
│  session: WorkoutSession                                         │
│  exercise: Exercise                                              │
│  planExercise: PlanExercise?     ← Referenz auf Soll-Werte      │
│  setNumber: Int                                                  │
│  targetReps: Int?                                                │
│  targetWeight: Double?                                           │
│  actualReps: Int                                                 │
│  actualWeight: Double                                            │
│  isCompleted: Bool                                               │
│  completedAt: Date?                                              │
│  supersetGroup: Int?                                             │
└──────────────────────────────────────────────────────────────────

FoodEntry ─────────────────────────────────────────────────────────
│  id: UUID                                                        │
│  dailyLog: DailyLog                                              │
│  name: String                                                    │
│  calories: Double                                                │
│  protein: Double  (g)                                            │
│  carbs: Double    (g)                                            │
│  fat: Double      (g)                                            │
│  loggedAt: Date                                                  │
│  mealType: MealType (enum: breakfast/lunch/dinner/snack)         │
└──────────────────────────────────────────────────────────────────

DailyLog ──────────────────────────────────────────────────────────
│  id: UUID                                                        │
│  date: Date (normiert auf Mitternacht)                           │
│  foodEntries: [FoodEntry]                                        │
│  targetCalories: Double?                                         │
│  mood: Int? (1–5)                                               │
└──────────────────────────────────────────────────────────────────

WeightEntry ────────────────────────────────────────────────────────
│  id: UUID                                                        │
│  date: Date                                                      │
│  weightKg: Double                                                │
│  notes: String?                                                  │
└──────────────────────────────────────────────────────────────────
```

### 3.2 Supersatz-Logik

Supersätze werden über das Feld `supersetGroup: Int?` in `PlanExercise` und `WorkoutSet` abgebildet. Übungen mit identischer `supersetGroup`-Zahl innerhalb desselben Plans bilden einen Supersatz. Eine `supersetGroup = nil` bedeutet: keine Verknüpfung.

```
PlanExercise A  (supersetGroup: 1) ─┐
PlanExercise B  (supersetGroup: 1) ─┘  → Supersatz
PlanExercise C  (supersetGroup: nil)    → Einzelübung
PlanExercise D  (supersetGroup: 2) ─┐
PlanExercise E  (supersetGroup: 2) ─┘  → Supersatz
```

---

## 4. Navigation & Routing

Die App nutzt eine `TabView` mit fünf Haupt-Tabs:

| Tab | Icon | Feature |
|-----|------|---------|
| Home | house.fill | Dashboard |
| Training | dumbbell.fill | Pläne & Mediathek |
| Ernährung | fork.knife | Kalorien & Makros |
| Statistik | chart.xyaxis.line | Analyse & Fortschritt |
| Einstellungen | gearshape.fill | Health, Export, Profil |

Innerhalb von **Training** gibt es eine interne Navigation:
- `TrainingPlansView` → `PlanDetailView` → `WorkoutSessionView` (Full-Screen Cover)
- `ExerciseLibraryView` → `ExerciseDetailView`

**WorkoutSessionView** wird als `.fullScreenCover` präsentiert, um den immersiven Workout-Modus zu ermöglichen.

---

## 5. Services & Systemintegration

### 5.1 HealthKitService
- Kapselt alle `HKHealthStore`-Interaktionen
- Permissions: `.workoutType`, `.dietaryEnergyConsumed`, `.bodyMass`
- Exportiert: `HKWorkout`, `HKQuantitySample` (Kalorien), `HKQuantitySample` (Gewicht)
- Respektiert den Sync-Modus aus den Einstellungen (`UserDefaults`)

### 5.2 NotificationService
- Nutzt `UNUserNotificationCenter`
- Plant lokale Benachrichtigungen für Pausen-Timer
- Verwendet `UNTimeIntervalNotificationTrigger` mit der Pausendauer der Übung
- `interruptionLevel: .timeSensitive` für zuverlässige Hintergrund-Zustellung
- Benachrichtigungen werden beim Abbruch eines Workouts storniert

### 5.3 PDFExportService
- Nutzt `UIGraphicsPDFRenderer` (A4: 595×842pt)
- Export 1: Leerer Plan (Übungen, Sätze, Gewicht/Wiederholungs-Felder als Tabelle)
- Export 2: Historischer Plan inkl. Swift Charts-generierter Steigerungsgrafik (als `UIImage` via `ImageRenderer` eingebettet)

### 5.4 SeedDataService
- Liest `DefaultExercises_de.json` / `DefaultExercises_en.json` aus dem Bundle
- Sprachwahl per `Locale.current.language.languageCode`
- Wird beim ersten App-Start aufgerufen (geprüft per `UserDefaults`-Flag `hasSeededExercises`)
- Populiert die SwiftData-Datenbank mit Standardübungen in allen 4 Kategorien

### 5.5 FoodAPIService *(neu)*
- `actor`-basierter Swift Concurrency Service
- Kommuniziert mit der **OpenFoodFacts REST API** (`https://world.openfoodfacts.org/api/v2/product/{barcode}.json`)
- Decodiert Kalorien und Makronährstoffe (pro 100g) sowie Portionsgröße
- Bietet Fallback-Handling: Produkt nicht gefunden → manuelle Eingabe
- Kein API-Key erforderlich (OpenFoodFacts ist öffentlich)

### 5.6 WidgetDataService *(neu)*
- Schreibt aktuelle Tagesdaten in `UserDefaults(suiteName: "group.com.fittrackpro.app")`
- Shared App Group zwischen App-Target und WidgetKit-Extension
- Ruft `WidgetCenter.shared.reloadAllTimelines()` nach jedem relevanten Datenevent
- Schlüssel: `widget_calories_today`, `widget_calories_target`, `widget_weight`, `widget_last_workout`

---

## 6. Design System

| Element | Spezifikation |
|---------|---------------|
| Primärfarbe | Dynamisches Blau / Akzentfarbe konfigurierbar |
| Hintergrund | Adaptiv (Light/Dark Mode) |
| Typografie | SF Pro (System), SF Rounded für Display-Text |
| Abstände | 8pt-Raster |
| Eckenradius | 12pt (Cards), 8pt (Buttons) |
| Animationen | `.spring(response:dampingFraction:)` für Übergänge |
| Charts | Swift Charts (native) |

---

## 7. Technologie-Stack Zusammenfassung

| Bereich | Framework / Technologie |
|---------|------------------------|
| UI | SwiftUI |
| Persistenz | SwiftData |
| Cloud-Sync | CloudKit |
| Diagramme | Swift Charts |
| HealthKit | HealthKit |
| Benachrichtigungen | UserNotifications |
| PDF-Generierung | UIKit (UIGraphicsPDFRenderer) |
| Barcode-Scanner | AVFoundation |
| Lebensmittel-API | OpenFoodFacts REST (URLSession) |
| Home Screen Widget | WidgetKit |
| Hintergrundtasks | BackgroundTasks / App Lifecycle |
| Einstellungen | UserDefaults (AppStorage) |
| Medien | PhotosUI / AVKit |
| Lokalisierung | Localizable.strings (DE, EN) |

