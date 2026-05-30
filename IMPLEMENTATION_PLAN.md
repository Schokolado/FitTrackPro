# FitTrackPro – Technischer Implementierungsplan

> **Zweck:** Detaillierte technische Spezifikationen, Datenstrukturen, Framework-Anforderungen und Implementierungsdetails für alle Features.

---

## 0. Getroffene Architekturentscheidungen

| Frage | Entscheidung |
|-------|-------------|
| Barcode-Scanner Lebensmittel | ✅ Ja – AVFoundation Scanner + OpenFoodFacts REST API |
| iCloud-Sync | ✅ Ja – SwiftData + CloudKit |
| Home Screen Widget | ✅ Ja – WidgetKit-Extension (Kalorien, Gewicht, letztes Workout) |
| Apple Watch | ❌ Nein (vorerst, spätere Erweiterung möglich) |
| Sprachen | ✅ Deutsch (DE) + Englisch (EN) – Localizable.strings von Anfang an |
| Gewichtseinheit | ✅ Nur kg (vorerst) |

---

## 1. Technologie-Stack & Mindestanforderungen

| Komponente | Technologie | Mindestversion |
|-----------|------------|---------------|
| Deployment Target | iOS | 17.0 |
| Sprache | Swift | 5.9 |
| UI-Framework | SwiftUI | iOS 17 API |
| ORM / Persistenz | SwiftData + CloudKit | iOS 17 |
| Cloud-Sync | CloudKit (NSPersistentCloudKitContainer) | iOS 13 |
| Diagramme | Swift Charts | iOS 16 |
| Health-Integration | HealthKit | iOS 8 |
| Benachrichtigungen | UserNotifications | iOS 10 |
| PDF-Export | UIKit (UIGraphicsPDFRenderer) | iOS 10 |
| Medien-Auswahl | PhotosUI | iOS 14 |
| Video-Wiedergabe | AVKit | iOS 8 |
| Barcode-Scanner | AVFoundation | iOS 14 |
| Lebensmittel-API | OpenFoodFacts REST API | – |
| Home Screen Widget | WidgetKit | iOS 14 |
| Hintergrundtasks | BackgroundTasks | iOS 13 |
| Lokalisierung | Localizable.strings (DE, EN) | – |
| Einstellungen | @AppStorage (UserDefaults) | iOS 14 |
| Xcode-Version | Xcode | 15.0+ |

---

## 2. SwiftData Datenmodell – Vollständige Spezifikation

### 2.1 `ExerciseCategory` (Enum)

```swift
enum ExerciseCategory: String, Codable, CaseIterable {
    case machine        = "Maschinen"
    case freeWeight     = "Freie Gewichte"
    case cable          = "Kabelzug"
    case bodyweight     = "Eigengewicht"
}
```

### 2.2 `MealType` (Enum)

```swift
enum MealType: String, Codable, CaseIterable {
    case breakfast = "Frühstück"
    case lunch     = "Mittagessen"
    case dinner    = "Abendessen"
    case snack     = "Snack"
}
```

### 2.3 `Exercise` (@Model)

```swift
@Model
final class Exercise {
    var id: UUID
    var name: String
    var category: ExerciseCategory
    var notes: String
    var externalVideoURL: URL?
    var localMediaPaths: [String]          // Relative Pfade im Documents-Verzeichnis
    var defaultRestDuration: TimeInterval   // In Sekunden (z.B. 90.0)
    var isCustom: Bool                      // false = Seed-Daten, true = benutzerdefiniert
    var sortOrder: Int
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \PlanExercise.exercise)
    var planExercises: [PlanExercise]

    @Relationship(deleteRule: .nullify, inverse: \WorkoutSet.exercise)
    var workoutSets: [WorkoutSet]
}
```

### 2.4 `TrainingPlan` (@Model)

