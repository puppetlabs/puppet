test_name "should modify a user when no longer managing home (#20726)"
confine :except, :platform => /^eos-/ # See ARISTA-37
confine :except, :platform => /^cisco_/ # See PUP-5828
tag 'audit:medium',
    'audit:refactor',  # Use block style `test_run`
    'audit:acceptance' # Could be done as integration tests, but would
                       # require changing the system running the test
                       # in ways that might require special permissions
                       # or be harmful to the system running the test

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
    # Sadly Windows ADSI won't tell us the default home directory
    # for a user. You can get it via WMI Win32_UserProfile, but that
    # doesn't exist in a base 2003 install. So we simply specify an
    # initial home directory, that matches what the default will be.
    # This way we are guaranteed that `puppet resource user name`
    # will include the home directory in its output.
    home_prop = "home='#{profile_base(agent)}\\#{name}'"
  when /solaris/
    pending_test("managehome needs work on solaris")
  when /osx/
    skip_test("OSX doesn't support managehome")
    # we don't get here
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
  on agent, "test -d '#{home_dir}'"

  step "modify the user"
  new_home_dir = "#{home_dir}_foo"
  on agent, puppet_resource('user', name, ["ensure=present", "home='#{new_home_dir}'"]) do |result|
    found_home_dir = result.stdout.match(/home\s*=>\s*'([^']+)'/m)[1]
    assert_equal new_home_dir, found_home_dir, "Failed to change home property of user"
  end

  step "verify that home directory still exists since we did not specify managehome"
  on agent, "test -d '#{home_dir}'"
end
