require 'xcodeproj'

project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

resources_build_phase = target.resources_build_phase
resources_build_phase.files.each do |build_file|
  if build_file.file_ref && build_file.file_ref.path == 'App/LaunchScreen.storyboard'
    build_file.remove_from_project
  elsif build_file.file_ref && build_file.file_ref.path == 'LaunchScreen.storyboard'
    build_file.remove_from_project
  end
end

project.save
puts "Successfully cleaned build phases."
