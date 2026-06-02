import SwiftUI
import SwiftData

struct FoodSearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let mealType: MealType
    
    @Query(sort: \FoodEntry.timestamp, order: .reverse) private var allFoodEntries: [FoodEntry]
    
    @State private var searchText = ""
    @State private var searchResults: [OFFProduct] = []
    @State private var isSearching = false
    
    // For navigation to form
    @State private var selectedProduct: OFFProduct?
    @State private var selectedEntry: FoodEntry?
    @State private var showForm = false
    
    private let apiService = FoodAPIService()
    
    private var recentFoods: [FoodEntry] {
        var uniqueNames = Set<String>()
        var result = [FoodEntry]()
        
        for entry in allFoodEntries {
            if !uniqueNames.contains(entry.name) {
                uniqueNames.insert(entry.name)
                result.append(entry)
            }
            if result.count >= 20 { break } // Limit to 20 recent items
        }
        
        // If searching locally
        if !searchText.isEmpty {
            return result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        return result
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(action: {
                        selectedProduct = nil
                        selectedEntry = nil
                        showForm = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.brand)
                            Text("Manuell hinzufügen")
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                if !searchText.isEmpty {
                    Section(header: Text("Datenbank-Suche (OpenFoodFacts)")) {
                        if isSearching {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else if searchResults.isEmpty {
                            Text("Keine Ergebnisse gefunden.")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(searchResults) { product in
                                Button(action: {
                                    selectedProduct = product
                                    showForm = true
                                }) {
                                    VStack(alignment: .leading) {
                                        Text(product.productName ?? "Unbekanntes Produkt")
                                            .font(.headline)
                                        if let nuts = product.nutriments, let kcal = nuts.energyKcal100g {
                                            Text("\(kcal, specifier: "%.0f") kcal pro 100g")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .foregroundColor(.primary)
                            }
                        }
                    }
                }
                
                Section(header: Text(searchText.isEmpty ? "Zuletzt gegessen" : "Lokale Treffer")) {
                    if recentFoods.isEmpty {
                        Text("Noch keine Einträge vorhanden.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(recentFoods) { entry in
                            Button(action: {
                                selectedEntry = entry
                                showForm = true
                            }) {
                                VStack(alignment: .leading) {
                                    Text(entry.name)
                                        .font(.headline)
                                    Text("\(entry.calories, specifier: "%.0f") kcal (\(entry.amountGrams, specifier: "%.0f")g)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }
            }
            .navigationTitle("\(mealType.rawValue) hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Lebensmittel suchen...")
            .onChange(of: searchText) { oldValue, newValue in
                Task {
                    await performSearch(query: newValue)
                }
            }
            .navigationDestination(isPresented: $showForm) {
                FoodEntryFormView(mealType: mealType, prefilledProduct: selectedProduct, prefilledEntry: selectedEntry)
            }
        }
    }
    
    private func performSearch(query: String) async {
        guard query.count >= 3 else {
            searchResults = []
            return
        }
        
        isSearching = true
        do {
            let results = try await apiService.searchProducts(query: query)
            // Optional: debounce this or handle race conditions
            if searchText == query {
                searchResults = results
            }
        } catch {
            print("Search failed: \(error)")
            if searchText == query {
                searchResults = []
            }
        }
        if searchText == query {
            isSearching = false
        }
    }
}
