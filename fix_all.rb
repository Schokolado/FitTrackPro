require 'xcodeproj'
project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

def add_file(project, target, file_path)
  group_path = File.dirname(file_path)
  file_name = File.basename(file_path)
  
  group = project.main_group.find_subpath(group_path, true)
  group.set_path(group_path) if group.path.nil?
  
  file_ref = group.files.find { |f| f.path == file_name }
  if file_ref.nil?
    file_ref = group.new_file(file_name)
  end
  
  unless target.source_build_phase.files.any? { |bf| bf.file_ref == file_ref }
    target.source_build_phase.add_file_reference(file_ref)
  end
end

add_file(project, target, 'Features/WaterTracker/WaterTrackerView.swift')
add_file(project, target, 'Features/WaterTracker/WaterEntryFormView.swift')
add_file(project, target, 'Features/SleepTracker/SleepTrackerView.swift')
add_file(project, target, 'Features/SleepTracker/SleepEntryFormView.swift')
add_file(project, target, 'Features/Recovery/RecoveryCalculator.swift')
add_file(project, target, 'Features/Recovery/RecoveryView.swift')

project.save