```swift
@Model
final class TrainingPlan {
    var id: UUID
    var name: String
    var createdAt: Date
    var sortOrder: Int

    @Relationship(deleteRule: .cascade, inverse: \PlanExercise.plan)
    var planExercises: [PlanExercise]

    @Relationship(deleteRule: .nullify, inverse: \WorkoutSession.plan)
    var sessions: [WorkoutSession]
}
```

### 2.5 `PlanExercise` (@Model)

```swift
@Model
final class PlanExercise {
    var id: UUID
    var sortOrder: Int
    var supersetGroup: Int?       // nil = kein Supersatz; gleiche Zahl = gleicher Supersatz
    var targetSets: Int
    var targetReps: Int
    var targetWeight: Double?
    var restDuration: TimeInterval

    var plan: TrainingPlan?
    var exercise: Exercise?

    @Relationship(deleteRule: .nullify, inverse: \WorkoutSet.planExercise)
    var workoutSets: [WorkoutSet]
}
```

### 2.6 `WorkoutSession` (@Model)

```swift
@Model
final class WorkoutSession {
    var id: UUID
    var startedAt: Date
    var finishedAt: Date?
    var durationSeconds: TimeInterval
    var moodRating: Int?           // 1–5
    var intensityRating: Int?      // 1–5
    var notes: String
    var isCompleted: Bool          // false wenn abgebrochen
    var syncedToHealthKit: Bool

    var plan: TrainingPlan?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.session)
    var performedSets: [WorkoutSet]
}
```

### 2.7 `WorkoutSet` (@Model)

```swift
@Model
final class WorkoutSet {
    var id: UUID
    var setNumber: Int
    var targetReps: Int?
    var targetWeight: Double?
    var actualReps: Int
    var actualWeight: Double
    var isCompleted: Bool
    var completedAt: Date?
    var supersetGroup: Int?

    var session: WorkoutSession?
    var exercise: Exercise?
    var planExercise: PlanExercise?
}
```

### 2.8 `DailyLog` (@Model)

```swift
@Model
final class DailyLog {
    var id: UUID
    var date: Date               // Normiert: Calendar.current.startOfDay(for: date)
    var targetCalories: Double?
    var targetProtein: Double?
    var targetCarbs: Double?
    var targetFat: Double?
    var mood: Int?               // 1–5

    @Relationship(deleteRule: .cascade, inverse: \FoodEntry.dailyLog)
    var foodEntries: [FoodEntry]
}
```

### 2.9 `FoodEntry` (@Model)

```swift
@Model
final class FoodEntry {
    var id: UUID
    var name: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var loggedAt: Date
    var mealType: MealType

    var dailyLog: DailyLog?
}
```

### 2.10 `WeightEntry` (@Model)

```swift
@Model
final class WeightEntry {
    var id: UUID
    var date: Date
    var weightKg: Double
    var notes: String
}
```

### 2.11 ModelContainer-Konfiguration (mit CloudKit)

```swift
// In FitTrackProApp.swift
let schema = Schema([
    Exercise.self,
    TrainingPlan.self,
    PlanExercise.self,
    WorkoutSession.self,
    WorkoutSet.self,
    DailyLog.self,
    FoodEntry.self,
    WeightEntry.self
])

// CloudKit-Sync aktivieren
let modelConfiguration = ModelConfiguration(
    schema: schema,
    isStoredInMemoryOnly: false,
    cloudKitDatabase: .automatic  // Container-ID: iCloud.com.fittrackpro.app
)
let container = try! ModelContainer(for: schema, configurations: [modelConfiguration])
```

> **Xcode Capability:** `iCloud` → CloudKit aktivieren, Container `iCloud.com.fittrackpro.app` anlegen.  
> **Background Modes:** `Remote notifications` aktivieren (für CloudKit-Push-Sync).

---

## 3. Service-Spezifikationen

### 3.1 HealthKitService

