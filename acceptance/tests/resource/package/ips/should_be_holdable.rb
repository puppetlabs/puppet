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
    clean agent, :pkg => 'mypkg2'
    clean agent, :pkg => 'mypkg'
  end
end


agents.each do |agent|
  step "IPS: setup"
  setup agent
  setup_fakeroot agent
  send_pkg agent, :pkg => 'mypkg@0.0.1'
  setup_fakeroot2 agent
  send_pkg2 agent, :pkg => 'mypkg2@0.0.1'
  set_publisher agent
  step "IPS: basic - it should create a specific version and install dependent package"
  apply_manifest_on(agent, 'package {mypkg2 : ensure=>"0.0.1"}') do
    assert_match( /ensure: created/, result.stdout, "err: #{agent}")
  end
  on agent, "pkg list -v mypkg" do
    assert_match( /mypkg@0.0.1/, result.stdout, "err: #{agent}")
  end
  on agent, "pkg list -v mypkg2" do
    assert_match( /mypkg2@0.0.1/, result.stdout, "err: #{agent}")
  end

  step "IPS: it should upgrade current and dependent package"
  setup_fakeroot agent
  send_pkg agent, :pkg => 'mypkg@0.0.2'
  setup_fakeroot2 agent
  send_pkg2 agent, :pkg => 'mypkg2@0.0.2', :pkgdep => 'mypkg@0.0.2'
  apply_manifest_on(agent, 'package {mypkg2 : ensure=>"0.0.2"}') do
    assert_match( /changed/, result.stdout, "err: #{agent}")
  end
  on agent, "pkg list -v mypkg" do
    assert_match( /mypkg@0.0.2/, result.stdout, "err: #{agent}")
  end
  on agent, "pkg list -v mypkg2" do
    assert_match( /mypkg2@0.0.2/, result.stdout, "err: #{agent}")
  end

  step "IPS: it should not upgrade current and dependent package if dependent package is held"
  apply_manifest_on(agent, 'package {mypkg : ensure=>"held", provider=>"pkg"}') do
    assert_match( //, result.stdout, "err: #{agent}")
  end
  setup_fakeroot agent
  send_pkg agent, :pkg => 'mypkg@0.0.3'
  setup_fakeroot2 agent
  send_pkg2 agent, :pkg => 'mypkg2@0.0.3', :pkgdep => 'mypkg@0.0.3'
  apply_manifest_on(agent, 'package {mypkg2 : ensure=>"0.0.2"}') do
    assert_no_match( /changed/, result.stdout, "err: #{agent}")
  end
  on agent, "pkg list -v mypkg" do
    assert_match( /mypkg@0.0.2/, result.stdout, "err: #{agent}")
  end
  on agent, "pkg list -v mypkg2" do
    assert_match( /mypkg2@0.0.2/, result.stdout, "err: #{agent}")
  end

  step "IPS: it should upgrade if hold was released."
  apply_manifest_on(agent, 'package {mypkg : ensure=>"0.0.3", provider=>"pkg"}') do
    assert_match( //, result.stdout, "err: #{agent}")
  end
  apply_manifest_on(agent, 'package {mypkg2 : ensure=>"0.0.3"}') do
    assert_match( /changed/, result.stdout, "err: #{agent}")
  end
  on agent, "pkg list -v mypkg" do
    assert_match( /mypkg@0.0.3/, result.stdout, "err: #{agent}")
  end
  on agent, "pkg list -v mypkg2" do
    assert_match( /mypkg2@0.0.3/, result.stdout, "err: #{agent}")
  end
end
