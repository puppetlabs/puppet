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
  step "IPS: clean slate"
  clean agent
  step "IPS: setup"
  setup agent
  setup_fakeroot agent
  send_pkg agent, :pkg => 'mypkg@0.0.1'
  set_publisher agent
  step "IPS: basic - it should create"
  apply_manifest_on(agent, 'package {mypkg : ensure=>present}') do
    assert_match( /ensure: created/, result.stdout, "err: #{agent}")
  end
  step "IPS: check it was created"
  on(agent, puppet("resource package mypkg")) do
    assert_match( /ensure => '0\.0\.1,.*'/, result.stdout, "err: #{agent}")
  end
  on agent, "pkg list -v mypkg" do
    assert_match( /mypkg@0.0.1/, result.stdout, "err: #{agent}")
  end
end