**Benötigte Permissions (Info.plist):**
- `NSHealthShareUsageDescription`
- `NSHealthUpdateUsageDescription`

**Zu anfordernde Typen:**
```swift
let readTypes: Set<HKObjectType> = [
    HKObjectType.workoutType(),
    HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
    HKObjectType.quantityType(forIdentifier: .bodyMass)!
]
let writeTypes: Set<HKSampleType> = [
    HKObjectType.workoutType(),
    HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
    HKObjectType.quantityType(forIdentifier: .bodyMass)!
]
```

**Workout-Export:**
```swift
func exportWorkout(session: WorkoutSession) async throws {
    // HKWorkout erstellen mit Start/End-Zeit und totalEnergyBurned
    // HKWorkoutActivity optional
    // HKHealthStore.save() aufrufen
}
```

**Sync-Modi:**
- `autoSync: Bool` → gespeichert in `@AppStorage("healthkit_auto_sync")`
- Wenn `autoSync == true`: Automatisch nach `WorkoutSummaryView` exportieren
- Wenn `autoSync == false`: Button „An Apple Health senden" in `WorkoutSummaryView` anzeigen

### 3.2 NotificationService

**Benötigte Permission (Info.plist):**
- Keine (wird zur Laufzeit via `UNUserNotificationCenter.requestAuthorization` angefragt)

**Implementierungsdetails:**
```swift
func scheduleRestTimerNotification(exerciseName: String, duration: TimeInterval, identifier: String) {
    let content = UNMutableNotificationContent()
    content.title = "Pause beendet!"
    content.body = "Bereit für den nächsten Satz: \(exerciseName)"
    content.sound = .default
    content.interruptionLevel = .timeSensitive  // Wichtig für Hintergrundablieferung

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: duration, repeats: false)
    let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    UNUserNotificationCenter.current().add(request)
}

func cancelRestTimerNotification(identifier: String) {
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
}
```

**App-Hintergrundverhalten:**
- `UIApplicationDelegate.applicationDidEnterBackground`: Timer läuft weiter (Notification bereits geplant)
- Bei Workout-Abbruch: Alle ausstehenden Notifications canceln

### 3.3 PDFExportService

**Export 1 – Leerer Trainingsplan:**

Layout:
1. Kopfzeile: App-Logo + Plan-Name + Datum
2. Pro Übung: Tabelle mit Spalten: `#` | `Übung` | `Sätze` | `Wdh.` | `Gewicht (kg)` | `Notizen`
3. Fußzeile: App-Name + Seitenzahl

```swift
func exportEmptyPlan(_ plan: TrainingPlan) -> Data {
    let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842)) // A4
    return renderer.pdfData { context in
        context.beginPage()
        // Zeichenoperationen mit NSAttributedString und UIBezierPath
    }
}
```

**Export 2 – Historischer Plan mit Steigerungskurve:**

Schritte:
1. Swift Chart als `UIImage` rendern (via `ImageRenderer` oder `UIGraphicsImageRenderer`)
2. Workout-Sessions des Plans laden und als Tabelle formatieren
3. Chart-Bild und Tabelle auf PDF-Seiten verteilen

```swift
// Chart als Bild rendern (iOS 16+)
@MainActor
func renderChartAsImage<V: View>(_ view: V, size: CGSize) -> UIImage {
    let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
    renderer.scale = 2.0 // Retina
    return renderer.uiImage ?? UIImage()
}
```

### 3.4 SeedDataService

**DefaultExercises.json Struktur:**
```json
{
  "exercises": [
    {
      "name": "Bankdrücken",
      "category": "freeWeight",
      "defaultRestDuration": 120,
      "notes": "Griffbreite schulterbreit, kontrollierte Bewegung"
    },
    {
      "name": "Kniebeugen",
      "category": "freeWeight",
      "defaultRestDuration": 180,
      "notes": "Füße schulterbreit, Oberschenkel parallel zum Boden"
    }
    // ... weitere Übungen
  ]
}
```

