require 'xcodeproj'

project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

target.build_configurations.each do |config|
    config.build_settings['INFOPLIST_KEY_UILaunchStoryboardName'] = 'LaunchScreen'
    config.build_settings['ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOLS'] = 'YES'
end

project.save
puts "Added INFOPLIST_KEY_UILaunchStoryboardName"
