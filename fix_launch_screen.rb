require 'xcodeproj'

project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

target.build_configurations.each do |config|
    config.build_settings.delete('INFOPLIST_KEY_UILaunchStoryboardName')
    config.build_settings['INFOPLIST_KEY_UILaunchScreen_Generation'] = 'YES'
    config.build_settings['INFOPLIST_KEY_UILaunchScreen_UIColorName'] = 'LaunchBackground'
    config.build_settings['INFOPLIST_KEY_UILaunchScreen_UIImageName'] = 'LaunchLogo'
end

project.save
puts "Successfully updated LaunchScreen build settings."
