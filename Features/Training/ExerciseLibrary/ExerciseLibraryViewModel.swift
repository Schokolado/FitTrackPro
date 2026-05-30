import SwiftUI
import SwiftData

@Observable
class ExerciseLibraryViewModel {
    var searchText: String = ""
    var selectedCategory: String? = nil
    
    // MARK: - Filtering

    /// Applies search text and category filter to the provided exercises.
    /// Note: archived exercises are already excluded by the `@Query` in `ExerciseLibraryView`.
    func filterExercises(_ exercises: [Exercise]) -> [Exercise] {
        exercises
            .filter { !$0.isArchived }
            .filter { exercise in
                let matchesSearch = searchText.isEmpty
                    || exercise.name.localizedCaseInsensitiveContains(searchText)
                let matchesCategory = selectedCategory == nil
                    || exercise.category == selectedCategory
                return matchesSearch && matchesCategory
            }
            .sorted { $0.sortOrder < $1.sortOrder }
    }
}
