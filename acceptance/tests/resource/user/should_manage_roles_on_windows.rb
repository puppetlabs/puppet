test_name "Manage roles for a Windows user" do
  confine :to, :platform => 'windows'

  tag 'audit:high',
      'audit:acceptance'

  require 'puppet/acceptance/windows_utils'
  extend Puppet::Acceptance::WindowsUtils

  def user_manifest(name, params)
    params_str = params.map do |param, value|
      value_str = value.to_s
      value_str = "\"#{value_str}\"" if value.is_a?(String)

      "  #{param} => #{value_str}"
    end.join(",\n")

    <<-MANIFEST
user { '#{name}':
  #{params_str}
}
MANIFEST
  end

  newUser = "tempUser#{rand(999999).to_i}"

  teardown do
    on(agent, puppet("resource user #{newUser} ensure=absent")) do |result|
      assert_match(/User\[#{newUser}\]\/ensure: removed/, result.stdout)
    end
  end

  agents.each do |agent|
    step "Create a new user named #{newUser}" do
      apply_manifest_on(agent, user_manifest(newUser, ensure: :present), expect_changes: true) do |result|
        assert_match(/User\[#{newUser}\]\/ensure: created/, result.stdout)
      end
    end

    step "Verify that a new user has no roles" do
      on(agent, puppet("resource user #{newUser}")) do |result|
        assert_no_match(/roles\s+=>/, result.stdout)
      end
    end

    step "Verify that puppet can grant #{newUser} a right" do
      apply_manifest_on(agent, user_manifest(newUser, roles: ['SeServiceLogonRight']), expect_changes: true) do |result|
        assert_match(/User\[#{newUser}\]\/roles: roles changed  to 'SeServiceLogonRight'/, result.stdout)
      end
    end

    step "Verify that puppet can grant #{newUser} a privilege also" do
      apply_manifest_on(agent, user_manifest(newUser, roles: ['SeBackupPrivilege']), expect_changes: true) do |result|
        assert_match(/User\[#{newUser}\]\/roles: roles changed SeServiceLogonRight to 'SeBackupPrivilege,SeServiceLogonRight'/, result.stdout)
      end
    end

    step "Verify that puppet can not grant #{newUser} an invalid role" do
      apply_manifest_on(agent, user_manifest(newUser, roles: ['InvalidRoleName']), :acceptable_exit_codes => [4], catch_changes: true) do |result|
        assert_match(/Calling `LsaAddAccountRights` returned 'Win32 Error Code 0x00000521'. One or more of the given rights\/privilleges are incorrect./, result.stderr)
      end
    end

    step "Verify that puppet can remove all of #{newUser}'s roles when managing :roles as an empty array and :role_membership as inclusive" do
      apply_manifest_on(agent, user_manifest(newUser, roles: [], role_membership: :inclusive), expect_changes: true) do |result|
        assert_match(/User\[#{newUser}\]\/roles: roles changed SeBackupPrivilege,SeServiceLogonRight to ''/, result.stdout)
      end
    end

    step "Verify that puppet can grant #{newUser} more than one right at the same time" do
      apply_manifest_on(agent, user_manifest(newUser, roles: ['SeDenyServiceLogonRight', 'SeDenyBatchLogonRight']), expect_changes: true) do |result|
        assert_match(/User\[#{newUser}\]\/roles: roles changed  to 'SeDenyBatchLogonRight,SeDenyServiceLogonRight'/, result.stdout)
      end
    end

    step "Verify that :role_membership managed as minimum just appends given role to existing ones" do
      apply_manifest_on(agent, user_manifest(newUser, roles: ['SeBackupPrivilege'], role_membership: :minimum), expect_changes: true) do |result|
        assert_match(/User\[#{newUser}\]\/roles: roles changed SeDenyServiceLogonRight,SeDenyBatchLogonRight to 'SeBackupPrivilege,SeDenyBatchLogonRight,SeDenyServiceLogonRight'/, result.stdout)
      end
    end

    step "Verify that :roles noops when #{newUser} already has given role while managing :role_membership as minimum" do
      apply_manifest_on(agent, user_manifest(newUser, roles: ['SeBackupPrivilege'], role_membership: :minimum), catch_changes: true) do |result|
        assert_no_match(/User\[#{newUser}\]\/roles: roles changed/, result.stdout)
      end
    end

    step "Verify that while not managing :role_membership, the behaviour remains the same, with noop from :roles when #{newUser} already has the given role" do
      apply_manifest_on(agent, user_manifest(newUser, roles: ['SeBackupPrivilege']), catch_changes: true) do |result|
        assert_no_match(/User\[#{newUser}\]\/roles: roles changed/, result.stdout)
      end
    end

    step "Verify that while managing :role_membership as inclusive, #{newUser} remains only with the given roles" do
      apply_manifest_on(agent, user_manifest(newUser, roles: ['SeBackupPrivilege', 'SeServiceLogonRight'], role_membership: :inclusive), expect_changes: true) do |result|
        assert_match(/User\[#{newUser}\]\/roles: roles changed SeBackupPrivilege,SeDenyServiceLogonRight,SeDenyBatchLogonRight to 'SeBackupPrivilege,SeServiceLogonRight'/, result.stdout)
      end
    end
  end
end
