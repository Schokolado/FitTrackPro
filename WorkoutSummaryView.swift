import SwiftUI
import SwiftData

struct WorkoutSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: WorkoutSession
    
    @State private var mood: Int = 3
    @State private var intensity: Int = 3
    @State private var notes: String = ""
    @State private var showConfetti = false
    
    // Computed statistics
    private var totalVolume: Double {
        session.sets?.filter { $0.isCompleted }
            .reduce(0) { $0 + ($1.actualWeight * Double($1.actualReps)) } ?? 0
    }
    
    private var totalSets: Int {
        session.sets?.filter { $0.isCompleted }.count ?? 0
    }
    
    private var durationString: String {
        let start = session.startTime
        let end = session.endTime ?? Date()
        let interval = end.timeIntervalSince(start)
        
        let hours = Int(interval) / 3600
        let minutes = Int(interval) / 60 % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes) Min."
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Success Header
                    VStack(spacing: 8) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.yellow)
                            .scaleEffect(showConfetti ? 1.0 : 0.5)
                            .opacity(showConfetti ? 1.0 : 0.0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.5, blendDuration: 0.5).delay(0.1), value: showConfetti)
                        
                        Text("Workout abgeschlossen!")
                            .font(.title2.bold())
                    }
                    .padding(.top, 20)
                    
                    // Stats Card
                    HStack(spacing: 20) {
                        StatBadge(title: "Dauer", value: durationString, icon: "clock")
                        StatBadge(title: "Volumen", value: "\(Int(totalVolume)) kg", icon: "scalemass")
                        StatBadge(title: "Sätze", value: "\(totalSets)", icon: "number")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.backgroundCard)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                    
                    // Ratings
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Wie fühlst du dich?")
                            .font(.headline)
                        
                        HStack {
                            ForEach(1...5, id: \.self) { rating in
                                Button(action: { mood = rating }) {
                                    Image(systemName: rating <= mood ? "star.fill" : "star")
                                        .font(.title)
                                        .foregroundColor(rating <= mood ? .yellow : .gray.opacity(0.3))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        
                        Divider().padding(.vertical, 8)
                        
                        Text("Wie anstrengend war es? (RPE)")
                            .font(.headline)
                        
                        Picker("Intensität", selection: $intensity) {
                            Text("1 - Sehr leicht").tag(1)
                            Text("2 - Leicht").tag(2)
                            Text("3 - Mittel").tag(3)
                            Text("4 - Schwer").tag(4)
                            Text("5 - Maximum").tag(5)
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding()
                    .background(Color.backgroundCard)
                    .cornerRadius(16)
                    
                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notizen (Optional)")
                            .font(.headline)
                        TextEditor(text: $notes)
                            .frame(minHeight: 100)
                            .padding(4)
                            .background(Color.backgroundSecondary)
                            .cornerRadius(8)
                    }
                    .padding()
                    .background(Color.backgroundCard)
                    .cornerRadius(16)
                    
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        cancelWorkout()
                    }
                    .foregroundColor(.red)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        saveAndClose()
                    }
                    .bold()
                }
            }
            .onAppear {
                // Trigger animation
                showConfetti = true
                
                // Set endTime if not already set (it might be set by the calling view)
                if session.endTime == nil {
                    session.endTime = Date()
                }
            }
        }
    }
    
    private func saveAndClose() {
        session.moodRating = mood
        session.intensityRating = intensity
        session.notes = notes
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving session: \(error)")
        }
        
        // Let the caller know we're done so the fullScreenCover can be dismissed
        // In this architecture, we dismiss the sheet. The parent (WorkoutSessionView)
        // should observe the session's state or we dismiss the parent as well.
        // Easiest way: Post a notification or use a binding.
        NotificationCenter.default.post(name: NSNotification.Name("WorkoutFinished"), object: nil)
    }
    
    private func cancelWorkout() {
        modelContext.delete(session)
        do {
            try modelContext.save()
        } catch {
            print("Error deleting session: \(error)")
        }
        NotificationCenter.default.post(name: NSNotification.Name("WorkoutFinished"), object: nil)
    }
}

struct StatBadge: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.brand)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
