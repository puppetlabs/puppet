test_name "#3172: puppet kick with hostnames on the command line"
step "verify that we trigger our host"

target = 'working.example.org'
agents.each do |host|
  on(host, puppet_kick(target), :acceptable_exit_codes => [3]) {
    assert_match(/Triggering #{target}/, stdout, "didn't trigger #{target} on #{host}" )
  }
end