**Seed-Logik:**
```swift
func seedIfNeeded(context: ModelContext) {
    guard !UserDefaults.standard.bool(forKey: "hasSeededExercises") else { return }
    // JSON laden, dekodieren, Exercise-Objekte in context einfügen
    UserDefaults.standard.set(true, forKey: "hasSeededExercises")
    try? context.save()
}
```

---

## 4. Workout-Modus – Zustandsmaschine

Der `WorkoutSessionViewModel` verwaltet einen komplexen Zustand:

```swift
enum WorkoutPhase {
    case idle
    case exercising(exerciseIndex: Int, setIndex: Int)
    case resting(exerciseIndex: Int, remainingSeconds: TimeInterval)
    case manualRest
    case summary
    case cancelled
}
```

**Timer-Implementierung:**
```swift
// Globaler Workout-Timer
private var workoutStartTime: Date = Date()
private var workoutTimer: Timer?

// Pausen-Timer (pro Satz)
private var restTimer: Timer?
private var restRemaining: TimeInterval = 0

// Hintergrund-Handling
func applicationDidEnterBackground() {
    // Timer-Snapshots mit Date() speichern
    // Bei Rückkehr: Differenz berechnen und State aktualisieren
}
```

---

## 5. Statistik-Aggregationslogik

Alle Queries nutzen SwiftData `@Query` mit Predicates und Sorts:

```swift
// Volumen pro Session für eine Übung
func totalVolume(for exercise: Exercise, in sessions: [WorkoutSession]) -> [(Date, Double)] {
    sessions.compactMap { session in
        let sets = session.performedSets.filter { $0.exercise == exercise && $0.isCompleted }
        let volume = sets.reduce(0.0) { $0 + (Double($1.actualReps) * $1.actualWeight) }
        guard let date = session.finishedAt, volume > 0 else { return nil }
        return (date, volume)
    }
}

// Max. Gewicht pro Session
func maxWeight(for exercise: Exercise, in sessions: [WorkoutSession]) -> [(Date, Double)] {
    sessions.compactMap { session in
        let maxW = session.performedSets
            .filter { $0.exercise == exercise && $0.isCompleted }
            .map { $0.actualWeight }
            .max() ?? 0
        guard let date = session.finishedAt, maxW > 0 else { return nil }
        return (date, maxW)
    }
}
```

---

## 6. Dashboard-Logik

```swift
// Kalorienbilanz heute
var todayCalories: Double {
    todayLog?.foodEntries.reduce(0) { $0 + $1.calories } ?? 0
}

// Trainingsleistung letzte N Tage (Volumen gesamt)
func trainingVolume(days: Int) -> Double {
    let since = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
    return sessions
        .filter { ($0.finishedAt ?? Date.distantPast) >= since && $0.isCompleted }
        .flatMap { $0.performedSets }
        .filter { $0.isCompleted }
        .reduce(0.0) { $0 + Double($1.actualReps) * $1.actualWeight }
}
```

---

## 7. Berechtigungen & Info.plist Einträge

```xml
<!-- HealthKit -->
<key>NSHealthShareUsageDescription</key>
<string>FitTrackPro liest Gesundheitsdaten um deine Fitness zu tracken.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>FitTrackPro schreibt Workout- und Gewichtsdaten in Apple Health.</string>

<!-- Kamera & Fotos -->
<key>NSCameraUsageDescription</key>
<string>Füge Fotos zu deinen Übungen hinzu.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Wähle Bilder und Videos für deine Übungen.</string>

<!-- Benachrichtigungen werden zur Laufzeit angefragt -->

<!-- Background Modes -->
<key>UIBackgroundModes</key>
<array>
    <string>processing</string>
    <string>fetch</string>
</array>
```

---

## 8. AppStorage-Keys (Einstellungen)

