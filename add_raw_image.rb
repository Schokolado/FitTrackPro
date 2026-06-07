require 'xcodeproj'

project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

group = project.main_group.find_subpath('FitTrackPro/Resources', true)
file_ref = group.find_file_by_path('LaunchLogoV3_raw.png')

unless file_ref
    file_ref = group.new_file('LaunchLogoV3_raw.png')
    target.resources_build_phase.add_file_reference(file_ref)
end

project.save
puts "Added LaunchLogoV3_raw.png to resources"
