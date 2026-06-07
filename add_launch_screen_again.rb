require 'xcodeproj'

project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

group = project.main_group.find_subpath('FitTrackPro/App', true)
file_ref = group.files.find { |f| f.path == 'LaunchScreen.storyboard' }

unless file_ref
    file_ref = group.new_file('LaunchScreen.storyboard')
end

# Add to resources build phase
resources_phase = target.resources_build_phase
unless resources_phase.files_references.include?(file_ref)
    build_file = resources_phase.add_file_reference(file_ref)
end

project.save
puts "Added LaunchScreen.storyboard to project"
