test_name "verifies that puppet resource creates a user and assigns the correct expiry date when absent" do
  confine :except, :platform => 'windows'

  tag 'audit:high',
      'audit:acceptance' # Could be done as integration tests, but would
                         # require changing the system running the test
                         # in ways that might require special permissions
                         # or be harmful to the system running the test

  user = "pl#{rand(999999).to_i}"

  teardown do
    step "cleanup"
    agents.each do |host|
      on(host, puppet_resource('user', user, 'ensure=absent'))
    end
  end
  
  agents.each do |host|
    step "user should not exist"
    on(host, puppet_resource('user', user, 'ensure=absent'), :acceptable_exit_codes => [0])
  
    step "create user with expiry=absent"
    on(host, puppet_resource('user', user, 'ensure=present', 'expiry=absent'), :acceptable_exit_codes => [0])
  
    step "verify the user exists and expiry is not set (meaning never expire)"
    on(host, puppet_resource('user', user)) do |result|
      assert_match(/ensure.*=> 'present'/, result.stdout)
      refute_match(/expiry.*=>/, result.stdout)
    end
  end
end
