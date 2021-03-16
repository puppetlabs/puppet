test_name 'Supports vendored modules' do
  tag 'risk:high'

  # beacon custom type emits a message so we can tell where the
  # type was loaded from, e.g. vendored, global, and whether the
  # type was loaded locally or pluginsynced from the master.
  def beacon_type(message)
    return <<END
    Puppet::Type.newtype(:beacon) do
      newparam(:name,  :namevar => true)
      newproperty(:message) do
        def sync; true; end
        def retrieve; :absent; end
        def insync?(is); false; end
        defaultto { "#{message}" }
      end
    end
END
  end

  def global_modules(host)
    if host.platform =~ /windows/
      '/cygdrive/c/ProgramData/PuppetLabs/code/modules'
    else
      '/etc/puppetlabs/code/modules'
    end
  end

  def vendor_modules(host)
    if host.platform =~ /windows/
      # escape spaces
      "/cygdrive/c/Program\\ Files/Puppet\\ Labs/Puppet/puppet/vendor_modules"
    else
      '/opt/puppetlabs/puppet/vendor_modules'
    end
  end

  teardown do
    hosts.each do |host|
      on(host, "rm -rf #{vendor_modules(host)}/beacon")
      on(host, "rm -rf #{global_modules(host)}/beacon")

      libdir = host.puppet['vardir']
      on(host, "rm -rf #{libdir}")
    end

    on(master, "rm -rf /etc/puppetlabs/code/environments/production/modules/beacon")
    on(master, "rm -f /etc/puppetlabs/code/environments/production/manifests/site.pp")
  end

  step 'delete libdir' do
    hosts.each do |host|
      on(host, "rm -rf #{host.puppet['libdir']}")
    end
  end

  step 'create vendored module with a custom type' do
    hosts.each do |host|
      vendor_dir = vendor_modules(host)
      on(host, "mkdir -p #{vendor_dir}/beacon/lib/puppet/type")

      # unescape, because net-scp escapes
      vendor_dir.gsub!(/\\/, '')
      create_remote_file(host, "#{vendor_dir}/beacon/lib/puppet/type/beacon.rb", beacon_type("vendored module from #{host}"))
    end
  end

  step 'vendored modules work locally' do
    hosts.each do |host|
      on(host, puppet("apply -e \"beacon { 'ping': }\"")) do |result|
        assert_match(/defined 'message' as 'vendored module from #{host}'/, result.stdout)
      end
    end
  end

  step 'vendored modules can be excluded' do
    hosts.each do |host|
      on(host, puppet("describe --vendormoduledir '' beacon"), accept_all_exit_codes: true) do |result|
        assert_match(/Unknown type beacon/, result.stdout)
      end
    end
  end

  step 'global modules override vendored modules' do
    agents.each do |agent|
      # skip the agent on the master, as we don't want to install the
      # global module on the master until later
      next if agent == master

      global_dir = global_modules(agent)
      on(agent, "mkdir -p #{global_dir}/beacon/lib/puppet/type")

      # global_dir doesn't have spaces, so don't need to escape
      create_remote_file(agent, "#{global_dir}/beacon/lib/puppet/type/beacon.rb", beacon_type("global module from #{agent}"))

      on(agent, puppet("apply -e \"beacon { 'ping': }\"")) do |result|
        assert_match(/defined 'message' as 'global module from #{agent}'/, result.stdout)
      end
    end
  end

  step "prepare server" do
    create_remote_file(master, "/etc/puppetlabs/code/environments/production/manifests/site.pp", "beacon { 'ping': }")
    on(master, "chown -R puppet:puppet /etc/puppetlabs/code/environments/production/manifests/site.pp")
    on(master, "chown -R puppet:puppet #{vendor_modules(master)}")
  end

  with_puppet_running_on(master, {}) do
    step "agent doesn't pluginsync the vendored module, instead using its local vendored module" do
      agents.each do |agent|
        on(agent, puppet("agent -t"), :acceptable_exit_codes => [0,2]) do |result|
          assert_match(/defined 'message' as 'vendored module from #{agent}'/, result.stdout)
        end
      end
    end

    step "agent downloads and uses newly installed global module from the server" do
      global_dir = global_modules(master)
      on(master, "mkdir -p #{global_dir}/beacon/lib/puppet/type")
      create_remote_file(master, "#{global_dir}/beacon/lib/puppet/type/beacon.rb", beacon_type("server module from #{master}"))
      on(master, "chown -R puppet:puppet #{global_dir}")

      agents.each do |agent|
        on(agent, puppet("agent -t"), :acceptable_exit_codes => [0,2]) do |result|
          assert_match(/defined 'message' as 'server module from #{master}'/, result.stdout)
        end
      end
    end
  end
end
