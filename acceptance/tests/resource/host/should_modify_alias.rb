test_name "should be able to modify a host alias"

tag 'audit:low',
    'audit:refactor',  # Use block style `test_name`
    'audit:acceptance' # Could be done at the integration (or unit) layer though
                       # actual changing of resources could irreparably damage a
                       # host running this, or require special permissions.

agents.each do |agent|
  file = agent.tmpfile('host-modify-alias')

  step "set up files for the test"
  on agent, "printf '127.0.0.8 test alias\n' > #{file}"

  step "modify the resource"
  on(agent, puppet_resource('host', 'test', "target=#{file}",
              'ensure=present', 'ip=127.0.0.8', 'host_aliases=banzai'))

  step "verify that the content was updated"
  on(agent, "cat #{file}; rm -f #{file}") do
    fail_test "the alias was not updated" unless
      stdout =~ /^127\.0\.0\.8[[:space:]]+test[[:space:]]+banzai[[:space:]]*$/
  end

  step "clean up after the test"
  on agent, "rm -f #{file}"
end
