require 'xcodeproj'

project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

target.build_configurations.each do |config|
    config.build_settings.delete('INFOPLIST_KEY_UILaunchScreen_Generation')
    # Optional: We could set UILaunchStoryboardName if we had a storyboard, but we are using UILaunchScreen dict
end

project.save
puts "Fixed LaunchScreen settings"
