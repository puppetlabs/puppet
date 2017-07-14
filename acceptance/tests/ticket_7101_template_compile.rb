test_name "#7101: template compile"

tag 'audit:low',
    'audit:refactor', # Use block style `test_name`
    'audit:unit'     # basic template handling

agents.each do |agent|
  template = agent.tmpfile('template_7101.erb')
  target = agent.tmpfile('file_7101.erb')

  manifest = <<-EOF
  $bar = 'test 7101'
  file { '#{target}':
    content => template("#{template}")
  }
  EOF

  step "Agents: Create template file"
  create_remote_file(agent, template, "<%= @bar %>" )

  step "Run manifest referencing template file"
  apply_manifest_on(agent, manifest)

  step "Agents: Verify file is created with correct contents "
  on(agent, "cat #{target}") do
    assert_match(/test 7101/, stdout, "File #{target} not created with correct contents on #{agent}" )
  end
end
