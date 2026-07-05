import SwiftUI
import SwiftData

struct MealDetailView: View {
    @Environment(\.modelContext) private var modelContext
    
    let mealType: MealType
    let dateString: String
    
    @Query private var allDailyLogs: [DailyLog]
    @Query(sort: \FoodEntry.timestamp, order: .reverse) private var allFoodEntries: [FoodEntry]
    
    @State private var showingFoodSearch = false
    @State private var showingSavedAlert = false
    @State private var savedFoodName = ""
    
    @State private var showingScanner = false
    @State private var scannedProduct: OFFProduct? = nil
    @State private var showingAddEntryFromScanner = false
    
    @State private var showingRecentEntryForm = false
    @State private var selectedRecentEntry: FoodEntry? = nil
    
    private var todayLog: DailyLog? {
        allDailyLogs.first { $0.dateString == dateString }
    }
    
    private var entries: [FoodEntry] {
        todayLog?.foodEntries?.filter { $0.mealType == mealType } ?? []
    }
    
    private var recentFoods: [FoodEntry] {
        var uniqueNames = Set<String>()
        var result = [FoodEntry]()
        
        for entry in allFoodEntries {
            guard entry.mealType == mealType else { continue }
            // Don't show foods that are already added today for this meal
            let alreadyAdded = entries.contains { $0.name == entry.name }
            if !alreadyAdded && !uniqueNames.contains(entry.name) {
                uniqueNames.insert(entry.name)
                result.append(entry)
            }
            if result.count >= 5 { break }
        }
        
        return result
    }
    
    private var totalCalories: Double {
        entries.reduce(0) { $0 + $1.calories }
    }
    
    private var totalProtein: Double {
        entries.reduce(0) { $0 + $1.proteinGrams }
    }
    
    private var totalCarbs: Double {
        entries.reduce(0) { $0 + $1.carbsGrams }
    }
    
    private var totalFat: Double {
        entries.reduce(0) { $0 + $1.fatGrams }
    }
    
    private var parsedDate: Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        formatter.timeZone = TimeZone.current
        return formatter.date(from: dateString) ?? Date()
    }
    
    var body: some View {
        List {
            Section(header: Text("Zusammenfassung")) {
                HStack {
                    Text("Kalorien")
                    Spacer()
                    Text("\(Int(totalCalories)) kcal")
                        .fontWeight(.bold)
                }
                HStack {
                    Text("Protein")
                    Spacer()
                    Text("\(String(format: "%.1f", totalProtein)) g")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Kohlenhydrate")
                    Spacer()
                    Text("\(String(format: "%.1f", totalCarbs)) g")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Fett")
                    Spacer()
                    Text("\(String(format: "%.1f", totalFat)) g")
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("Einträge")) {
                if entries.isEmpty {
                    Text("Noch keine Einträge für diese Mahlzeit.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(entries) { entry in
                        NavigationLink(destination: FoodEntryDetailView(entry: entry)) {
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
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteEntry(entry)
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                            .tint(.red)
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
                        Text("Lebensmittel suchen")
                            .foregroundColor(.primary)
                    }
                }
                
                Button(action: {
                    showingScanner = true
                }) {
                    HStack {
                        Image(systemName: "barcode.viewfinder")
                            .foregroundColor(.brand)
                        Text("Barcode scannen")
                            .foregroundColor(.primary)
                    }
                }
            }
            
            if !recentFoods.isEmpty {
                Section(header: Text("Zuletzt gegessen (Vorschläge)")) {
                    ForEach(recentFoods) { entry in
                        Button(action: {
                            selectedRecentEntry = entry
                            showingRecentEntryForm = true
                        }) {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(.brand)
                                    .font(.subheadline)
                                    .frame(width: 24)
                                    
                                VStack(alignment: .leading) {
                                    Text(entry.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    Text("\(Int(entry.amountGrams)) g")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text("\(Int(entry.calories)) kcal")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .navigationTitle(mealType.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingFoodSearch) {
            FoodSearchView(mealType: mealType) { savedName in
                showingFoodSearch = false
                savedFoodName = savedName
                showingSavedAlert = true
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showingScanner) {
            ZStack {
                BarcodeScannerView(onProductFound: { product in
                    showingScanner = false
                    scannedProduct = product
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showingAddEntryFromScanner = true
                    }
                })
                
                #if targetEnvironment(simulator)
                VStack {
                    Spacer()
                    Button(action: {
                        Task {
                            let service = FoodAPIService()
                            let product = try? await service.fetchProduct(barcode: "5449000000996")
                            DispatchQueue.main.async {
                                showingScanner = false
                                scannedProduct = product
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    showingAddEntryFromScanner = true
                                }
                            }
                        }
                    }) {
                        Text("Simulator Mock Scan")
                            .font(.headline)
                            .padding()
                            .background(Color.brand)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.bottom, 40)
                }
                #endif
            }
        }
        .sheet(item: $scannedProduct) { product in
            FoodEntryFormView(mealType: mealType, prefilledProduct: product, targetDate: parsedDate) { savedName in
                scannedProduct = nil
                savedFoodName = savedName
                showingSavedAlert = true
            }
            .presentationDetents([.large])
        }
        .sheet(item: $selectedRecentEntry) { entry in
            FoodEntryFormView(mealType: mealType, prefilledProduct: nil, prefilledEntry: entry, targetDate: parsedDate) { savedName in
                selectedRecentEntry = nil
                savedFoodName = savedName
                showingSavedAlert = true
            }
            .presentationDetents([.large])
        }
        .alert("Gespeichert", isPresented: $showingSavedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("\(savedFoodName) wurde hinzugefügt.")
        }
    }
    
    private func deleteEntry(_ entry: FoodEntry) {
        modelContext.delete(entry)
    }
}
