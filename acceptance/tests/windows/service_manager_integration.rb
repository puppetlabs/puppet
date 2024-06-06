test_name 'Test agent state via service control manager' do

  tag 'audit:integration'

  confine :to, platform: 'windows'

  teardown do
    agents.each do |agent|
      state = query_agent_state(agent)
      if state != "STOPPED"
        stop_puppet_windows_daemon(agent)
        ensure_agent_state(agent, "STOPPED")
      end
    end
  end

  def query_agent_state(host)
    on(host, 'sc query puppet').stdout.match(/STATE.+\s{1}(\w+)/)[1]
  end

  def start_puppet_windows_daemon(host)
    on(host, 'sc start puppet')
  end

  def stop_puppet_windows_daemon(host)
    on(host, 'sc stop puppet')
  end

  def ensure_agent_state(host, state)
    retry_attempts = 0
    while retry_attempts < 5
      return if state == query_agent_state(host)
      retry_attempts += 1
      sleep 1
    end
    fail_test "State not #{state} after 5 tries"
  end

  step 'store initial state' do

    agents.each do |agent|
      initial_state = query_agent_state(agent)
      assert_match("STOPPED", initial_state, "agent daemon should initially be stopped")

      start_puppet_windows_daemon(agent)
      ensure_agent_state(agent, "RUNNING")
      stop_puppet_windows_daemon(agent)
      ensure_agent_state(agent, "STOPPED")
    end
  end
end
