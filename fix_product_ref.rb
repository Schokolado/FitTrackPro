require 'xcodeproj'
project = Xcodeproj::Project.open('FitTrackPro.xcodeproj')
target = project.targets.find { |t| t.name == 'FitTrackPro' }

if target.product_reference.nil?
  products_group = project.products_group
  # Check if FitTrackPro.app already exists in Products
  app_ref = products_group.children.find { |c| c.path == 'FitTrackPro.app' }
  if app_ref.nil?
    app_ref = products_group.new_product_ref_for_target(target.product_name, target.product_type)
  end
  target.product_reference = app_ref
  project.save
  puts "Fixed product reference!"
else
  puts "Already fixed"
end

# Recreate the scheme now that product reference exists
shared_data_dir = File.join('FitTrackPro.xcodeproj', 'xcshareddata', 'xcschemes')
FileUtils.mkdir_p(shared_data_dir)
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(target)
scheme.set_launch_target(target)
scheme.save_as('FitTrackPro.xcodeproj', target.name, true)
puts "Recreated scheme!"
