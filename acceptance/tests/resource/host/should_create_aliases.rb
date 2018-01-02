test_name "host should create aliases"

tag 'audit:low',
    'audit:refactor',  # Use block style `test_name`
    'audit:acceptance' # Could be done at the integration (or unit) layer though
                       # actual changing of resources could irreparably damage a
                       # host running this, or require special permissions.

agents.each do |agent|
  target  = agent.tmpfile('host-create-aliases')

  step "clean up the system for testing"
  on agent, "rm -f #{target}"

  step "create the record"
  on(agent, puppet_resource('host', 'test', "ensure=present",
              "ip=127.0.0.7", "target=#{target}", "host_aliases=alias"))

  step "verify that the aliases were added"
  on(agent, "cat #{target} ; rm -f #{target}") do
    fail_test "alias was missing" unless
      stdout =~ /^127\.0\.0\.7[[:space:]]+test[[:space:]]alias/
  end
end
