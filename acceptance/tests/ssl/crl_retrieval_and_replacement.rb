test_name "Crl retrieval and replacement from master" do

  tag 'risk:medium',
      'server'

  with_puppet_running_on(master, {}) do
    agents.each do |agent|
      ca_crl_path = puppet_config(master, 'cacrl', section: 'master')
      crl_path = puppet_config(agent, 'hostcrl', section: 'agent')

      step "When a newer crl is available on master" do
        one_hour_ahead = on(master, "TZ=ZZZ-1:00 date +%Y%m%d%H%M.%S").stdout.chomp
        on(master, "touch -t #{one_hour_ahead} #{ca_crl_path}")

        step "Should replace the current agent crl" do
          old_agent_crl_mtime = on(agent, "stat -c '%Y' #{crl_path}").stdout
          on(agent, puppet("agent", "-t", "--server #{master}"), :acceptable_exit_codes => [0, 2])
          on(agent, "stat -c '%Y' #{crl_path}") do
            refute_equal(old_agent_crl_mtime, stdout, "expected crl to have been replaced, but was not")
          end
        end
      end

      step "When a newer crl is NOT available on master" do
        one_hour_behind = on(master, "TZ=ZZZ+1:00 date +%Y%m%d%H%M.%S").stdout.chomp
        on(master, "touch -t #{one_hour_behind} #{ca_crl_path}")

        step "Should NOT replace the current agent crl" do
          old_agent_crl_mtime = on(agent, "stat -c '%Y' #{crl_path}").stdout
          on(agent, puppet("agent", "-t", "--server #{master}"), :acceptable_exit_codes => [0, 2])
          on(agent, "stat -c '%Y' #{crl_path}") do
            assert_equal(old_agent_crl_mtime, stdout, "expected crl to NOT have been replaced, but was")
          end
        end
      end

      step "When an agent does not have a crl" do
        on(agent, "rm -rf #{crl_path}")
        on(agent, "test -f #{crl_path}", :acceptable_exit_codes => [1])

        step "Should create a crl file" do
          on(agent, puppet("agent", "-t", "--server #{master}"), :acceptable_exit_codes => [0, 2])
          on(agent, "test -f #{crl_path}", :acceptable_exit_codes => [0])
        end
      end
    end
  end
end
