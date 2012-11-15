test_name "should not create host if it exists"

agents.each do |agent|
  file = agent.tmpfile('host-not-create-existing')

  step "set up the system for the test"
  on agent, "printf '127.0.0.2 test alias\n' > #{file}"

  step "tell puppet to ensure the host exists"
  on(agent, puppet_resource('host', 'test', "target=#{file}",
              'ensure=present', 'ip=127.0.0.2', 'host_aliases=alias')) do
    fail_test "darn, we created the host record" if
      stdout.include? '/Host[test1]/ensure: created'
  end

  step "clean up after we created things"
  on agent, "rm -f #{file}"
end
