import SwiftUI
import SwiftData

struct MealDetailView: View {
    @Environment(\.modelContext) private var modelContext
    
    let mealType: MealType
    let dateString: String
    
    @Query private var allDailyLogs: [DailyLog]
    
    @State private var showingFoodSearch = false
    @State private var showingSavedAlert = false
    @State private var savedFoodName = ""
    
    @State private var showingScanner = false
    @State private var scannedProduct: OFFProduct? = nil
    @State private var showingAddEntryFromScanner = false
    
    private var todayLog: DailyLog? {
        allDailyLogs.first { $0.dateString == dateString }
    }
    
    private var entries: [FoodEntry] {
        todayLog?.foodEntries?.filter { $0.mealType == mealType } ?? []
    }
    
    private var totalCalories: Double {
        entries.reduce(0) { $0 + $1.calories }
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
                        Text("Lebensmittel hinzufügen")
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
        .sheet(isPresented: $showingAddEntryFromScanner) {
            FoodEntryFormView(mealType: mealType, prefilledProduct: scannedProduct, targetDate: parsedDate) { savedName in
                showingAddEntryFromScanner = false
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
