test_name "The report specifies which master was contacted during failover" do
  tag 'audit:medium',
      'audit:integration',
      'server'

  master_reportdir = create_tmpdir_for_user(master, 'report_dir')
  master_port = 8140

  teardown do
    on(master, "rm -rf #{master_reportdir}")
  end

  def remove_reports_on_master(master_reportdir, agent_node_name)
    on(master, "rm -rf #{master_reportdir}/#{agent_node_name}/*")
  end

  with_puppet_running_on(master, :master => { :reportdir => master_reportdir, :reports => 'store' }) do
    agents.each do |agent|
      # The server setting is set by beaker in puppet.conf, use a different conf file to avoid the deprecation warning
      tmpconf = agent.tmpfile('puppet_conf_test')

      step "master_used field should be the name and port of the successfully contacted master when failover is active" do
        step "no failover, successfully contact first master in the list" do
          on(agent, puppet("agent", "-t", "--config #{tmpconf}", "--server_list=#{master}:#{master_port},badmaster:22"), :acceptable_exit_codes => [0,2])
          on(master, "cat #{master_reportdir}/#{agent.node_name}/*") do
            assert_match(/master_used: #{master}:#{master_port}/, stdout, "expected '#{master}:#{master_port}' to be in the report")
          end
          remove_reports_on_master(master_reportdir, agent.node_name)
        end

        step "failover occurred, successfully report contact with first viable master" do
          on(agent, puppet("agent", "-t", "--config #{tmpconf}", "--server_list=badmaster:22,#{master}:#{master_port}"), :acceptable_exit_codes => [0,2])
          on(master, "cat #{master_reportdir}/#{agent.node_name}/*") do
            assert_match(/master_used: #{master}:#{master_port}/, stdout, "expected '#{master}:#{master_port}' to be in the report")
          end
          remove_reports_on_master(master_reportdir, agent.node_name)
        end

        step "master_field should not appear when no master could be conatacted" do
          on(agent, puppet("agent", "-t", "--config #{tmpconf}", "--server_list=badmaster:1","--http_connect_timeout=5s", "--report_server=#{master}"), :acceptable_exit_codes => [1])
          on(master, "cat #{master_reportdir}/#{agent.node_name}/*") do
            assert_no_match(/master_used:/, stdout, "did not expect master_used to be in the report")
          end
          remove_reports_on_master(master_reportdir, agent.node_name)
        end
      end

      step "master_used field should not appear in the report when not using the server_list setting" do
        on(agent, puppet("agent", "-t", "--server=#{master}"), :acceptable_exit_codes => [0,2])
        on(master, "cat #{master_reportdir}/#{agent.node_name}/*") do
          assert_no_match(/master_used:/, stdout, "did not expect master_used field to be in the report")
        end
        remove_reports_on_master(master_reportdir, agent.node_name)
      end
    end
  end
end
