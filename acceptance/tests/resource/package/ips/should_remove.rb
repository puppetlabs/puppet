test_name "Package:IPS basic tests"
confine :to, :platform => 'solaris-11'

tag 'audit:medium',
    'audit:refactor',  # Use block style `test_name`
    'audit:acceptance' # Could be done at the integration (or unit) layer though
                       # actual changing of resources could irreparably damage a
                       # host running this, or require special permissions.

require 'puppet/acceptance/solaris_util'
extend Puppet::Acceptance::IPSUtils

teardown do
  step "cleanup"
  agents.each do |agent|
    clean agent
  end
end


agents.each do |agent|
  step "IPS: setup"
  setup agent
  setup_fakeroot agent
  send_pkg agent, :pkg => 'mypkg@0.0.1'
  set_publisher agent
  on agent, "pkg install mypkg"
  on agent, "pkg list -v mypkg" do
    assert_match( /mypkg@0.0.1/, result.stdout, "err: #{agent}")
  end

  step "IPS: ensure removed."
  apply_manifest_on(agent, 'package {mypkg : ensure=>absent}')

  on(agent, "pkg list -v mypkg", :acceptable_exit_codes => [1]) do
    assert_no_match( /mypkg@0.0.1/, result.stdout, "err: #{agent}")
  end

end
