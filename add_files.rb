require 'xcodeproj'

project_path = 'BodyMeasureAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'BodyMeasureAI' }

group = project.main_group.find_subpath(File.join('BodyMeasureAI', 'StylistA', 'Services'), true)

files_to_add = [
  'KeychainManager.swift',
  'DeviceIdentifierManager.swift'
]

files_to_add.each do |filename|
  # Avoid adding duplicates
  unless group.files.find { |f| f.path == filename }
    file_ref = group.new_file(filename)
    target.source_build_phase.add_file_reference(file_ref)
  end
end

project.save
