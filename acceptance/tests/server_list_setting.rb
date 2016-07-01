test_name "Priority of server_list setting over server setting" do
  master_port = 8140

  step "Conflict warnings for server settings"
  with_puppet_running_on(master, {}) do
    agents.each do |agent|
      step "Should emit a warning when trying to set both server and server_list" do
        step "when server is set first" do
          on(agent, puppet("agent", "-t", "--server #{master}", "--server_list #{master}:#{master_port},another:123"), 
            :acceptable_exit_codes => [0, 2]) do |result|
              assert_match(/Attempted to set both server and server_list/, result.stderr, "a warning should have been issued because both server setttings were used")
            end
        end

        step "when server_list is set first" do
          on(agent, puppet("agent", "-t", "--server_list #{master}:#{master_port},another:123", "--server #{master}"), 
            :acceptable_exit_codes => [0, 2]) do |result|
              assert_match(/Attempted to set both server and server_list/, result.stderr, "a warning should have been issued because both server setttings were used")
            end
        end
      end

      step "Should not emit a warning when only one setting is used" do
        step "only server_list" do
          on(agent, puppet("agent", "-t", "--server_list #{master}:#{master_port},another:123"), 
            :acceptable_exit_codes => [0, 2]) do |result|
              assert_no_match(/Attempted to set both server and server_list/, result.stderr, "a warning should not have been issued because only one settting was used")
            end
        end

        step "only server" do
          on(agent, puppet("agent", "-t", "--server #{master}"), 
            :acceptable_exit_codes => [0, 2]) do |result|
              assert_no_match(/Attempted to set both server and server_list/, result.stderr, "a warning should not have been issued because only one settting was used")
            end
        end
      end
    end
  end

  step "Server_list setting takes priority over server"
  with_puppet_running_on(master, {}) do
    agents.each do |agent|
      step "Invalid server setting with valid server_list setting should successfully contact master" do
        on(agent, puppet("agent", "-t", "--server notvalid", "--server_list #{master}:#{master_port}", "--debug"), 
           :acceptable_exit_codes => [0, 2]) do |result|
             assert_match(/Selected master: #{master}:#{master_port}/, result.stdout, "should have selected the working master")
           end
      end
    end
  end
end
