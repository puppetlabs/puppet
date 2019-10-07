test_name "QA-760 - Windows Files Containing '-' and '.'"

tag 'risk:medium',
    'audit:medium',
    'audit:refactor',   # Use block style `test_name`
    'audit:integration'

confine(:to, :platform => 'windows')

temp_folder = <<-MANIFEST
file { 'c:/temp':
  ensure => directory
}
MANIFEST

dash_dot_file = <<-MANIFEST
file { 'c:/temp/dash-dot-%s.file':
  ensure  => file,
  content => "The file has new content: %s!",
}
MANIFEST

step "Generate Manifest"

first_run_manifest = ""
second_run_manifest = ""

for i in 1..100
  first_run_manifest += "#{dash_dot_file}\n" % [i,i]
  second_run_manifest += "#{dash_dot_file}\n" % [i,-i]
end

step "Create Temp Folder"

agents.each do |agent|
  on(agent, puppet('apply', '--debug'), :stdin => temp_folder)
end

step "Create Dash Dot File 100 Times"

agents.each do |agent|
  on(agent, puppet('apply', '--debug'), :stdin => first_run_manifest)
end

step "Update Dash Dot File 100 Times"

agents.each do |agent|
  on(agent, puppet('apply', '--debug'), :stdin => second_run_manifest)
end
