test_name "host should create"

tag 'audit:low',
    'audit:refactor',  # Use block style `test_name`
    'audit:acceptance' # Could be done at the integration (or unit) layer though
                       # actual changing of resources could irreparably damage a
                       # host running this, or require special permissions.

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
