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
project.save
