test_name "should query all services"

agents.each do |agent|
  step "query with puppet"
  on(agent, puppet_resource('service'), :accept_all_exit_codes => true) do
    assert_equal(exit_code, 0, "'puppet resource service' should have an exit code of 0")
    assert(/^service/ =~ stdout, "'puppet resource service' should present service details")
  end
end
