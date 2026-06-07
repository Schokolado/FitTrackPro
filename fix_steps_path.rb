require 'xcodeproj'

project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# Find the Steps group
features_group = project.main_group.find_subpath('Features', false)
steps_group = features_group.find_subpath('Steps', false)

if steps_group
  steps_group.set_path('Steps')
  steps_group.set_source_tree('<group>')
  
  steps_group.files.each do |file_ref|
    if file_ref.name == 'StepTrackerView.swift' || file_ref.name == 'StepEntryFormView.swift'
      # Re-set path relative to group
      file_ref.set_path(file_ref.name)
    end
  end
end

project.save
puts "Fixed paths for Steps group."
