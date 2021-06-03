test_name 'should manage purge_ssh_keys for new user' do

  tag 'audit:high',
      'audit:acceptance'

  name = "usr#{rand(9999).to_i}"

  agents.each do |agent|
    teardown do
      on(agent, puppet_resource('user', "#{name}", 'ensure=absent'))
    end

    home = agent.tmpdir(name)
    authorized_keys_file = agent.tmpfile("authorized_keys")

    step "create user #{name} with ssh keys purged and expect no failure" do
      apply_manifest_on(agent, <<-MANIFEST, { :catch_failures => true, :debug => true }) do |result|
          user {'#{name}':
            ensure => present,
            home => '#{home}',
            purge_ssh_keys => true
          }
        MANIFEST

        assert_no_match(/User '#{name}' has no home directory set to purge ssh keys from./, result.stdout)
      end
    end

    step "remove user #{name} and purge ssh keys purged and expect no failure" do
      apply_manifest_on(agent, <<-MANIFEST, { :catch_failures => true, :debug => true }) do |result|
          user {'#{name}':
            ensure => absent,
            home => '#{home}',
            purge_ssh_keys => true
          }
        MANIFEST

        assert_no_match(/User '#{name}' has no home directory set to purge ssh keys from./, result.stdout)
      end
    end

    # Platforms such as macOS does not support the `managehome` parameter
    # which we're expecting to remove homedir when ensure of user is set
    # to absent
    step "remove homedir" do
      agent.rm_rf(home)
    end

    step "expect debug log with home directory missing on second run of same manifest" do
      apply_manifest_on(agent, <<-MANIFEST, { :catch_failures => true, :debug => true }) do |result|
          user {'#{name}':
            ensure => absent,
            home => '#{home}',
            purge_ssh_keys => true
          }
        MANIFEST

        assert_match(/User '#{name}' has no home directory set to purge ssh keys from./, result.stdout)
      end
    end

    step "expect debug log with home directory missing when purge_ssh_keys has relative path to home" do
      apply_manifest_on(agent, <<-MANIFEST, { :catch_failures => true, :debug => true }) do |result|
          user {'#{name}':
            ensure => absent,
            purge_ssh_keys => '~/authorized_keys'
          }
        MANIFEST

        assert_match(/User '#{name}' has no home directory set to purge ssh keys from./, result.stdout)
      end
    end

    step "expect no debug log with home directory missing when purge_ssh_keys has absolute path" do
      apply_manifest_on(agent, <<-MANIFEST, { :catch_failures => true, :debug => true }) do |result|
          user {'#{name}':
            ensure => absent,
            purge_ssh_keys => '#{authorized_keys_file}'
          }
        MANIFEST

        assert_no_match(/User '#{name}' has no home directory set to purge ssh keys from./, result.stdout)
      end
    end
  end
end
