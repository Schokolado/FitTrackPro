require 'xcodeproj'

project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# Root-level files that are duplicates of files already in the Features/Core subdirectories.
# These should be REMOVED from the build target (and optionally from the project entirely).
root_duplicates = %w[
  PlanDetailView.swift
  PlanExerciseRowView.swift
  TrainingPlansView.swift
  ExerciseSelectionView.swift
  ExerciseHistoryView.swift
  WorkoutSessionView.swift
  WorkoutSummaryView.swift
  WorkoutSetRowView.swift
  WorkoutSessionViewModel.swift
  SeedDataService.swift
  NotificationService.swift
]

removed = 0
root_duplicates.each do |filename|
  # Find file references in the main group (root level)
  project.main_group.children.select { |child|
    child.is_a?(Xcodeproj::Project::Object::PBXFileReference) &&
    child.path == filename
  }.each do |file_ref|
    # Remove from Sources build phase
    target.source_build_phase.files.select { |f|
      f.file_ref == file_ref
    }.each do |build_file|
      target.source_build_phase.files.delete(build_file)
      puts "  Removed from target: #{filename}"
      removed += 1
    end
    # Remove from project group
    file_ref.remove_from_project
    puts "  Removed from project: #{filename}"
  end
end

project.save
puts "\nDone – removed #{removed} duplicate build references."
