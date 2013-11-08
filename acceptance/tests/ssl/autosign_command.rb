require 'puppet/acceptance/common_utils'
extend Puppet::Acceptance::CAUtils

test_name "autosign_command behavior (#7244)" do

  def assert_key_generated(name)
    assert_match(/Creating a new SSL key for #{name}/, stdout, "Expected agent to create a new SSL key for autosigning")
  end

  testdir = master.tmpdir('autosign_command')

  teardown do
    step "Remove autosign configuration"
    on(master, host_command("rm -rf '#{testdir}'") )
    reset_agent_ssl
  end

  reset_agent_ssl(false)

  step "Step 1: ensure autosign_command can approve CSRs"

  master_opts = {'master' => {'autosign' => 'false', 'autosign_command' => '/bin/true'}}
  with_puppet_running_on(master, master_opts) do
    agents.each do |agent|
      next if agent == master

      on(agent, puppet("agent --test --server #{master} --waitforcert 0"))
      assert_key_generated(agent)
      assert_match(/Caching certificate for #{agent}/, stdout, "Expected certificate to be autosigned")
    end
  end

  reset_agent_ssl(false)

  step "Step 2: ensure autosign_command can reject CSRs"

  master_opts = {'master' => {'autosign' => 'false', 'autosign_command' => '/bin/false'}}
  with_puppet_running_on(master, master_opts) do
    agents.each do |agent|
      next if agent == master

      on(agent, puppet("agent --test --server #{master} --waitforcert 0"), :acceptable_exit_codes => [1])
      assert_key_generated(agent)
      assert_match(/no certificate found/, stdout, "Expected certificate to not be autosigned")
    end
  end
end
