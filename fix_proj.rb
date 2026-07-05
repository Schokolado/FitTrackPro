require 'xcodeproj'
project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# Remove broken references
target.source_build_phase.files.each do |build_file|
  if build_file.file_ref && build_file.file_ref.path == 'DashboardDragDrop.swift'
    build_file.file_ref.remove_from_project
  end
end

# Add correctly
features_group = project.main_group.find_subpath(File.join('FitTrackPro', 'Features', 'Dashboard'), true)
file_ref = features_group.new_reference('Features/Dashboard/DashboardDragDrop.swift')
target.source_build_phase.add_file_reference(file_ref)

project.save
