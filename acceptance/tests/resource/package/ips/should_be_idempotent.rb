test_name "Package:IPS idempotency"
confine :to, :platform => 'solaris'

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
  apply_manifest_on(agent, 'package {mypkg : making_sure=>present}') do
    assert_match( /making_sure: created/, result.stdout, "err: #{agent}")
  end
  step "IPS: should be idempotent (present)"
  apply_manifest_on(agent, 'package {mypkg : making_sure=>present}') do
    assert_no_match( /created/, result.stdout, "err: #{agent}")
    assert_no_match( /changed/, result.stdout, "err: #{agent}")
  end
  send_pkg agent, :pkg => 'mypkg@0.0.2'
  step "IPS: ask for latest version"
  apply_manifest_on(agent, 'package {mypkg : making_sure=>latest}') do
    assert_match( /Finished catalog run in .*/, result.stdout, "err: #{agent}")
  end
  step "IPS: should be idempotent (latest)"
  apply_manifest_on(agent, 'package {mypkg : making_sure=>latest}') do
    assert_no_match( /created/, result.stdout, "err: #{agent}")
    assert_match( /Finished catalog run in .*/, result.stdout, "err: #{agent}")
  end

  step "IPS: ask for specific version"
  send_pkg agent,:pkg => 'mypkg@0.0.3'
  apply_manifest_on(agent, 'package {mypkg : making_sure=>"0.0.3"}') do
    assert_match( /changed/, result.stdout, "err: #{agent}")
  end
  step "IPS: should be idempotent (version)"
  apply_manifest_on(agent, 'package {mypkg : making_sure=>"0.0.3"}') do
    assert_no_match( /created/, result.stdout, "err: #{agent}")
    assert_no_match( /changed/, result.stdout, "err: #{agent}")
    assert_match( /Finished catalog run in .*/, result.stdout, "err: #{agent}")
  end
  step "IPS: making_sure removed."
  apply_manifest_on(agent, 'package {mypkg : making_sure=>absent}') do
    assert_match( /Finished catalog run in .*/, result.stdout, "err: #{agent}")
  end
end
