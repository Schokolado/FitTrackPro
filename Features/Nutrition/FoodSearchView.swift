import SwiftUI
import SwiftData

struct FoodSearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let mealType: MealType?
    var targetDate: Date = Date()
    var onSave: ((String) -> Void)? = nil
    var onIngredientSelected: ((String, Double, Double, Double, Double, Double) -> Void)? = nil
    
    @Query(sort: \FoodEntry.timestamp, order: .reverse) private var allFoodEntries: [FoodEntry]
    @Query(sort: \SavedFood.createdAt, order: .reverse) private var savedFoods: [SavedFood]
    @Query(sort: \Recipe.createdAt, order: .reverse) private var recipes: [Recipe]
    
    @State private var searchText = ""
    @State private var searchResults: [OFFProduct] = []
    @State private var isSearching = false
    @State private var showingScanner = false
    @State private var hasMoreResults = false
    @State private var showRateLimitAlert = false
    @State private var showAmountAlert = false
    @State private var ingredientAmount: Double = 100.0
    @State private var pendingIngredient: (name: String, cal: Double, pro: Double, carb: Double, fat: Double)?
    @State private var hasSearchedOnline = false
    @State private var lastSearchTime: Date = Date.distantPast
    
    // For navigation to form
    @State private var selectedProduct: OFFProduct?
    @State private var selectedEntry: FoodEntry?
    @State private var showForm = false
    
    private let apiService = FoodAPIService()
    
    private var recentFoods: [FoodEntry] {
        var uniqueNames = Set<String>()
        var result = [FoodEntry]()
        let isSearching = !searchText.isEmpty
        
        for entry in allFoodEntries {
            if isSearching {
                if !entry.name.localizedCaseInsensitiveContains(searchText) { continue }
            } else if let targetType = mealType {
                if entry.mealType != targetType { continue }
            }
            
            if !uniqueNames.contains(entry.name) {
                uniqueNames.insert(entry.name)
                result.append(entry)
            }
            if result.count >= 20 { break } // Limit to 20 recent items
        }
        
        return result
    }
    
        @State private var currentPage = 1


    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    searchBar
                    
                    List {
                        if searchText.isEmpty {
                            localSearchSection
                            savedItemsSection
                            manualAddSection
                        } else {
                            manualAddSection
                            
                            if hasSearchedOnline {
                                onlineSearchSection
                            }
                            
                            savedItemsSection
                            localSearchSection
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle(mealType?.rawValue.appending(" hinzufügen") ?? "Mahlzeit hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingScanner = true
                    }) {
                        Image(systemName: "barcode.viewfinder")
                    }
                }
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
            .alert("Menge eingeben (g/ml)", isPresented: $showAmountAlert) {
                TextField("Menge", value: $ingredientAmount, format: .number)
                    .keyboardType(.decimalPad)
                Button("Abbrechen", role: .cancel) { }
                Button("Hinzufügen") {
                    if let pending = pendingIngredient, let onSelected = onIngredientSelected {
                        onSelected(pending.name, pending.cal, pending.pro, pending.carb, pending.fat, ingredientAmount)
                        dismiss()
                    }
                }
            }
            .navigationDestination(isPresented: $showForm) {
                if let entry = selectedEntry {
                    FoodEntryFormView(mealType: mealType, prefilledEntry: entry, targetDate: targetDate) { savedName in
                        onSave?(savedName)
                        dismiss()
                    }
                } else if let product = selectedProduct {
                    FoodEntryFormView(mealType: mealType, prefilledProduct: product, targetDate: targetDate) { savedName in
                        onSave?(savedName)
                        dismiss()
                    }
                } else {
                    FoodEntryFormView(mealType: mealType, targetDate: targetDate) { savedName in
                        onSave?(savedName)
                        dismiss()
                    }
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { showForm && selectedProduct == nil && selectedEntry == nil },
                set: { if !$0 { showForm = false } }
            )) {
                if let onIngredientSelected = onIngredientSelected {
                    FoodEntryFormView(mealType: .snack, prefilledProduct: nil, prefilledEntry: nil) { savedName in }
                } else {
                    FoodEntryFormView(mealType: mealType, prefilledProduct: nil, prefilledEntry: nil) { savedName in
                        showForm = false
                        dismiss()
                        onSave?(savedName)
                    }
                }
            }
            .sheet(isPresented: $showingScanner) {
                BarcodeScannerView(
                    onProductFound: { product in
                        showingScanner = false
                        if let product = product {
                            selectedProduct = product
                            showForm = true
                        }
                    },
                    onSavedFoodFound: { localFood in
                        showingScanner = false
                        let tempEntry = FoodEntry(name: localFood.name, barcode: localFood.barcode, calories: localFood.caloriesPer100g, proteinGrams: localFood.proteinPer100g, carbsGrams: localFood.carbsPer100g, fatGrams: localFood.fatPer100g)
                        tempEntry.amountGrams = 100
                        selectedEntry = tempEntry
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showForm = true
                        }
                    }
                )
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
                    Text("Eigene Mahlzeit/Lebensmittel erstellen")
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
                            if onIngredientSelected != nil {
                                let p = selectedProduct ?? product
                                let name = p.productName ?? "Unbekanntes Produkt"
                                let cal = p.nutriments?.energyKcal100g ?? 0
                                let pro = p.nutriments?.proteins100g ?? 0
                                let carb = p.nutriments?.carbohydrates100g ?? 0
                                let fat = p.nutriments?.fat100g ?? 0
                                pendingIngredient = (name, cal, pro, carb, fat)
                                ingredientAmount = 100.0
                                showAmountAlert = true
                            } else {
                                showForm = true
                            }
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
    
    private var savedItemsSection: some View {
        Group {
            let filteredFoods = searchText.isEmpty ? savedFoods : savedFoods.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            let filteredRecipes = searchText.isEmpty ? recipes : recipes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            
            if !filteredFoods.isEmpty {
                Section(header: Text("Eigene Lebensmittel")) {
                    ForEach(filteredFoods.prefix(6)) { food in
                        Button(action: {
                            if onIngredientSelected != nil {
                                pendingIngredient = (food.name, food.caloriesPer100g, food.proteinPer100g, food.carbsPer100g, food.fatPer100g)
                                ingredientAmount = 100.0
                                showAmountAlert = true
                            } else {
                                // Create a temporary FoodEntry from SavedFood to populate the form
                                let tempEntry = FoodEntry(name: food.name, barcode: food.barcode, calories: food.caloriesPer100g, proteinGrams: food.proteinPer100g, carbsGrams: food.carbsPer100g, fatGrams: food.fatPer100g)
                                tempEntry.amountGrams = 100 // Default reference
                                selectedEntry = tempEntry
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    showForm = true
                                }
                            }
                        }) {
                            VStack(alignment: .leading) {
                                Text(food.name)
                                    .font(.headline)
                                Text("\(food.caloriesPer100g, specifier: "%.0f") kcal / 100g")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .foregroundColor(.primary)
                    }
                    
                    if filteredFoods.count > 6 {
                        NavigationLink(destination: SavedFoodListView(foods: filteredFoods, onIngredientSelected: onIngredientSelected, onFoodSelected: { tempEntry in
                            selectedEntry = tempEntry
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                showForm = true
                            }
                        })) {
                            Text("Alle \(filteredFoods.count) Ergebnisse anzeigen...")
                                .foregroundColor(.brand)
                        }
                    }
                }
            }
            
            if !filteredRecipes.isEmpty {
                Section(header: Text("Meine Rezepte")) {
                    ForEach(filteredRecipes) { recipe in
                        Button(action: {
                            if onIngredientSelected != nil {
                                pendingIngredient = (recipe.name, recipe.totalCalories, recipe.totalProtein, recipe.totalCarbs, recipe.totalFat)
                                ingredientAmount = recipe.totalGrams > 0 ? recipe.totalGrams : 100.0
                                showAmountAlert = true
                            } else {
                                let tempEntry = FoodEntry(name: recipe.name, calories: recipe.totalCalories, proteinGrams: recipe.totalProtein, carbsGrams: recipe.totalCarbs, fatGrams: recipe.totalFat)
                                tempEntry.amountGrams = recipe.totalGrams
                                tempEntry.recipeId = recipe.id
                                
                                // Create notes with ingredients
                                var ingredientsText = ""
                                if let ingredients = recipe.ingredients {
                                    let names = ingredients.map { ing -> String in
                                        let amount = Int(ing.amountGrams)
                                        return "\(amount)g \(ing.name)"
                                    }
                                    ingredientsText = names.joined(separator: ", ")
                                }
                                tempEntry.recipeNote = ingredientsText
                                
                                selectedEntry = tempEntry
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    showForm = true
                                }
                            }
                        }) {
                            VStack(alignment: .leading) {
                                Text(recipe.name)
                                    .font(.headline)
                                Text("\(recipe.totalCalories, specifier: "%.0f") kcal | \(recipe.portions, specifier: "%.1f") Portion(en)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
        }
    }
    
    private var localSearchSection: some View {
        let headerText = searchText.isEmpty ? (mealType != nil ? "Zuletzt als \(mealType!.rawValue) gegessen" : "Zuletzt gegessen") : "Lokale Treffer"
        return Section(header: Text(headerText)) {
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

struct SavedFoodListView: View {
    var foods: [SavedFood]
    var onIngredientSelected: ((String, Double, Double, Double, Double, Double) -> Void)?
    var onFoodSelected: ((FoodEntry) -> Void)?
    
    @State private var showAmountAlert = false
    @State private var ingredientAmount: Double = 100.0
    @State private var pendingIngredient: (name: String, cal: Double, pro: Double, carb: Double, fat: Double)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(foods) { food in
                Button(action: {
                    if onIngredientSelected != nil {
                        pendingIngredient = (food.name, food.caloriesPer100g, food.proteinPer100g, food.carbsPer100g, food.fatPer100g)
                        ingredientAmount = 100.0
                        showAmountAlert = true
                    } else {
                        let tempEntry = FoodEntry(name: food.name, barcode: food.barcode, calories: food.caloriesPer100g, proteinGrams: food.proteinPer100g, carbsGrams: food.carbsPer100g, fatGrams: food.fatPer100g)
                        tempEntry.amountGrams = 100
                        onFoodSelected?(tempEntry)
                        dismiss()
                    }
                }) {
                    VStack(alignment: .leading) {
                        Text(food.name)
                            .font(.headline)
                        Text("\(food.caloriesPer100g, specifier: "%.0f") kcal / 100g")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .foregroundColor(.primary)
            }
        }
        .navigationTitle("Gespeicherte Lebensmittel")
        .alert("Menge angeben", isPresented: $showAmountAlert) {
            TextField("g/ml", value: $ingredientAmount, format: .number)
                .keyboardType(.decimalPad)
            Button("Abbrechen", role: .cancel) { }
            Button("Hinzufügen") {
                if let pending = pendingIngredient, let onSelected = onIngredientSelected {
                    onSelected(pending.name, pending.cal, pending.pro, pending.carb, pending.fat, ingredientAmount)
                    dismiss()
                }
            }
        } message: {
            Text("Wie viel \(pendingIngredient?.name ?? "davon") möchtest du verwenden?")
        }
    }
}