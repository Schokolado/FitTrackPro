require 'xcodeproj'
project = Xcodeproj::Project.open('FitTrackPro.xcodeproj')
target = project.targets.find { |t| t.name == 'FitTrackPro' }
puts "Target: #{target.name}"
puts "Product Type: #{target.product_type}"
puts "Product Name: #{target.product_name}"
puts "Product Reference: #{target.product_reference.inspect}"
if target.product_reference
  puts "Product Ref Path: #{target.product_reference.path}"
end
