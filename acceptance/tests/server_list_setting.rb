test_name "Priority of server_list setting over server setting" do

  tag 'audit:medium',
      'audit:unit',
      'audit:refactor'     # is only testing agent side behavior, should remove server

  master_port = 8140

  step "Conflict warnings for server settings" do
    with_puppet_running_on(master, {}) do
      agents.each do |agent|
        tmpconf = agent.tmpfile('puppet_conf_test')

        step "Server_list setting takes priority over server" do
          step "Invalid server setting with valid server_list setting should successfully contact master" do
            on(agent, puppet("agent", "-t", "--config #{tmpconf}", "--server notvalid", "--server_list #{master}:#{master_port}", "--debug"),
              :acceptable_exit_codes => [0, 2]) do |result|
              unless agent['locale'] == 'ja'
                assert_match(/Selected server from the `server_list` setting: #{master}:#{master_port}/,
                            result.stdout, "should have selected the working master")
              end
            end
          end
        end
      end
    end
  end
end
