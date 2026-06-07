require 'xcodeproj'

project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# Check if script already exists
existing_phase = target.shell_script_build_phases.find { |p| p.name == 'Fix Info.plist Launch Screen' }
if existing_phase
    existing_phase.remove_from_project
end

# Add a new script phase
phase = target.new_shell_script_build_phase('Fix Info.plist Launch Screen')
phase.shell_script = <<-SCRIPT
#!/bin/sh
INFOPLIST="${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH}"
echo "Fixing Launch Screen in $INFOPLIST"
/usr/libexec/PlistBuddy -c "Delete :UILaunchScreen" "$INFOPLIST" || true
/usr/libexec/PlistBuddy -c "Add :UILaunchStoryboardName string LaunchScreen" "$INFOPLIST" || true
SCRIPT

# Move the phase BEFORE the "Code Signing" phase if possible (Xcodeproj adds it at the end, which is before CodeSign automatically)
project.save
puts "Added Run Script Phase to fix Info.plist"
