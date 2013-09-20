test_name "#7101: template compile"

agents.each do |agent|
  template = agent.tmpfile('template_7101.erb')
  target = agent.tmpfile('file_7101.erb')

  manifest = %Q{
$bar = 'test 7101'
file { '#{target}':
  content => template("#{template}")
}
}

  step "Agents: Create template file"
  create_remote_file(agent, template, %w{<%= bar %>} )

  step "Run manifest referencing template file"
  apply_manifest_on(agent, manifest)

  step "Agents: Verify file is created with correct contents "
  on(agent, "cat #{target}") do
    assert_match(/test 7101/, stdout, "File #{target} not created with correct contents on #{agent}" )
  end
end
