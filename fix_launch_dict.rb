require 'xcodeproj'

project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

target.build_configurations.each do |config|
    config.build_settings['INFOPLIST_KEY_UILaunchScreen_Generation'] = 'YES'
    config.build_settings['INFOPLIST_KEY_UILaunchScreen_UIColorName'] = 'LaunchBackground'
    config.build_settings['INFOPLIST_KEY_UILaunchScreen_UIImageName'] = 'LaunchLogoV3'
    # Delete the storyboard setting to avoid conflicts
    config.build_settings.delete('INFOPLIST_KEY_UILaunchStoryboardName')
end

project.save
puts "Added UILaunchScreen dict keys to build settings"
