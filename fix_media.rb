require 'xcodeproj'
project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

project.files.select { |file| file.path && file.path.include?('MediaStorageService.swift') }.each do |file_ref|
  target.source_build_phase.files.select { |f| f.file_ref == file_ref }.each do |build_file|
    target.source_build_phase.files.delete(build_file)
  end
  file_ref.remove_from_project
end

group = project.main_group.find_subpath('Core/Services', true)
file_ref = group.new_reference('MediaStorageService.swift')
file_ref.set_path('MediaStorageService.swift') # Relative to Core/Services group
target.add_file_references([file_ref])
project.save
