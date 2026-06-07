require 'xcodeproj'

project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# Add the file to the project
file_path = 'App/LaunchScreen.storyboard'
group = project.main_group.find_subpath('FitTrackPro/App', true)
file_reference = group.new_reference(file_path)

# Add it to the Resources build phase
resources_build_phase = target.resources_build_phase
resources_build_phase.add_file_reference(file_reference)

# Update build settings to use this storyboard
target.build_configurations.each do |config|
    config.build_settings.delete('INFOPLIST_KEY_UILaunchScreen_Generation')
    config.build_settings['INFOPLIST_KEY_UILaunchStoryboardName'] = 'LaunchScreen'
end

project.save
puts "Successfully added LaunchScreen.storyboard to project."
