require 'xcodeproj'
project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

def add_file(project, target, path_string)
  group_path = path_string.split('/')[0...-1].join('/')
  file_name = path_string.split('/').last
  group = project.main_group.find_subpath("FitTrackPro/#{group_path}", true)
  file_ref = group.files.find { |f| f.path == file_name }
  unless file_ref
    file_ref = group.new_reference(file_name)
    target.add_file_references([file_ref])
    puts "Added #{file_name}"
  end
end

add_file(project, target, "Core/UI/ShareSheet.swift")
add_file(project, target, "Core/Services/PDFExportService.swift")
add_file(project, target, "Features/Training/Plans/PDF/PDFEmptyPlanTemplate.swift")
add_file(project, target, "Features/Training/Plans/PDF/PDFHistoricalPlanTemplate.swift")

project.save
