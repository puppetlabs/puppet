test_name "should modify a user without changing home directory (pending #19542)"

require 'puppet/acceptance/windows_utils'
extend Puppet::Acceptance::WindowsUtils

name = "pl#{rand(999999).to_i}"
pw = "Passwrd-#{rand(999999).to_i}"[0..11]

def get_home_dir(host, user_name)
  home_dir = nil
  on host, puppet_resource('user', user_name) do |result|
    home_dir = result.stdout.match(/home\s*=>\s*'([^']+)'/m)[1]
  end
  home_dir
end

agents.each do |agent|
  home_prop = nil
  case agent['platform']
  when /windows/
    home_prop = "home='#{profile_base(agent)}\\#{name}'"
  when /solaris/
    pending_test("managehome needs work on solaris")
  end

  teardown do
    step "delete the user"
    agent.user_absent(name)
    agent.group_absent(name)
  end

  step "ensure the user is present with managehome"
  on agent, puppet_resource('user', name, ["ensure=present", "managehome=true", "password=#{pw}", home_prop].compact)

  step "find the current home dir"
  home_dir = get_home_dir(agent, name)

  step "modify the user"
  on agent, puppet_resource('user', name, ["ensure=present", "managehome=true", "home='#{home_dir}_foo'"]) do |result|
    # SHOULD: user resource output should contain the new home directory
    pending_test "when #19542 is reimplemented correctly"
  end
  # SHOULD: old home directory should not exist in the filesystem
  # SHOULD: new home directory should exist in the filesystem
end
