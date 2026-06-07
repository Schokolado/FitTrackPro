require 'xcodeproj'

project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

target.build_configurations.each do |config|
    config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
    config.build_settings.delete('INFOPLIST_FILE')
    
    # Disable UILaunchScreen dict generation which overrides storyboard!
    config.build_settings['INFOPLIST_KEY_UILaunchScreen_Generation'] = 'NO'
    
    # Set Storyboard
    config.build_settings['INFOPLIST_KEY_UILaunchStoryboardName'] = 'LaunchScreen'
    
    # Clean up my previous mistakes
    config.build_settings.delete('INFOPLIST_KEY_UILaunchScreen_UIColorName')
    config.build_settings.delete('INFOPLIST_KEY_UILaunchScreen_UIImageName')
end

project.save
puts "Fixed launch screen conflict in build settings"
