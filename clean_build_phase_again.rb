require 'xcodeproj'

project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# Remove previous run script
existing_phase = target.shell_script_build_phases.find { |p| p.name == 'Force Modern Launch Screen' }
if existing_phase
    existing_phase.remove_from_project
end

# Ensure we use Storyboard
target.build_configurations.each do |config|
    config.build_settings['INFOPLIST_KEY_UILaunchStoryboardName'] = 'LaunchScreen'
    config.build_settings['CURRENT_PROJECT_VERSION'] = '4'
end

project.save
puts "Removed broken script and bumped version to 4"
