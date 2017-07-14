test_name "should be able to modify a host address"

tag 'audit:low',
    'audit:refactor',  # Use block style `test_name`
    'audit:acceptance' # Could be done at the integration (or unit) layer though
                       # actual changing of resources could irreparably damage a
                       # host running this, or require special permissions.

agents.each do |agent|
  file = agent.tmpfile('host-modify-ip')

  step "set up files for the test"
  on agent, "printf '127.0.0.9 test alias\n' > #{file}"

  step "modify the resource"
  on(agent, puppet_resource('host', 'test', "target=#{file}",
              'ensure=present', 'ip=127.0.0.10', 'host_aliases=alias'))

  step "verify that the content was updated"
  on(agent, "cat #{file}; rm -f #{file}") do
    fail_test "the address was not updated" unless
      stdout =~ /^127\.0\.0\.10[[:space:]]+test[[:space:]]+alias[[:space:]]*$/
  end

  step "clean up after the test"
  on agent, "rm -f #{file}"
end
