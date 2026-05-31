# FitTrackPro – Status-Report & Entwicklungsprotokoll

> **Projekt:** FitTrackPro – iOS Krafttraining & Ernährungs-App  
> **Plattform:** iOS 17+ · Swift 5.9 · SwiftUI · SwiftData  
> **Start:** 2026-05-29  
> **Letztes Update:** 2026-05-31

---

## Übersicht

| Kategorie | Status |
|-----------|--------|
| Dokumentation | ✅ Abgeschlossen |
| Architekturentscheidungen | ✅ Abgeschlossen |
| M0 – Projektsetup | ✅ Abgeschlossen |
| M1 – Datenmodell | ✅ Abgeschlossen |
| M2 – Übungs-Mediathek | ✅ Abgeschlossen |
| M3 – Trainingspläne | ✅ Abgeschlossen |
| M4 – Workout-Modus | ✅ Abgeschlossen |
| M5 – Workout-Abschluss | ✅ Abgeschlossen |
| M6 – Ernährung + Barcode | ⏳ Ausstehend |
| M7 – Gewichtstracker | ⏳ Ausstehend |
| M8 – Dashboard | ⏳ Ausstehend |
| M9 – Statistik & Analyse | ⏳ Ausstehend |
| M10 – PDF-Export | ⏳ Ausstehend |
| M11 – Apple Health | ⏳ Ausstehend |
| M12 – Einstellungen | 🔧 In Arbeit (Basis fertig) |
| M13 – CloudKit Sync | ⏳ Ausstehend |
| M14 – WidgetKit Extension | ⏳ Ausstehend |
| M15 – Lokalisierung DE+EN | ⏳ Ausstehend |
| M16 – Polish & QA | ⏳ Ausstehend |
| M17 – App Store Release | ⏳ Ausstehend |

---

## Einträge

### 2026-05-31 – Code-Cleanup & Architektur-Konsolidierung

**Status:** ✅ Fertig  
**Bearbeitet:** Architekturbereinigung (3 kritische Issues aus Validierung)

**Implementiert:**
- Magic-String-Notifications ersetzt: `NSNotification.Name("WorkoutFinished")` in `WorkoutSummaryView` und `WorkoutSessionView` durch typisierte Konstante `Notification.Name.workoutFinished` (aus `NotificationNames.swift`) ersetzt. Sender und Empfänger nutzen jetzt dieselbe Konstante.
- `DateFormatter` gecacht: In `WorkoutSessionViewModel` wird `DateFormatter` jetzt als `private static let` einmalig angelegt statt jede Sekunde neu.
- Datei-Konsolidierung: Alle aktiven Swift-Quellen aus dem Projekt-Root in die korrekte `Features/` und `Core/`-Verzeichnisstruktur verschoben. `project.pbxproj` entsprechend aktualisiert. Root enthielt die neuesten Versionen, die massiv von veralteten `Features/`-Kopien abwichen.

**Nächster Schritt:** Milestone 6 (Ernährungs-Tracker)

### 2026-05-31 – Post-M5 Features (dokumentiert nachträglich)

**Status:** ✅ Fertig  
**Bearbeitet:** UI-Verbesserungen und Feature-Erweiterungen nach Milestone 5

**Implementiert:**
- **ThemeManager** (`Core/Managers/ThemeManager.swift`): Dynamische Kategorie-Farben, pro Kategorie konfigurierbar via `UserDefaults`, mit `Color(hex:)` und `toHex()` Extension.
- **ThemeSettingsView** (`Features/Settings/ThemeSettingsView.swift`): UI zum Anpassen der Kategorie-Farben in den Einstellungen.
- **ExerciseCardView** (`Features/Training/ExerciseLibrary/ExerciseCardView.swift`): Moderne Floating-Card-Darstellung in der Übungsbibliothek mit dynamischen Kategorie-Icons und -Farben.
- **ExerciseIconView** (`Core/Views/ExerciseIconView.swift`): Wiederverwendbare Icon-Komponente pro Übungskategorie.
- **Dynamische Icons in Exercise.swift**: Extension mit `themeColor`, `themeIcon` und `customIconName` Properties.
- **Segmented Control im Training-Tab** (`TrainingMainView`): Umschalten zwischen Trainingsplänen und Übungsbibliothek.
- **Auto-Expand & Auto-Scroll in PlanDetailView**: Neu hinzugefügte Übungen werden automatisch aufgeklappt und ins Bild gescrollt.
- **Auto-Expand nächste Übung im Workout-Modus**: Nach Abschluss einer Übung wird automatisch die nächste Gruppe aufgeklappt und gescrollt.
- **Manueller Timer mit Favoriten** (`WorkoutSessionView`): Timer-Menü mit drei konfigurierbaren Favoriten (30/60/90 Sek.) und freier Eingabe via `@AppStorage`.
- **Ad-hoc Übungen im laufenden Workout**: Übungen können aus der Bibliothek zum laufenden Workout hinzugefügt werden, optional mit Übernahme in den Plan.
- **Auto-Finish Alert**: Nach Abschluss aller Übungen erscheint automatisch ein Hinweis zum Beenden des Workouts.
- **Logger+App.swift**: Zentrales `os.Logger`-Setup für strukturiertes Logging.
- **NotificationNames.swift**: Typisierte `Notification.Name`-Konstanten als zentrale Quelle.
- **TrainingPlan+Grouping.swift**: `ExerciseGroup`-Struct und `groupedPlanExercises`-Extension ausgelagert.

