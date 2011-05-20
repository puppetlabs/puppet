test_name "#7139: Puppet resource file failes on path with leading '/'"

step "Agents: create valid, invalid formatted manifests"
create_remote_file(agents, '/tmp/ticket-7139', %w{foo bar contents} )

step "Run puppet file resource on /tmp/ticket-7139"
agents.each do |host|
  on(host, "puppet resource file /tmp/ticket-7139") do
    assert_match(/file \{ \'\/tmp\/ticket-7139\':/, stdout, "puppet resource file failed on #{host}")
  end
end
