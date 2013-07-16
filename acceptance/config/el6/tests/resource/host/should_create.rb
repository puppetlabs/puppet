test_name "host should create"

agents.each do |agent|
  target = agent.tmpfile('host-create')

  step "clean up for the test"
  on agent, "rm -f #{target}"

  step "create the host record"
  on(agent, puppet_resource("host", "test", "ensure=present",
              "ip=127.0.0.1", "target=#{target}"))

  step "verify that the record was created"
  on(agent, "cat #{target} ; rm -f #{target}") do
    fail_test "record was not present" unless stdout =~ /^127\.0\.0\.1[[:space:]]+test/
  end
end
