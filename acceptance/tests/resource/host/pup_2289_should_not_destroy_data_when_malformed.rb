test_name "should not delete data when existing content is malformed"

tag 'audit:low',
    'audit:refactor',  # Use block style `test_name`
    'audit:acceptance' # Could be done at the integration (or unit) layer though
                       # actual changing of resources could irreparably damage a
                       # host running this, or require special permissions.

agents.each do |agent|
  file = agent.tmpfile('host-not-delete-data')

  teardown do
    on(agent, "rm -f #{file}", :acceptable_exit_codes => (0..255))
  end

  step "(setup) populate test file with host information"
  on(agent, "printf '127.0.0.2 existing alias\n' > #{file}")

  step "(setup) populate test file with a malformed line"
  on(agent, "printf '==\n' >> #{file}")

  step "tell puppet to add another host entry"
  on(agent, puppet_resource('host', 'test', "target=#{file}",
    'ensure=present', 'ip=127.0.0.3', 'host_aliases=foo'))

  step "verify that the initial host entry was not deleted"
  on(agent, "cat #{file}") do |res|
    fail_test "existing host data was deleted" unless
      res.stdout.include? 'existing'
  end

end
