import SwiftUI
import SwiftData

struct ExerciseHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    let exercise: Exercise
    
    @Query private var pastSets: [WorkoutSet]
    
    init(exercise: Exercise) {
        self.exercise = exercise
        let exerciseId = exercise.id
        
        _pastSets = Query(
            filter: #Predicate<WorkoutSet> { set in
                set.exercise?.id == exerciseId && set.isCompleted == true
            },
            sort: \.timestamp, order: .reverse
        )
    }
    
    // Gruppiere die Sätze nach Datum (ohne Uhrzeit), um sie chronologisch anzuzeigen
    private var groupedSessions: [(Date, [WorkoutSet])] {
        var dict: [Date: [WorkoutSet]] = [:]
        let calendar = Calendar.current
        
        for set in pastSets {
            let startOfDay = calendar.startOfDay(for: set.timestamp)
            if dict[startOfDay] == nil {
                dict[startOfDay] = []
            }
            dict[startOfDay]?.append(set)
        }
        
        // Sortiere die Gruppen nach Datum (neueste zuerst)
        let sortedKeys = dict.keys.sorted(by: >)
        return sortedKeys.map { ($0, dict[$0]!.sorted(by: { $0.setNumber < $1.setNumber })) }
    }
    
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }()
    
    var body: some View {
        List {
            if groupedSessions.isEmpty {
                ContentUnavailableView("Keine Historie", systemImage: "clock.badge.xmark", description: Text("Du hast diese Übung bisher noch nicht abgeschlossen."))
            } else {
                ForEach(groupedSessions, id: \.0) { date, sets in
                    Section(header: Text(dateFormatter.string(from: date))) {
                        ForEach(sets) { set in
                            HStack {
                                Text("Satz \(set.setNumber)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .frame(width: 60, alignment: .leading)
                                
                                Spacer()
                                
                                let isCardio = exercise.category.lowercased() == "cardio"
                                
                                Text(isCardio ? "Level \(Int(set.actualWeight))" : "\(set.actualWeight, specifier: "%.1f") kg")
                                    .font(.headline)
                                    .frame(width: 80, alignment: .trailing)
                                
                                Text(isCardio ? "\(set.actualReps) Min" : "× \(set.actualReps)")
                                    .font(.headline)
                                    .frame(width: 60, alignment: .trailing)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("\(exercise.name) Historie")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Schließen") {
                    dismiss()
                }
            }
        }
    }
}
