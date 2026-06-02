import SwiftUI
import SwiftData

struct MealDetailView: View {
    @Environment(\.modelContext) private var modelContext
    
    let mealType: MealType
    let dateString: String
    
    @Query private var allDailyLogs: [DailyLog]
    
    @State private var showingFoodSearch = false
    
    private var todayLog: DailyLog? {
        allDailyLogs.first { $0.dateString == dateString }
    }
    
    private var entries: [FoodEntry] {
        todayLog?.foodEntries?.filter { $0.mealType == mealType } ?? []
    }
    
    private var totalCalories: Double {
        entries.reduce(0) { $0 + $1.calories }
    }
    
    var body: some View {
        List {
            Section(header: Text("Zusammenfassung")) {
                HStack {
                    Text("Gesamtkalorien")
                    Spacer()
                    Text("\(Int(totalCalories)) kcal")
                        .fontWeight(.bold)
                }
            }
            
            Section(header: Text("Einträge")) {
                if entries.isEmpty {
                    Text("Noch keine Einträge für diese Mahlzeit.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(entries) { entry in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(entry.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("\(Int(entry.amountGrams)) g")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("\(Int(entry.calories)) kcal")
                                .font(.subheadline)
                                .fontWeight(.bold)
                        }
                        .padding(.vertical, 4)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteEntry(entry)
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            
            Section {
                Button(action: {
                    showingFoodSearch = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.brand)
                        Text("Lebensmittel hinzufügen")
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .navigationTitle(mealType.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingFoodSearch) {
            FoodSearchView(mealType: mealType)
                .presentationDetents([.large])
        }
    }
    
    private func deleteEntry(_ entry: FoodEntry) {
        modelContext.delete(entry)
    }
}
