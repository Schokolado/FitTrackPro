require 'xcodeproj'
project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# Add Feature/WaterTracker
group_water = project.main_group.find_subpath('Features/WaterTracker', true)
file1 = group_water.new_file('WaterTrackerView.swift')
file2 = group_water.new_file('WaterEntryFormView.swift')

# Add to Dashboard
group_dashboard = project.main_group.find_subpath('Features/Dashboard', true)
file3 = group_dashboard.new_file('WaterTrackerCard.swift')

target.source_build_phase.add_file_reference(file1)
target.source_build_phase.add_file_reference(file2)
target.source_build_phase.add_file_reference(file3)

project.save
