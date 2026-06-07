require 'xcodeproj'

project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# Remove previous run script
existing_phase = target.shell_script_build_phases.find { |p| p.name == 'Fix Info.plist Launch Screen' }
if existing_phase
    existing_phase.remove_from_project
end

# Ensure we aren't using the storyboard in build settings
target.build_configurations.each do |config|
    config.build_settings.delete('INFOPLIST_KEY_UILaunchStoryboardName')
end

# Add a new script phase
phase = target.new_shell_script_build_phase('Force Modern Launch Screen')
phase.shell_script = <<-SCRIPT
#!/bin/sh
INFOPLIST="${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH}"
echo "Forcing modern Launch Screen dict in $INFOPLIST"

# Remove any existing Launch Screen settings
/usr/libexec/PlistBuddy -c "Delete :UILaunchStoryboardName" "$INFOPLIST" || true
/usr/libexec/PlistBuddy -c "Delete :UILaunchScreen" "$INFOPLIST" || true

# Add the proper modern Launch Screen dictionary
/usr/libexec/PlistBuddy -c "Add :UILaunchScreen dict" "$INFOPLIST" || true
/usr/libexec/PlistBuddy -c "Add :UILaunchScreen:UIColorName string LaunchBackground" "$INFOPLIST" || true
/usr/libexec/PlistBuddy -c "Add :UILaunchScreen:UIImageName string LaunchLogoV3" "$INFOPLIST" || true
/usr/libexec/PlistBuddy -c "Add :UILaunchScreen:UIImageRespectsSafeAreaInsets bool false" "$INFOPLIST" || true

# Bump version again to clear simulator cache!
# Note: Changing CFBundleVersion here only affects the built app, not the source project.
# But it's enough to bust the simulator cache!
old_ver=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFOPLIST" || echo "1")
new_ver=$((old_ver + 1))
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $new_ver" "$INFOPLIST" || true
SCRIPT

project.save
puts "Added Run Script Phase to force modern UILaunchScreen dictionary"
