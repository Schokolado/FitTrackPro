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
    @State private var showingScanner = false
    
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
    
        @State private var currentPage = 1
    @State private var hasMoreResults = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    searchBar
                    
                    List {
                        manualAddSection
                        
                        if !searchText.isEmpty && hasSearchedOnline {
                            onlineSearchSection
                        }
                        
                        localSearchSection
                    }
                    .scrollContentBackground(.hidden)
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
            .toolbarBackground(Color(.systemGroupedBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onChange(of: searchText) { oldValue, newValue in
                if newValue.isEmpty {
                    hasSearchedOnline = false
                    searchResults = []
                    currentPage = 1
                    hasMoreResults = false
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
            .sheet(isPresented: $showingScanner) {
                ZStack {
                    BarcodeScannerView(onProductFound: { product in
                        showingScanner = false
                        selectedProduct = product
                        selectedEntry = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showForm = true
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
                                    selectedProduct = product
                                    selectedEntry = nil
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        showForm = true
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
        }
    }
    
    private var searchBar: some View {
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
    }
    
    private var manualAddSection: some View {
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
    
    private var onlineSearchSection: some View {
        Section(header: Text("Datenbank-Suche (OpenFoodFacts)")) {
            if searchResults.isEmpty {
                if isSearching {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else {
                    Text("Keine Ergebnisse gefunden.")
                        .foregroundColor(.secondary)
                }
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
                
                if isSearching {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if hasMoreResults {
                    Button("Weitere laden...") {
                        Task {
                            await triggerOnlineSearch(query: searchText, page: currentPage + 1)
                        }
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    private var localSearchSection: some View {
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
                        await triggerOnlineSearch(query: searchText, page: 1)
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
    
    private func triggerOnlineSearch(query: String, page: Int) async {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastSearchTime)
        
        // 3 seconds internal timer between online searches to prevent blocking
        if elapsed < 3 {
            isSearching = true
            let remaining = 3.0 - elapsed
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
        }
        
        lastSearchTime = Date()
        hasSearchedOnline = true
        await performSearch(query: query, page: page)
    }
    
    private func performSearch(query: String, page: Int) async {
        guard query.count >= 3 else {
            searchResults = []
            return
        }
        
        if page == 1 {
            searchResults = []
        }
        isSearching = true
        do {
            let results = try await apiService.searchProducts(query: query, page: page)
            if searchText == query {
                if page == 1 {
                    searchResults = results
                } else {
                    searchResults.append(contentsOf: results)
                }
                currentPage = page
                hasMoreResults = results.count >= 20
            }
        } catch {
            print("Search failed: \(error)")
            if searchText == query && page == 1 {
                searchResults = []
            }
        }
        if searchText == query {
            isSearching = false
        }
    }
}