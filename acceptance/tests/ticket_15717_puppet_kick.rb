test_name "#15717: puppet kick"
step "verify puppet kick actually triggers an agent run"

confine :except, :platform => 'windows'

restauth_conf = <<END
path /run
auth yes
allow *

path /
auth any
END

with_master_running_on(master, "--autosign true") do
  agents.each do |agent|
    if agent == master
      Log.warn("This test does not support nodes that are both master and agent")
      next
    end

    step "create rest auth.conf on agent"
    testdir = agent.tmpdir('puppet-kick-auth')
    create_remote_file(agent, "#{testdir}/auth.conf", restauth_conf)

    step "daemonize the agent"
    on(agent, puppet_agent("--debug --daemonize --server #{master} --listen --rest_authconfig #{testdir}/auth.conf"))

    begin
      step "wait for agent to start listening"
      timeout = 15
      begin
        Timeout.timeout(timeout) do
          loop do
            # 7 is "Could not connect to host", which will happen before it's running
            result = on(agent, "curl -k https://#{agent}:8139", :acceptable_exit_codes => [0,7])
            break if result.exit_code == 0
            sleep 1
          end
        end
      rescue Timeout::Error
        fail_test "Puppet agent #{agent} failed to start after #{timeout} seconds"
      end

      begin
        done = false
        while not done do
          step "kick the agent from the master"
          # `puppet kick` exit code 3 may mean:
          # 1. the agent we started above is actively connecting to the master
          #    and applying a catalog, if so, wait for it to become idle
          # 2. auth.conf doesn't allow access to /run, which is the bug we're
          #    trying to verify
          # 3. the SSL server's cert verification failed, in which case fail
          #    early: SSL_connect returned=1 errno=0 state=SSLv3 read server
          #    certificate B: certificate verify failed
          # 4. who knows what else
          #
          # So make sure `puppet kick` returns with exit code 0 and prints
          # 'status is success'. Also make sure we get a deprecation warning
          on(master, puppet_kick("--host #{agent} --"), :acceptable_exit_codes => [0, 3]) do
            assert_match(/Puppet kick is deprecated/, stderr, "Puppet kick did not issue deprecation warning")

            if result.exit_code == 0
              assert_match(/status is success/, stdout, "Puppet kick was successful, but agent #{agent} did not report success")
              done = true
            elsif stdout.include? "status is running"
              step "Agent #{agent} is already running, retrying kick"
            else
              fail_test "Failed to trigger puppet kick on host #{agent}"
            end
          end
        end
      rescue Timeout::Error
        fail_test "Puppet agent #{agent} failed to kick after #{timeout} seconds"
      end
    ensure
      step "kill agent"
      on(agent, puppet_agent("--configprint pidfile #{config}")) do
        on(agent, "kill `cat #{stdout.chomp}`")
      end
    end
  end
end