```swift
extension AppStorageKeys {
    static let healthKitAutoSync    = "healthkit_auto_sync"       // Bool, default: true
    static let hasSeededExercises   = "has_seeded_exercises"      // Bool, default: false
    static let weightUnit           = "weight_unit"               // String: "kg" | "lbs"
    static let notificationsEnabled = "notifications_enabled"     // Bool, default: true
    static let targetCalories       = "target_calories"           // Double
    static let targetProtein        = "target_protein"            // Double
    static let targetCarbs          = "target_carbs"              // Double
    static let targetFat            = "target_fat"                // Double
    static let defaultRestDuration  = "default_rest_duration"     // TimeInterval, default: 90
}
```

---

## 9. Design System – Technische Spezifikation

### Farb-Tokens (`Color+Theme.swift`)

```swift
extension Color {
    // Primär-Palette
    static let brand            = Color("BrandPrimary")     // Kräftiges Blau/Indigo
    static let brandSecondary   = Color("BrandSecondary")   // Akzentfarbe (Cyan/Teal)

    // Semantische Farben
    static let success          = Color("Success")           // Grün
    static let warning          = Color("Warning")           // Orange
    static let destructive      = Color("Destructive")       // Rot

    // Hintergründe (adaptiv)
    static let backgroundPrimary    = Color("BackgroundPrimary")
    static let backgroundSecondary  = Color("BackgroundSecondary")
    static let backgroundCard       = Color("BackgroundCard")

    // Text (adaptiv)
    static let textPrimary      = Color("TextPrimary")
    static let textSecondary    = Color("TextSecondary")
}
```

### Animations-Konstanten

```swift
extension Animation {
    static let springy = Animation.spring(response: 0.35, dampingFraction: 0.7)
    static let smooth  = Animation.easeInOut(duration: 0.25)
}
```

### Spacing-System (8pt-Raster)

```swift
enum Spacing {
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 24
    static let xl:  CGFloat = 32
    static let xxl: CGFloat = 48
}
```

---

## 10. Vorgefertigte Übungsliste (Seed-Daten Auszug)

| Kategorie | Übungen (Auswahl) |
|-----------|------------------|
| Freie Gewichte | Bankdrücken, Kniebeugen, Kreuzheben, Schulterdrücken (stehend), Langhantelrudern, Bizeps Curls, Trizeps Dips, Schrägbankdrücken |
| Maschinen | Beinpresse, Lat-Pulldown (Maschine), Butterfly, Cable Crossover (Maschine), Rückenstrecker, Beinbeuger, Beinstrecker, Schulter-Maschine |
| Kabelzug | Kabelzug-Rudern, Trizeps Pushdown, Bizeps Curl Kabel, Face Pulls, Kabel-Flys, Lat-Pulldown (Kabel) |
| Eigengewicht | Klimmzüge, Liegestütze, Dips, Plank, Burpees, Mountain Climbers, Jump Squats, Sit-ups, Hyperextensions |

---

## 11. SwiftData Schema Versioning

Für zukünftige Schemamigrationen wird `VersionedSchema` vorbereitet:

```swift
enum FitTrackProSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] = [
        Exercise.self, TrainingPlan.self, PlanExercise.self,
        WorkoutSession.self, WorkoutSet.self,
        DailyLog.self, FoodEntry.self, WeightEntry.self
    ]
}
```

---

## 12. OpenFoodFacts API – Barcode-Scanner Spezifikation

**API-Endpunkt (Barcode-Lookup):**
```
GET https://world.openfoodfacts.org/api/v2/product/{barcode}.json
```

**Response-Felder (relevant):**
```json
{
  "product": {
    "product_name": "Haferflocken",
    "product_name_de": "Haferflocken",
    "nutriments": {
      "energy-kcal_100g": 366,
      "proteins_100g": 13.5,
      "carbohydrates_100g": 58.7,
      "fat_100g": 7.0
    },
    "serving_size": "40g",
    "serving_quantity": 40
  },
  "status": 1
}
```