**Nächster Schritt:** → s.o. (Cleanup)

### 2026-05-30 – Milestone 5 abgeschlossen

**Status:** ✅ Fertig  
**Bearbeitet:** Workout-Abschluss & Zusammenfassung

**Implementiert:**
- `WorkoutSummaryView`: Zeigt automatisch berechnete Statistiken an (Dauer, Gesamtvolumen in kg, Anzahl der abgehakten Sätze).
- Sterne-Rating für die Stimmung (Mood) und Picker für RPE-Intensität (1-5).
- Speichern-Button: Sichert alle Daten (`endTime`, `moodRating`, `intensityRating`, `notes`) im SwiftData-Context und schließt den Workout-Modus.
- Animierter Pokal als visuelles Feedback für das abgeschlossene Training.
- `WorkoutSessionView` aktualisiert, um die Summary als Sheet anzuzeigen (ohne Swipe-to-dismiss).

**Nächster Schritt:** Milestone 6 (Ernährung + Barcode)

### 2026-05-30 – Milestone 4 abgeschlossen

**Status:** ✅ Fertig  
**Bearbeitet:** Workout-Modus (Timer, Sätze, Pausen)

**Implementiert:**
- `WorkoutSessionViewModel`: Steuert den Workout-Timer (Gesamtdauer) und den Pausen-Timer via `Date()`.
- `NotificationService`: Plant lokale Benachrichtigungen (`UNUserNotificationCenter`) für ablaufende Pausen.
- `WorkoutSessionView`: Stellt den laufenden Workout dar. Gruppiert die Sätze nach Übungen. 
- Rest-Timer UI taucht als rotes Banner am oberen Rand auf und lässt sich überspringen.
- `WorkoutSetRowView`: Pre-filled Soll-Werte für Sätze, die editierbar sind, bevor sie mit dem ✅ Checkmark bestätigt werden.
- Abbrechen-Dialog (verwirft die Session in SwiftData) und vorläufiger Beenden-Button.
- Start des Workouts aus dem Plan: Beim Klick auf "Workout Starten" in `PlanDetailView` wird die Session anhand der PlanExercises im Hintergrund vorausgefüllt und geöffnet.

**Nächster Schritt:** Milestone 5 (Workout-Abschluss & Rating)

### 2026-05-30 – Milestone 3 abgeschlossen

**Status:** ✅ Fertig  
**Bearbeitet:** Trainingspläne und Übungs-Soll-Werte

**Implementiert:**
- `TrainingPlansView`: Anzeige aller Pläne mit Löschen- und Duplizieren-Funktion via SwipeActions.
- `PlanDetailView`: Bearbeiten der Pläne, Umbenennen und Hinzufügen von Übungen.
- `ExerciseSelectionView`: Übungen aus der Seed-Datenbank auswählen und dem Plan hinzufügen.
- `PlanExerciseRowView`: Eingabe der Soll-Werte (Sätze, Reps, Gewicht, Pause) und Supersatz-Toggle.
- `AppRouter` aktualisiert: Der Training-Tab zeigt nun die Trainingspläne an. Die Übungsbibliothek ist über das Buch-Icon oben links erreichbar.
- Alle Listen unterstützen Drag-to-reorder und native Deletion via SwiftData.

**Nächster Schritt:** Milestone 4 (Workout-Modus)

### 2026-05-30 – Milestone 2 abgeschlossen

**Status:** ✅ Fertig  
**Bearbeitet:** Übungs-Mediathek und Seed-Daten

**Implementiert:**
- `DefaultExercises_de.json` und `DefaultExercises_en.json` mit Start-Übungen.
- `SeedDataService` geschrieben, der beim ersten Start der App die JSON-Daten in SwiftData überträgt.
- `ExerciseLibraryView` und `ExerciseLibraryViewModel` für Liste, Filter (Chips) und Suche.
- `ExerciseFormView` zum Anlegen und Bearbeiten von eigenen Übungen.
- `ExerciseDetailView` mit Platzhaltern für Medien (Milestone 2.1).
- Swipen zum Löschen (in List) funktioniert nativ durch Löschen aus dem ModelContext.

