test_name "#3172: puppet kick with hostnames on the command line"
step "Verify puppet kick application attempts to connect to the hostname specified on the command line"

target = 'working.example.org'
agents.each do |host|
  if host['platform'].include?('windows')
    on(host, puppet_kick(target), :acceptable_exit_codes => [1]) {
      assert_match(/Puppet kick is not supported/, stderr)
    }
  else
    # Error: Host working.example.org failed: getaddrinfo: Name or service not known
    # working.example.org finished with exit code 2
    # Failed: working.example.org
    # Exited: 3
    on(host, puppet_kick(target), :acceptable_exit_codes => [3]) {
      assert_match(/Triggering #{target}/, stdout, "didn't trigger #{target} on #{host}" )
    }
  end
end
