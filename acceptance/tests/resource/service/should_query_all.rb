test_name "should query all services"

tag 'audit:medium',
    'audit:refactor',   # Investigate combining with should_not_change_the_system.rb
                        # Use block style `test_name`
    'audit:integration' # Doesn't change the system it runs on

agents.each do |agent|
  step "query with puppet"
  on(agent, puppet_resource('service'), :accept_all_exit_codes => true) do
    assert_equal(exit_code, 0, "'puppet resource service' should have an exit code of 0")
    assert(/^service/ =~ stdout, "'puppet resource service' should present service details")
  end
end
