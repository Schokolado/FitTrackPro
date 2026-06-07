require 'xcodeproj'

project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

group = project.main_group.find_subpath('FitTrackPro/App', true)
file_ref = group.files.find { |f| f.path == 'LaunchScreen.storyboard' }
unless file_ref
  file_ref = group.new_reference('LaunchScreen.storyboard')
end

resources_phase = target.resources_build_phase
unless resources_phase.files_references.include?(file_ref)
  resources_phase.add_file_reference(file_ref)
  puts "Added LaunchScreen.storyboard to resources phase."
end

target.build_configurations.each do |config|
    config.build_settings['INFOPLIST_KEY_UILaunchStoryboardName'] = 'LaunchScreen'
    # Delete old dict-based generation keys to prevent conflicts
    config.build_settings.delete('INFOPLIST_KEY_UILaunchScreen_Generation')
    config.build_settings.delete('INFOPLIST_KEY_UILaunchScreen_UIImageName')
    config.build_settings.delete('INFOPLIST_KEY_UILaunchScreen_UIColorName')
end

project.save
puts "Successfully configured LaunchScreen.storyboard"