**Decodable-Modelle:**
```swift
struct OFFResponse: Decodable {
    let product: OFFProduct?
    let status: Int
}
struct OFFProduct: Decodable {
    let productName: String?
    let productNameDe: String?
    let nutriments: OFFNutriments
    let servingSize: String?
    let servingQuantity: Double?
    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case productNameDe = "product_name_de"
        case nutriments, servingSize = "serving_size"
        case servingQuantity = "serving_quantity"
    }
}
struct OFFNutriments: Decodable {
    let kcalPer100g: Double?
    let proteinPer100g: Double?
    let carbsPer100g: Double?
    let fatPer100g: Double?
    enum CodingKeys: String, CodingKey {
        case kcalPer100g = "energy-kcal_100g"
        case proteinPer100g = "proteins_100g"
        case carbsPer100g = "carbohydrates_100g"
        case fatPer100g = "fat_100g"
    }
}
```

**Service (`FoodAPIService.swift`):**
```swift
actor FoodAPIService {
    private let baseURL = "https://world.openfoodfacts.org/api/v2/product"
    private let session = URLSession.shared

    func fetchProduct(barcode: String) async throws -> OFFProduct? {
        guard let url = URL(string: "\(baseURL)/\(barcode).json") else { return nil }
        let (data, response) = try await session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        let result = try JSONDecoder().decode(OFFResponse.self, from: data)
        return result.status == 1 ? result.product : nil
    }
}
```

**Barcode-Scanner (`BarcodeScannerView.swift`):**
```swift
// UIViewControllerRepresentable wrapping AVCaptureSession
// Unterstützte Formate: .ean13, .ean8, .upce, .code128
// Scan-Ergebnis → Callback → API-Call → FoodEntryFormView mit pre-filled Feldern
// Mengeneingabe (g) → Makros werden proportional berechnet
```

**User Flow:**
1. In `FoodLogView` → „Barcode scannen" Button
2. `BarcodeScannerView` öffnet sich als Sheet
3. Barcode wird erkannt → API-Call (Ladeindikator)
4. Ergebnis-Sheet: Produkt-Preview mit Mengen-Stepper (g)
5. „Hinzufügen" → `FoodEntry` wird erstellt und in `DailyLog` gespeichert
6. Kein Ergebnis → Fallback auf manuelle Eingabe

**Info.plist Ergänzung:**
```xml
<key>NSCameraUsageDescription</key>
<string>FitTrackPro benötigt die Kamera zum Scannen von Lebensmittel-Barcodes.</string>
```

---

## 13. CloudKit-Sync – Detailspezifikation

**Xcode-Setup:**
- `Signing & Capabilities` → `+` → `iCloud` hinzufügen
- `CloudKit` aktivieren, Container: `iCloud.com.fittrackpro.app`
- `Background Modes` → `Remote notifications` aktivieren

**SwiftData CloudKit-Constraints** (alle @Model-Klassen müssen erfüllen):
- Alle Properties entweder `Optional` oder mit Default-Wert initialisiert
- Keine `enum`-Properties ohne `Codable`-Conformance
- Keine `@Transient`-Properties im Sync
- Eindeutige Constraints mit `#Unique` sind CloudKit-kompatibel

**App Group für Widget-Sharing:**
- `Signing & Capabilities` → `App Groups` → `group.com.fittrackpro.app`
- Shared `UserDefaults(suiteName: "group.com.fittrackpro.app")` für Widget-Daten

**Conflict-Resolution:**
- CloudKit nutzt „Last Write Wins" (Timestamp-basiert)
- `WorkoutSession.startedAt` als semantischer Tiebreaker

**Offline-Verhalten:**
- SwiftData schreibt lokal sofort; CloudKit synct wenn Verbindung besteht
- Kein spezielles Offline-Handling notwendig (SwiftData übernimmt Queue)

