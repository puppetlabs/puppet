test_name "should delete a user with managehome=true" do
  confine :except, :platform => /osx/

  tag 'audit:high',
      'audit:acceptance' # Could be done as integration tests, but would
                         # require changing the system running the test
                         # in ways that might require special permissions
                         # or be harmful to the system running the test

  agents.each do |agent|
    home = ''
    name = "pl#{rand(999999).to_i}"

    teardown do
      agent.user_absent(name)
    end

    step "ensure the user is present" do
      agent.user_present(name)
    end

    step "get home directory path" do
      on(agent, puppet_resource('user', name)) do |result|
        info = result.stdout.match(/home\s+=>\s+'(.+)',/)
        home = info[1] if info
      end
    end

    step "delete the user with managehome=true" do
      on(agent, puppet_resource('user', name, ['ensure=absent', 'managehome=true']))
    end

    step "verify the user was deleted" do
      fail_test "User '#{name}' was not deleted" if agent.user_list.include?(name)
    end

    step "verify the home directory was deleted" do
      skip_test("managehome parameter on Windows is not behaving as expected. See PUP-11202") if agent['platform'] =~ /windows/
      on(agent, "test -d #{home}", :acceptable_exit_codes => [1])
    end
  end
end
