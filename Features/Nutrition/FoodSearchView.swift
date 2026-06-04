import SwiftUI
import SwiftData

struct FoodSearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let mealType: MealType?
    var onSave: ((String) -> Void)? = nil
    
    @Query(sort: \FoodEntry.timestamp, order: .reverse) private var allFoodEntries: [FoodEntry]
    
    @State private var searchText = ""
    @State private var searchResults: [OFFProduct] = []
    @State private var isSearching = false
    @State private var hasSearchedOnline = false
    @State private var lastSearchTime: Date = Date.distantPast
    @State private var showRateLimitAlert = false
    
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
            VStack(spacing: 0) {
                // Eigene Suchleiste, um die fehlerhaften iOS-Transitions zu umgehen
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Lebensmittel suchen...", text: $searchText)
                        .submitLabel(.search)
                        .onSubmit {
                            hasSearchedOnline = false
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(.systemGray5))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 8)
                
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
                
                if !searchText.isEmpty && hasSearchedOnline {
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
                                    Task {
                                        isSearching = true
                                        if let code = product.code, let fullProduct = try? await apiService.fetchProduct(barcode: code) {
                                            selectedProduct = fullProduct
                                        } else {
                                            selectedProduct = product
                                        }
                                        isSearching = false
                                        showForm = true
                                    }
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
                    if recentFoods.isEmpty && searchText.isEmpty {
                        Text("Noch keine Einträge vorhanden.")
                            .foregroundColor(.secondary)
                    } else if recentFoods.isEmpty {
                        Text("Keine lokalen Treffer.")
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
                    
                    if !searchText.isEmpty && !hasSearchedOnline {
                        Button(action: {
                            Task {
                                await triggerOnlineSearch(query: searchText)
                            }
                        }) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                Text("Weitere Ergebnisse online suchen...")
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle(mealType?.rawValue.appending(" hinzufügen") ?? "Mahlzeit hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
            .onChange(of: searchText) { oldValue, newValue in
                if newValue.isEmpty {
                    hasSearchedOnline = false
                    searchResults = []
                }
            }
            .alert("Bitte kurz warten", isPresented: $showRateLimitAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Um die Datenbank nicht zu überlasten, warte bitte ein paar Sekunden zwischen den Suchanfragen.")
            }
            .navigationDestination(isPresented: $showForm) {
                FoodEntryFormView(mealType: mealType, prefilledProduct: selectedProduct, prefilledEntry: selectedEntry) { savedName in
                    dismiss()
                    onSave?(savedName)
                }
            }
            } // close VStack
        } // close NavigationStack
    } // close body
    
    private func triggerOnlineSearch(query: String) async {
        let now = Date()
        // 5 seconds rate limit between online searches
        if now.timeIntervalSince(lastSearchTime) < 5 {
            showRateLimitAlert = true
            return
        }
        
        lastSearchTime = now
        hasSearchedOnline = true
        await performSearch(query: query)
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
