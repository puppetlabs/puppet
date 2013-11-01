test_name "autosign_command behavior (#7244)" do

  def assert_key_generated(name)
    assert_match(/Creating a new SSL key for #{name}/, stdout, "Expected agent to create a new SSL key for autosigning")
  end

  def reset_agent_ssl
    return if master.is_pe?
    clear_agent_ssl

    hostname = master.execute('facter hostname')
    fqdn = master.execute('facter fqdn')

    step "Master: Ensure the master bootstraps CA"
    with_puppet_running_on(master,
                            :master => {
                              :dns_alt_names => "puppet,#{hostname},#{fqdn}",
                              :autosign => true,
                            }
                          ) do

      agents.each do |agent|
        next if agent == master
        step "Clear old agent certificate from master" do
          agent_cn = on(agent, puppet('agent --configprint certname')).stdout.chomp
          puts "agent cn: #{agent_cn}"
          clean_cert(master, agent_cn) if agent_cn
        end
      end
    end
  end


  def clean_cert(host, cn)
    on(host, puppet('cert', 'clean', cn), :acceptable_exit_codes => [0, 24])
  end

  def clear_agent_ssl
    return if master.is_pe?
    step "All: Clear agent only ssl settings (do not clear master)"
    hosts.each do |host|
      next if host == master
      ssldir = on(host, puppet('agent --configprint ssldir')).stdout.chomp
      on( host, host_command("rm -rf '#{ssldir}'") )
    end
  end

  testdir = master.tmpdir('autosign_command')

  teardown do
    step "Remove autosign configuration"
    on(master, host_command("rm -rf '#{testdir}'") )
    reset_agent_ssl
  end

  step "Step 1: ensure autosign_command can approve CSRs"

  reset_agent_ssl

  master_opts = {'master' => {'autosign' => 'false', 'autosign_command' => '/bin/true'}}
  with_puppet_running_on(master, master_opts) do
    agents.each do |agent|
      next if agent == master

      on(agent, puppet("agent --test --server #{master} --waitforcert 0"))
      assert_key_generated(agent)
      assert_no_match(/failed to retrieve certificate/, stdout, "Expected certificate to be autosigned")
    end
  end

  reset_agent_ssl

  step "Step 2: ensure autosign_command can reject CSRs"

  master_opts = {'master' => {'autosign' => 'false', 'autosign_command' => '/bin/false'}}
  with_puppet_running_on(master, master_opts) do
    agents.each do |agent|
      next if agent == master

      on(agent, puppet("agent --test --server #{master} --waitforcert 0"), :acceptable_exit_codes => [1])
      assert_key_generated(agent)
      assert_no_match(/failed to retrieve certificate/, stdout, "Expected certificate to not be autosigned")
    end
  end
end