---

## 14. WidgetKit-Extension – Detailspezifikation

**Target-Setup (Xcode):**
- `File` → `New Target` → `Widget Extension`
- Name: `FitTrackProWidget`
- Kein Live Activity (vorerst)

**Ordnerstruktur der Extension:**
```
FitTrackProWidget/
├── FitTrackProWidgetBundle.swift   # @main WidgetBundle
├── CalorieWidget.swift             # Small: Kalorienbilanz
├── FitnessDashboardWidget.swift    # Medium: Kalorien + Workout + Gewicht
├── WidgetProvider.swift            # TimelineProvider
└── WidgetEntryView.swift           # SwiftUI Views
```

**Daten-Sharing (App → Widget via App Group):**
```swift
// Nach jedem relevanten Datenevent in der App:
func updateWidgetSharedData() {
    let defaults = UserDefaults(suiteName: "group.com.fittrackpro.app")!
    defaults.set(todayCalories, forKey: "widget_calories_today")
    defaults.set(todayCalorieTarget, forKey: "widget_calories_target")
    defaults.set(currentWeightKg, forKey: "widget_weight")
    defaults.set(lastWorkoutDate?.timeIntervalSince1970, forKey: "widget_last_workout")
    WidgetCenter.shared.reloadAllTimelines()
}
```

**Trigger für Widget-Refresh:**
- Neue Mahlzeit geloggt (`FoodEntryFormView` onSave)
- Workout abgeschlossen (`WorkoutSummaryView` onAppear)
- Gewicht eingetragen (`WeightTrackerView` onSave)

**Widget 1 – Kalorienbilanz (systemSmall):**
- Kreisdiagramm mit Fortschritt (verbrauchte / Ziel-Kalorien)
- Makro-Mini-Balken (P / K / F)

**Widget 2 – Fitness-Dashboard (systemMedium):**
- Links: Kalorien-Ring
- Mitte: Letztes Workout (Name + Datum)
- Rechts: Aktuelles Gewicht

---

## 15. Lokalisierung (DE + EN)

**Struktur:**
```
FitTrackPro/
└── Resources/
    ├── de.lproj/
    │   ├── Localizable.strings
    │   └── InfoPlist.strings
    └── en.lproj/
        ├── Localizable.strings
        └── InfoPlist.strings
```

**Verwendungsregeln:**
```swift
// IMMER String(localized:) oder LocalizedStringKey – nie Hardcode-Strings in Views
Text("workout.start.button")           // SwiftUI nutzt LocalizedStringKey automatisch
let msg = String(localized: "rest.timer.done.body \(exerciseName)")
```

**Seed-Daten Lokalisierung:**
- `DefaultExercises_de.json` – deutsche Übungsnamen und Notizen
- `DefaultExercises_en.json` – englische Namen und Notizen
- `SeedDataService` wählt anhand `Locale.current.language.languageCode`

**Key-Namenskonvention:**
```
<feature>.<component>.<element>
workout.session.cancel.button   = "Abbrechen"       // DE
workout.session.cancel.button   = "Cancel"           // EN
nutrition.log.add.barcode       = "Barcode scannen"  // DE
nutrition.log.add.barcode       = "Scan Barcode"     // EN
```

**InfoPlist.strings (für Systempermissions-Dialoge):**
```
// de.lproj/InfoPlist.strings
"NSCameraUsageDescription" = "FitTrackPro benötigt die Kamera zum Scannen von Lebensmittel-Barcodes.";
"NSHealthShareUsageDescription" = "FitTrackPro liest Gesundheitsdaten für dein Fitness-Tracking.";

// en.lproj/InfoPlist.strings  
"NSCameraUsageDescription" = "FitTrackPro needs camera access to scan food barcodes.";
"NSHealthShareUsageDescription" = "FitTrackPro reads health data for your fitness tracking.";
```

