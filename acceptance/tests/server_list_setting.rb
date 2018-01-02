test_name "Priority of server_list setting over server setting" do

  tag 'audit:medium',
      'audit:unit',
      'audit:refactor'     # is only testing agent side behavior, should remove server

  master_port = 8140

  step "Conflict warnings for server settings"
  with_puppet_running_on(master, {}) do
    agents.each do |agent|
      tmpconf = agent.tmpfile('puppet_conf_test')

      step "Should emit a warning when trying to set both server and server_list" do
        step "when server is set first" do
          on(agent, puppet("agent", "-t", "--config #{tmpconf}", "--server #{master}", "--server_list #{master}:#{master_port},another:123"),
            :acceptable_exit_codes => [0, 2]) do |result|
            unless agent['locale'] == 'ja'
              assert_match(/Attempted to set both server and server_list/,
                           result.stderr, "a warning should have been issued because both server setttings were used")
            end
          end
        end

        step "when server_list is set first" do
          on(agent, puppet("agent", "-t", "--config #{tmpconf}", "--server_list #{master}:#{master_port},another:123", "--server #{master}"),
            :acceptable_exit_codes => [0, 2]) do |result|
            unless agent['locale'] == 'ja'
              assert_match(/Attempted to set both server and server_list/,
                           result.stderr, "a warning should have been issued because both server setttings were used")
            end
          end
        end
      end

      step "Should not emit a warning when only one setting is used" do
        step "only server_list" do
          on(agent, puppet("agent", "-t", "--config #{tmpconf}", "--server_list #{master}:#{master_port},another:123"),
            :acceptable_exit_codes => [0, 2]) do |result|
              assert_no_match(/Attempted to set both server and server_list/,
                              result.stderr, "a warning should not have been issued because only one settting was used")
          end
        end

        step "only server" do
          on(agent, puppet("agent", "--config #{tmpconf}", "-t", "--server #{master}"),
            :acceptable_exit_codes => [0, 2]) do |result|
              assert_no_match(/Attempted to set both server and server_list/, result.stderr, "a warning should not have been issued because only one settting was used")
          end
        end

        step "Server_list setting takes priority over server" do
          step "Invalid server setting with valid server_list setting should successfully contact master" do
            on(agent, puppet("agent", "-t", "--config #{tmpconf}", "--server notvalid", "--server_list #{master}:#{master_port}", "--debug"),
               :acceptable_exit_codes => [0, 2]) do |result|
              unless agent['locale'] == 'ja'
                assert_match(/Selected master: #{master}:#{master_port}/,
                             result.stdout, "should have selected the working master")
              end
            end
          end
        end
      end
    end
  end
end
