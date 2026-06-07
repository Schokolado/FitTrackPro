require 'xcodeproj'

project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

target.build_configurations.each do |config|
    config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
    config.build_settings.delete('INFOPLIST_FILE')
    
    # Base plist info
    config.build_settings['INFOPLIST_KEY_UIApplicationSceneManifest_Generation'] = 'YES'
    config.build_settings['INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents'] = 'YES'
    config.build_settings['INFOPLIST_KEY_LSRequiresIPhoneOS'] = 'YES'
    
    # Launch Screen Storyboard
    config.build_settings['INFOPLIST_KEY_UILaunchStoryboardName'] = 'LaunchScreen'
    
    # Remove dictionary keys if they exist
    config.build_settings.delete('INFOPLIST_KEY_UILaunchScreen_Generation')
    config.build_settings.delete('INFOPLIST_KEY_UILaunchScreen_UIColorName')
    config.build_settings.delete('INFOPLIST_KEY_UILaunchScreen_UIImageName')
end

project.save
puts "Set GENERATE_INFOPLIST_FILE=YES and UILaunchStoryboardName"
