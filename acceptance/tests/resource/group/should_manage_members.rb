test_name "should correctly manage the members property for the Group resource" do
  # These are the only platforms whose group providers manage the members
  # property
  confine :to, :platform => /windows|osx|aix|^el-|fedora/

  tag 'audit:high',
      'audit:acceptance' # Could be done as integration tests, but would
                         # require changing the system running the test
                         # in ways that might require special permissions
                         # or be harmful to the system running the test

  require 'puppet/acceptance/common_utils'
  extend Puppet::Acceptance::BeakerUtils

  def random_name
    "pl#{rand(999999).to_i}"
  end

  def group_manifest(user, params)
    params_str = params.map do |param, value|
      value_str = value.to_s
      value_str = "\"#{value_str}\"" if value.is_a?(String)

      "  #{param} => #{value_str}"
    end.join(",\n")

    <<-MANIFEST
group { '#{user}':
  #{params_str}
}
MANIFEST
  end

  def members_of(host, group)
    case host['platform']
    when /windows/
      # More verbose than 'net localgroup <group>', but more programmatic
      # because it does not require us to parse stdout
      get_group_members = <<-PS1
# Adapted from https://github.com/RamblingCookieMonster/PowerShell/blob/master/Get-ADGroupMembers.ps1
function Get-Members([string] $group) {
  $ErrorActionPreference = 'Stop'

  Add-Type -AssemblyName 'System.DirectoryServices.AccountManagement' -ErrorAction Stop
  $contextType = [System.DirectoryServices.AccountManagement.ContextType]::Machine
  $groupObject = [System.DirectoryServices.AccountManagement.GroupPrincipal]::FindByIdentity(
    $contextType,
    $group
  )

  if (-Not $groupObject) {
    throw "Could not find the group '$group'!"
  }

  $members = $groupObject.GetMembers($false) | ForEach-Object { "'$($_.Name)'" }
  write-output "[$([string]::join(',', $members))]"
}

Get-Members #{group}
PS1
      Kernel.eval(
        execute_powershell_script_on(host, get_group_members).stdout.chomp 
      )
    else
      # This reads the group members from the /etc/group file
      get_group_members = <<-RUBY
require 'etc'

group_struct = nil
Etc.group do |g|
  if g.name == '#{group}'
    group_struct = g
    break
  end
end

unless group_struct
  raise "Could not find the group '#{group}'!"
end

puts(group_struct.mem.to_s)
RUBY

      script_path = "#{host.tmpfile("get_group_members")}.rb"
      create_remote_file(host, script_path, get_group_members)

      # The setup step should have already set :privatebindir on the
      # host. We only include the default here to make this routine
      # work for local testing, which sometimes skips the setup step.
      privatebindir = host.has_key?(:privatebindir) ? host[:privatebindir] : '/opt/puppetlabs/puppet/bin'

      result = on(host, "#{privatebindir}/ruby #{script_path}")
      Kernel.eval(result.stdout.chomp)
    end
  end

  agents.each do |agent|
    users = 6.times.collect { random_name }
    users.each { |user| agent.user_absent(user) }

    group = random_name
    agent.group_absent(group)
    teardown { agent.group_absent(group) }

    step 'Creating the Users' do
      users.each do |user|
        agent.user_present(user)
        teardown { agent.user_absent(user) }
      end
    end

    group_members = [users[0], users[1]]

    step 'Ensure that the group is created with the specified members' do
      manifest = group_manifest(group, members: group_members)
      apply_manifest_on(agent, manifest)
      assert_matching_arrays(group_members, members_of(agent, group), "The group was not successfully created with the specified members!")
    end

    step "Verify that Puppet errors when one of the members does not exist" do
      manifest = group_manifest(group, members: ['nonexistent_member'])
      apply_manifest_on(agent, manifest, :acceptable_exit_codes => [0, 1]) do |result|
        assert_match(/Error:.*#{group}/, result.stderr, "Puppet fails to report an error when one of the members in the members property does not exist")
      end
    end

    step "Verify that Puppet noops when the group's members are already set after creating the group" do
      manifest = group_manifest(group, members: group_members)
      apply_manifest_on(agent, manifest, catch_changes: true)
      assert_matching_arrays(group_members, members_of(agent, group), "The group's members somehow changed despite Puppet reporting a noop")
    end

    step "Verify that Puppet enforces minimum user membership when auth_membership == false" do
      new_members = [users[2], users[4]]

      manifest = group_manifest(group, members: new_members, auth_membership: false)
      apply_manifest_on(agent, manifest)

      group_members += new_members
      assert_matching_arrays(group_members, members_of(agent, group), "Puppet fails to enforce minimum user membership when auth_membership == false")
    end

    step "Verify that Puppet noops when the group's members are already set after enforcing minimum user membership" do
      manifest = group_manifest(group, members: group_members)
      apply_manifest_on(agent, manifest, catch_changes: true)
      assert_matching_arrays(group_members, members_of(agent, group), "The group's members somehow changed despite Puppet reporting a noop")
    end

    # Run some special, platform-specific tests. If these get too large, then
    # we should consider placing them in a separate file.
    case agent['platform']
    when /windows/
      domain = on(agent, 'hostname').stdout.chomp.upcase

      step "(Windows) Verify that Puppet prints each group member as DOMAIN\\<user>" do
        new_members = [users[3]]

        manifest = group_manifest(group, members: new_members, auth_membership: false)
        apply_manifest_on(agent, manifest) do |result|
          group_members += new_members

          stdout = result.stdout.chomp

          group_members.each do |user|
            assert_match(/#{domain}\\#{user}/, stdout, "Puppet fails to print the group member #{user} as #{domain}\\#{user}")
          end
        end
      end

      step "(Windows) Verify that `puppet resource` prints each group member as DOMAIN\\<user>" do
        on(agent, puppet('resource', 'group', group)) do |result|
          stdout = result.stdout.chomp

          group_members.each do |user|
            assert_match(/#{domain}\\#{user}/, stdout, "`puppet resource` fails to print the group member #{user} as #{domain}\\#{user}")
          end
        end
      end
    when /aix/
      step "(AIX) Verify that Puppet accepts a comma-separated list of members for backwards compatibility" do
        new_members = [users[3], users[5]]

        manifest = group_manifest(group, members: new_members.join(','), auth_membership: false)
        apply_manifest_on(agent, manifest)

        group_members += new_members
        assert_matching_arrays(group_members, members_of(agent, group), "Puppet cannot manage the members property when the members are provided as a comma-separated list")
      end
    end

    step "Verify that Puppet enforces inclusive user membership when auth_membership == true" do
      group_members = [users[0]]

      manifest = group_manifest(group, members: group_members, auth_membership: true)
      apply_manifest_on(agent, manifest)
      assert_matching_arrays(group_members, members_of(agent, group), "Puppet fails to enforce inclusive group membership when auth_membership == true")
    end

    step "Verify that Puppet noops when the group's members are already set after enforcing inclusive user membership" do
      manifest = group_manifest(group, members: group_members)
      apply_manifest_on(agent, manifest, catch_changes: true)
      assert_matching_arrays(group_members, members_of(agent, group), "The group's members somehow changed despite Puppet reporting a noop")
    end
  end
end
