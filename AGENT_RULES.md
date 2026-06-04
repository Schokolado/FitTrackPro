# Agent Core Rules

These rules must be strictly followed for every task in this project.

1. **Protocol Changes**: Du MUSST zwingend nach JEDER erledigten Aufgabe oder jedem Feature alle relevanten Markdown-Dateien aktualisieren (insbesondere `TODO.md` und `REPORT.md`), bevor du dem User antwortest!
2. **Clean Build**: Always perform a clean build (`xcodebuild -scheme FitTrackPro -destination 'generic/platform=iOS Simulator' clean build`) after modifying code to verify the changes.
3. **Fix Build Errors**: Automatically fix any issues that arise during the build process.
4. **Definition of Done**: A task is ONLY considered finished when:
   - The changes have been fully implemented.
   - The markdown reports/documentation have been updated.
   - The project builds successfully (`** BUILD SUCCEEDED **`).
5. **Simulator Launch**: After a successful build, automatically boot the iOS Simulator (`open -a Simulator`), build the `.app` payload, and launch it via `xcrun simctl` so the user can immediately review the UI changes without manual clicking.
