# Feature Requests & Backlog

Diese Datei sammelt Ideen, Wünsche und optionale Features für die App, die aktuell nicht Teil der direkten Meilenstein-Planung sind, aber als "Nice-to-Have" für die Zukunft festgehalten werden sollen.

## UI / UX Verbesserungen

- [ ] **Interaktives Pull-to-Minimize für WorkoutSessionView**
  - **Beschreibung:** Anstatt das Workout über das `.fullScreenCover` mittels einfachem Klick/Swipe zu schließen, soll die `WorkoutSessionView` als Custom-Overlay (ZStack) umgebaut werden.
  - **Ziel:** Der Nutzer kann das Workout-Fenster interaktiv an den Finger gekoppelt nach unten ziehen (y-Offset ändert sich proportional zur Fingerbewegung), um es nahtlos in den Mini-Player übergehen zu lassen. Wenn man nicht weit genug zieht, federt die Ansicht zurück nach oben.
  - **Aufwand:** Mittel (Erfordert Umbau der View-Präsentation im `AppRouter` / `MainTabView`).

- [ ] **Dynamische Farbgebung für Kalorien-Kreis (Dashboard)**
  - **Beschreibung:** Wenn die Kalorien um einen bestimmten Wert (z.B. 400 kcal) über dem Ziel liegen, soll sich der Kreis im Dashboard rot färben. Wenn am Abend noch deutlich zu wenige Kalorien (z.B. 400 kcal unter Ziel) erreicht wurden, soll er sich orange färben.
  - **Konfiguration:** Das Limit (z.B. 400 kcal) soll in den Settings einstellbar sein.
  - **Design-Aspekt:** Die Idee kann designtechnisch noch verfeinert werden (z.B. fließende Farbverläufe oder Warn-Icons), um besser zum modernen UI zu passen.

- [ ] **Verbrannte Kalorien in der App anzeigen**
  - **Beschreibung:** Die durch Workouts und Schritte verbrannten Kalorien (z.B. per HealthKit `activeEnergyBurned` oder eigener Schätzung) sollen direkt auf dem Dashboard oder im Ernährungs-Tab ausgewiesen werden.
  - **Ziel:** Der Nutzer erhält einen besseren Überblick über seinen echten Tagesumsatz und kann so seine zugeführten Kalorien besser steuern.

- [ ] **Widgets erweitern und verfeinern**
  - **Beschreibung:** Die aktuellen Widgets (klein und mittel) weiter überarbeiten (z.B. Design-Polishing) und eventuell ganz neue Widgets hinzufügen (z.B. ein großes Widget oder spezielle Widgets nur für Workouts/Makros).
  - **Ziel:** Dem Nutzer noch mehr Informationen und Schnellzugriffe direkt auf dem Homescreen bieten.
