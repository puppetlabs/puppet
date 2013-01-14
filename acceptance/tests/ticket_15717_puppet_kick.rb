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

    # kick will verify the SSL server's cert, but since the master and
    # agent can be in different domains (ec2, dc1), ask the agent for
    # its fqdn, and always kick using that
    agent_fqdn = on(agent, facter('fqdn')).stdout.chomp

    step "create rest auth.conf on agent"
    testdir = agent.tmpdir('puppet-kick-auth')
    create_remote_file(agent, "#{testdir}/auth.conf", restauth_conf)

    step "daemonize the agent"
    on(agent, puppet_agent("--debug --daemonize --server #{master} --listen --no-client --rest_authconfig #{testdir}/auth.conf"))

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

      step "kick the agent from the master"
      on(master, puppet_kick("--host #{agent_fqdn}")) do
        assert_match(/Puppet kick is deprecated/, stderr, "Puppet kick did not issue deprecation warning")
        assert_match(/status is success/, stdout, "Puppet kick was successful, but agent #{agent} did not report success")
      end
    ensure
      step "kill agent"
      on(agent, puppet_agent("--configprint pidfile #{config}")) do
        on(agent, "kill `cat #{stdout.chomp}`")
      end
    end
  end
end
