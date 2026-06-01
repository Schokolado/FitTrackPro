require 'xcodeproj'
project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# Remove bad reference
bad_refs = project.files.select { |f| f.path == 'MediaStorageService.swift' }
bad_refs.each do |ref|
  ref.build_files.each { |bf| bf.remove_from_project }
  ref.remove_from_project
end

# Add proper reference
group = project.main_group.find_subpath('FitTrackPro/Core/Services', true)
# Use real path
file_path = 'Core/Services/MediaStorageService.swift'
file_ref = group.new_file(file_path)
target.add_file_references([file_ref])

project.save
