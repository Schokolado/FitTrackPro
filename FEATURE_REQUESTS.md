# Feature Requests & Backlog

Diese Datei sammelt Ideen, Wünsche und optionale Features für die App, die aktuell nicht Teil der direkten Meilenstein-Planung sind, aber als "Nice-to-Have" für die Zukunft festgehalten werden sollen.

## UI / UX Verbesserungen

- [ ] **Interaktives Pull-to-Minimize für WorkoutSessionView**
  - **Beschreibung:** Anstatt das Workout über das `.fullScreenCover` mittels einfachem Klick/Swipe zu schließen, soll die `WorkoutSessionView` als Custom-Overlay (ZStack) umgebaut werden.
  - **Ziel:** Der Nutzer kann das Workout-Fenster interaktiv an den Finger gekoppelt nach unten ziehen (y-Offset ändert sich proportional zur Fingerbewegung), um es nahtlos in den Mini-Player übergehen zu lassen. Wenn man nicht weit genug zieht, federt die Ansicht zurück nach oben.
  - **Aufwand:** Mittel (Erfordert Umbau der View-Präsentation im `AppRouter` / `MainTabView`).
