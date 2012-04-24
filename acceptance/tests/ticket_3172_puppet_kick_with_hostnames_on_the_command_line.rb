test_name "#3172: puppet kick with hostnames on the command line"
step "verify that we trigger our host"

target = 'working.example.org'
agents.each do |host|
  if host['platform'].include?('windows')
    on(host, puppet_kick(target), :acceptable_exit_codes => [1]) {
      assert_match(/Puppet kick is not supported/, stdout)
    }
  else
    on(host, puppet_kick(target), :acceptable_exit_codes => [3]) {
      assert_match(/Triggering #{target}/, stdout, "didn't trigger #{target} on #{host}" )
    }
  end
end
