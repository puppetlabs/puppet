test_name "Package:IPS versionable"
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
  send_pkg agent, :pkg => 'mypkg@0.0.2'
  set_publisher agent
  step "IPS: basic - it should create a specific version"
  apply_manifest_on(agent, 'package {mypkg : ensure=>"0.0.1"}') do
    assert_match( /ensure: created/, result.stdout, "err: #{agent}")
  end
  on agent, "pkg list mypkg" do
    assert_match( /0.0.1/, result.stdout, "err: #{agent}")
  end

  step "IPS: it should upgrade if asked for next version"
  apply_manifest_on(agent, 'package {mypkg : ensure=>"0.0.2"}') do
    assert_match( /ensure changed/, result.stdout, "err: #{agent}")
  end
  on agent, "pkg list mypkg" do
    assert_no_match( /0.0.1/, result.stdout, "err: #{agent}")
    assert_match( /0.0.2/, result.stdout, "err: #{agent}")
  end
  step "IPS: it should downpgrade if asked for previous version"
  apply_manifest_on(agent, 'package {mypkg : ensure=>"0.0.1"}') do
    assert_match( /ensure changed/, result.stdout, "err: #{agent}")
  end
  on agent, "pkg list mypkg" do
    assert_no_match( /0.0.2/, result.stdout, "err: #{agent}")
    assert_match( /0.0.1/, result.stdout, "err: #{agent}")
  end
end
