require 'xcodeproj'

project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# The main group corresponds to the folder "FitTrackPro" usually, let's find it.
main_group = project.main_group.children.find { |g| g.display_name == 'FitTrackPro' || g.path == 'FitTrackPro' }

unless main_group
    main_group = project.main_group
end

files = [
  'Features/Dashboard/DashboardView.swift',
  'Features/WeightTracker/WeightTrackerView.swift',
  'Features/WeightTracker/WeightEntryFormView.swift'
]

files.each do |file_path|
  file_ref = main_group.new_file(file_path)
  target.add_file_references([file_ref])
  puts "Added #{file_path}"
end

project.save
