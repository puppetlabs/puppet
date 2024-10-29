# frozen_string_literal: true

test_name 'should create a user with password and modify the password' do

  tag 'audit:high',
      'audit:acceptance' # Could be done as integration tests, but would
  # require changing the system running the test
  # in ways that might require special permissions
  # or be harmful to the system running the test
  
  require 'puppet/acceptance/common_utils'
  extend Puppet::Acceptance::ManifestUtils

  name = "pl#{rand(999_999).to_i}"
  initial_password = 'test1'
  modified_password = 'test2'

  agents.each do |agent|
    teardown { agent.user_absent(name) }

    step 'ensure the user does not exist' do
      user_manifest = resource_manifest('user', name, { ensure: 'absent', provider: 'useradd' } )
      apply_manifest_on(agent, user_manifest) do |result|
        skip_test 'Useradd provider not present on this host' if result.stderr =~ /Provider useradd is not functional on this host/
      end
    end

    step 'create the user with password' do
      apply_manifest_on(agent, <<-MANIFEST, catch_failures: true)
          user { '#{name}':
            ensure => present,
            password => '#{initial_password}',
          }
        MANIFEST
    end

    step 'verify the password was set correctly' do
      on(agent, puppet('resource', 'user', name), acceptable_exit_codes: 0) do |result|
        assert_match(/password\s*=>\s*'#{initial_password}'/, result.stdout, 'Password was not set correctly')
      end
    end

    step 'modify the user with a different password' do
      # There is a known issue with SSSD and Red Hat 8, this is a temporary workaround until a permanent fix is
      # implemented in our images. See ITHELP-100250
      # https://access.redhat.com/solutions/7031304
      if agent['platform'] == 'el-8-ppc64le'
        on(agent, 'systemctl stop sssd; rm -f /var/lib/sss/db/*; systemctl start sssd', acceptable_exit_codes: 0)
      end

      apply_manifest_on(agent, <<-MANIFEST, catch_failures: true)
	    user { '#{name}':
	      ensure => present,
	      password => '#{modified_password}',
	    }
	MANIFEST
    end

    step 'verify the password was set correctly' do
      on(agent, "puppet resource user #{name}", acceptable_exit_codes: 0) do |result|
        assert_match(/password\s*=>\s*'#{modified_password}'/, result.stdout, 'Password was not changed correctly')
      end
    end

    step 'Verify idempotency when setting the same password' do
      apply_manifest_on(agent, <<-MANIFEST, expect_changes: false)
	    user { '#{name}':
	      ensure => present,
	      password => '#{modified_password}',
	    }
	MANIFEST
    end
  end
end