**Nächster Schritt:** Milestone 3 (Trainingspläne)

### 2026-05-30 – Milestone 0 & 1 abgeschlossen

**Status:** ✅ Fertig  
**Bearbeitet:** Xcode-Projekt Fundament und komplettes SwiftData-Datenmodell

**Implementiert:**
- Ordnerstruktur, Design System (`Color+Theme.swift`), `AppRouter` und Lokalisierungsdateien.
- App Icon Asset Catalog repariert.
- `Exercise`, `TrainingPlan`, `PlanExercise`, `WorkoutSession`, `WorkoutSet`, `FoodEntry`, `DailyLog`, `WeightEntry` in `Core/Models/` als `@Model` Klassen angelegt.
- Korrekte optionale Attribute und Default-Werte für CloudKit-Kompatibilität (`NSPersistentCloudKitContainer`) gesetzt.
- Inverse `@Relationship`s (Nullify / Cascade) definiert.
- `FitTrackProApp.swift` mit dem `ModelContainer` konfiguriert.

**Nächster Schritt:** Milestone 2 (Übungs-Mediathek)

---

### 2026-05-29 – Dokumentationsphase abgeschlossen

**Status:** ✅ Fertig  
**Bearbeitet:** Initiale Planungsdokumente erstellt

**Erstellt:**
- `ARCHITEKTUR.md` – Systemarchitektur, SwiftData-Datenmodell, Ordnerstruktur, Navigationssystem, Services
- `TODO.md` – 17 Meilensteine mit detaillierter Schritt-für-Schritt-Checkliste
- `IMPLEMENTATION_PLAN.md` – Vollständige Swift-Datenstrukturen, Service-Spezifikationen, Framework-Anforderungen, Design System
- `REPORT.md` – Dieses Statusprotokoll

---

### 2026-05-29 – Architekturentscheidungen getroffen

**Status:** ✅ Fertig  
**Bearbeitet:** Alle offenen Designfragen beantwortet; alle vier Dokumente entsprechend aktualisiert

**Entscheidungen:**

| Feature | Entscheidung | Auswirkung |
|---------|-------------|-----------|
| Barcode-Scanner | ✅ AVFoundation + OpenFoodFacts API | `BarcodeScannerView.swift`, `FoodAPIService.swift` neu |
| iCloud-Sync | ✅ SwiftData + CloudKit | `ModelContainer(.automatic)`, M13 CloudKit-Testing neu |
| Home Screen Widget | ✅ WidgetKit (Small + Medium) | WidgetKit Extension Target, `WidgetDataService.swift`, M14 neu |
| Apple Watch | ❌ Vorerst nicht | – |
| Sprachen | ✅ DE + EN | `de.lproj/` + `en.lproj/`, M15 Lokalisierung neu |
| Gewichtseinheit | ✅ Nur kg | AppStorage-Key `weight_unit` vorerst unused |

**Dokumente aktualisiert:**
- `ARCHITEKTUR.md` – §0 Entscheidungen, neue Services (5.5/5.6), Widget-Target in Ordnerstruktur, erweiterte Tech-Stack-Tabelle
- `IMPLEMENTATION_PLAN.md` – §0 Entscheidungstabelle, aktualisierter Tech-Stack, CloudKit-Konfiguration, neue Sektionen §12–§15 (OpenFoodFacts, CloudKit, WidgetKit, Lokalisierung)
- `TODO.md` – M0 mit Capability-Setup, M2 mit lokalisierten Seed-Dateien, M5/7 mit WidgetDataService-Calls, M6 mit Barcode-Scanner, M12 erweitert, neue M13–M15, M16–M17 (ex M13–M14)

**Nächster Schritt:** Xcode-Projekt erstellen → **Milestone 0**  
Bei Bereitschaft: „Go" sagen.

---

<!-- 
VORLAGE FÜR NEUE EINTRÄGE:

### YYYY-MM-DD – [Titel]

**Status:** ✅ Fertig | 🔧 In Arbeit | ❌ Blockiert | ⏭️ Übersprungen  
**Milestone:** M0 – Projektsetup  
**Bearbeitet:** [Kurzbeschreibung]

**Implementiert:**
- 

**Probleme / Entscheidungen:**
- 

**Nächster Schritt:** 
-->


---

<!-- 
VORLAGE FÜR NEUE EINTRÄGE:

### YYYY-MM-DD – [Titel]

**Status:** ✅ Fertig | 🔧 In Arbeit | ❌ Blockiert | ⏭️ Übersprungen  
**Milestone:** M0 – Projektsetup  
**Bearbeitet:** [Kurzbeschreibung]

**Implementiert:**
- 

**Probleme / Entscheidungen:**
- 

**Nächster Schritt:** 
-->
