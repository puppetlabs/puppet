test_name "#7139: Puppet resource file fails on path with leading '/'"

tag 'audit:low',
    'audit:refactor', # Use block style `test_name`
    'audit:unit'     # basic puppet file resource validation?

agents.each do |agent|
  target = agent.tmpfile('ticket-7139')

  step "Agents: create valid, invalid formatted manifests"
  create_remote_file(agent, target, %w{foo bar contents} )

  step "Run puppet file resource on #{target}"
  on(agent, puppet_resource('file', target)) do
    assert_match(/file \{ \'#{Regexp.escape(target)}\':/, stdout, "puppet resource file failed on #{agent}")
  end
end
