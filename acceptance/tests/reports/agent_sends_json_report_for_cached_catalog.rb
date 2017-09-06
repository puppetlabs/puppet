test_name "C100533: Agent sends json report for cached catalog" do
  skip_test 'requires a master' if master.nil?

  tag 'risk:medium',
      'audit:medium',
      'audit:integration',
      'server'

  with_puppet_running_on(master, :main => {}) do
    expected_format = 'json'

    step "Perform agent run to ensure that catalog is cached" do
      agents.each do |agent|
        on(agent, puppet('agent', '-t', "--server #{master}"), :acceptable_exit_codes => [0,2])
      end
    end

    step "Ensure agent sends #{expected_format} report for cached catalog" do
      agents.each do |agent|
        on(agent, puppet('agent', '-t',
                         "--server #{master}",
                         '--http_debug'), :acceptable_exit_codes => [0,2]) do |res|
          # Expected content-type should be in the headers of the
          # HTTP report payload being PUT to the server by the agent.
          unless res.stderr =~ /<- "PUT \/puppet\/v[3-9]\/report.*Content-Type: .*\/#{expected_format}/
            fail_test("Report was not submitted in #{expected_format} format")
          end
        end
      end
    end

  end

end
