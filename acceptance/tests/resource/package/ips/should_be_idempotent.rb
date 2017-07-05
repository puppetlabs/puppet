test_name "Package:IPS idempotency"
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

  step "IPS: it should create"
  apply_manifest_on(agent, 'package {mypkg : ensure=>present}') do
    assert_match( /ensure: created/, result.stdout, "err: #{agent}")
  end

  step "IPS: should be idempotent (present)"
  apply_manifest_on(agent, 'package {mypkg : ensure=>present}') do
    assert_no_match( /created/, result.stdout, "err: #{agent}")
    assert_no_match( /changed/, result.stdout, "err: #{agent}")
  end
  send_pkg agent, :pkg => 'mypkg@0.0.2'

  step "IPS: ask for latest version"
  apply_manifest_on(agent, 'package {mypkg : ensure=>latest}')

  step "IPS: ask for latest version again: should be idempotent (latest)"
  apply_manifest_on(agent, 'package {mypkg : ensure=>latest}') do
    assert_no_match( /created/, result.stdout, "err: #{agent}")
  end

  step "IPS: ask for specific version"
  send_pkg agent,:pkg => 'mypkg@0.0.3'
  apply_manifest_on(agent, 'package {mypkg : ensure=>"0.0.3"}') do
    assert_match( /changed/, result.stdout, "err: #{agent}")
  end

  step "IPS: ask for specific version again: should be idempotent (version)"
  apply_manifest_on(agent, 'package {mypkg : ensure=>"0.0.3"}') do
    assert_no_match( /created/, result.stdout, "err: #{agent}")
    assert_no_match( /changed/, result.stdout, "err: #{agent}")
  end

  step "IPS: ensure removed."
  apply_manifest_on(agent, 'package {mypkg : ensure=>absent}')
  on(agent, "pkg list -v mypkg", :acceptable_exit_codes => [1]) do
    assert_no_match( /mypkg/, result.stdout, "err: #{agent}")
  end

end
