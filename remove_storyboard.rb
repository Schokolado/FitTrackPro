require 'xcodeproj'

project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# Remove from resources phase
resources_phase = target.resources_build_phase
resources_phase.files.each do |build_file|
    if build_file.file_ref && build_file.file_ref.name == 'LaunchScreen.storyboard'
        build_file.remove_from_project
    end
end

# Remove from main group or any group
project.main_group.recursive_children.each do |child|
    if child.name == 'LaunchScreen.storyboard' || child.path == 'LaunchScreen.storyboard'
        child.remove_from_project
    end
end

# Restore Info.plist launch screen generation settings
target.build_configurations.each do |config|
    config.build_settings.delete('INFOPLIST_KEY_UILaunchStoryboardName')
    config.build_settings['INFOPLIST_KEY_UILaunchScreen_Generation'] = 'YES'
end

project.save
puts "Removed LaunchScreen.storyboard"
