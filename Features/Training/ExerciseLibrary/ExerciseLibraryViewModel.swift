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
        .sorted { ex1, ex2 in
            if ex1.category != ex2.category {
                return ex1.category < ex2.category
            }
            return ex1.name.localizedCaseInsensitiveCompare(ex2.name) == .orderedAscending
        }
    }
}
