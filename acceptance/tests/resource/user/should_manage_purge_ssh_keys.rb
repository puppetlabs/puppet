test_name 'should manage purge_ssh_keys' do
  tag 'audit:high',
      'audit:acceptance'

  # MODULES-11236
  skip_test('This test does not work on Windows nor macOS') if agent['platform'] =~ /windows/ || agent['platform'] =~ /osx/

  name = "usr#{rand(9999).to_i}"

  agents.each do |agent|
    home = agent.tmpdir(name)
    authorized_keys_path = "#{home}/.ssh/authorized_keys"

    teardown do
      agent.rm_rf(home)
      on(agent, puppet_resource('user', "#{name}", 'ensure=absent'))
    end

    step "create user #{name} with ssh keys purged" do
      apply_manifest_on(agent, <<-MANIFEST, { :catch_failures => true, :debug => true }) do |result|
          user {'#{name}':
            ensure => present,
            home => '#{home}',
            purge_ssh_keys => true
          }
        MANIFEST
      end

      on(agent, puppet("resource user #{name} --to_yaml")) do |result|
        resource = YAML.load(result.stdout)
        assert_match('present', resource['user'][name]['ensure'])
      end
    end

    step "ensure home ownership" do
      on(agent, "chown -R #{name} #{home}")
    end

    step "add ssh keys" do
      apply_manifest_on(agent, <<-MANIFEST, { :catch_failures => true, :debug => true }) do |result|
        ssh_authorized_key { '#{name}@example.com':
          ensure => present,
          user   => '#{name}',
          type   => 'ssh-rsa',
          key    => 'my-key'
        }
        MANIFEST
      end

      on(agent, "cat #{authorized_keys_path}") do |result|
        assert_match(/ssh-rsa my-key #{name}@example.com/, result.stdout)
      end
    end

    step "purge ssh keys" do
      apply_manifest_on(agent, <<-MANIFEST, { :catch_failures => true, :debug => true }) do |result|
          user {'#{name}':
            purge_ssh_keys => true
          }
        MANIFEST
      end

      on(agent, "cat #{authorized_keys_path}") do |result|
        assert_no_match(/ssh-rsa my-key #{name}@example.com/, result.stdout)
      end
    end

    step "add ssh keys" do
      apply_manifest_on(agent, <<-MANIFEST, { :catch_failures => true, :debug => true }) do |result|
        ssh_authorized_key { '#{name}@example.com':
          ensure => present,
          user   => '#{name}',
          type   => 'ssh-rsa',
          key    => 'my-key'
        }
        MANIFEST
      end

      on(agent, "cat #{authorized_keys_path}") do |result|
        assert_match(/ssh-rsa my-key #{name}@example.com/, result.stdout)
      end
    end

    step "purge ssh keys when purge_ssh_keys has relative path to home" do
      apply_manifest_on(agent, <<-MANIFEST, { :catch_failures => true, :debug => true }) do |result|
          user {'#{name}':
            purge_ssh_keys => '~/.ssh/authorized_keys'
          }
        MANIFEST

      end

      on(agent, "cat #{authorized_keys_path}") do |result|
        assert_no_match(/ssh-rsa my-key #{name}@example.com/, result.stdout)
      end
    end

    step "add ssh keys" do
      apply_manifest_on(agent, <<-MANIFEST, { :catch_failures => true, :debug => true }) do |result|
        ssh_authorized_key { '#{name}@example.com':
          ensure => present,
          user   => '#{name}',
          type   => 'ssh-rsa',
          key    => 'my-key'
        }
        MANIFEST
      end

      on(agent, "cat #{authorized_keys_path}") do |result|
        assert_match(/ssh-rsa my-key #{name}@example.com/, result.stdout)
      end
    end

    step "purge ssh keys when purge_ssh_keys has absolute path" do
      apply_manifest_on(agent, <<-MANIFEST, { :catch_failures => true, :debug => true }) do |result|
          user {'#{name}':
            purge_ssh_keys => '#{authorized_keys_path}'
          }
        MANIFEST
      end

      on(agent, "cat #{authorized_keys_path}") do |result|
        assert_no_match(/ssh-rsa my-key #{name}@example.com/, result.stdout)
      end
    end
  end
end
