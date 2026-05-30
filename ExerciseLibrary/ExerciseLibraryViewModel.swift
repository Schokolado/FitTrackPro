import SwiftUI
import SwiftData

@Observable
class ExerciseLibraryViewModel {
    var searchText: String = ""
    var selectedCategory: String? = nil
    
    // Filtering logic to be applied on the queried exercises in the view
    func filterExercises(_ exercises: [Exercise]) -> [Exercise] {
        exercises.filter { exercise in
            let matchesSearch = searchText.isEmpty || exercise.name.localizedCaseInsensitiveContains(searchText)
            let matchesCategory = selectedCategory == nil || exercise.category == selectedCategory
            return matchesSearch && matchesCategory
        }
        .sorted { $0.sortOrder < $1.sortOrder }
    }
}
