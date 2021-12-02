test_name 'should correctly ensure resource and dependant user' do
  tag 'audit:high',
      'audit:acceptance'

  confine :to, :platform => /el-8-x86_64/

  agents.each do |agent|
    teardown do
      apply_manifest_on(agent, <<-MANIFEST) do |result|
        package { 'abrt':
          ensure => 'purged',
        }
        -> user { 'abrt':
          ensure => 'absent',
        }
        -> group { 'abrt':
          ensure => 'absent'
        }
        MANIFEST
      end
    end

    step "ensure desired state on package and desired information on dependant user and group" do
      apply_manifest_on(agent, <<-MANIFEST, { :catch_failures => true, :debug => true }) do |result|
        package { 'abrt':
          ensure => 'present',
        }
        -> group { 'abrt':
          ensure     => 'present',
          gid        => '59998',
          forcelocal => true,
        }
        -> user { 'abrt':
          ensure     => 'present',
          uid        => '59998',
          gid        => '59998',
          forcelocal => true,
        }
        MANIFEST
      end
    end
  end
end
