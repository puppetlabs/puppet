test_name "Package:IPS basic tests"
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
  step "IPS: clean slate"
  clean agent
  step "IPS: setup"
  setup agent
  setup_fakeroot agent
  send_pkg agent, :pkg => 'mypkg@0.0.1'
  set_publisher agent
  step "IPS: basic making_sure we are clean"
  apply_manifest_on(agent, 'package {mypkg : making_sure=>absent}') do
    assert_match( /Finished catalog run in .*/, result.stdout, "err: #{agent}")
  end
  step "IPS: basic - it should create"
  apply_manifest_on(agent, 'package {mypkg : making_sure=>present}') do
    assert_match( /making_sure: created/, result.stdout, "err: #{agent}")
  end
  step "IPS: check it was created"
  on agent, "puppet resource package mypkg" do
    assert_match( /making_sure => '0.0.1'/, result.stdout, "err: #{agent}")
  end
  step "IPS: do not upgrade until latest is mentioned"
  send_pkg agent,:pkg => 'mypkg@0.0.2'
  apply_manifest_on(agent, 'package {mypkg : making_sure=>present}') do
    assert_no_match( /making_sure: created/, result.stdout, "err: #{agent}")
  end
  step "IPS: verify it was not upgraded"
  on agent, "puppet resource package mypkg" do
    assert_match( /making_sure => '0.0.1'/, result.stdout, "err: #{agent}")
  end
  step "IPS: ask to be latest"
  apply_manifest_on(agent, 'package {mypkg : making_sure=>latest}') do
    assert_match( /Finished catalog run in .*/, result.stdout, "err: #{agent}")
  end
  step "IPS: making_sure it was upgraded"
  on agent, "puppet resource package mypkg" do
    assert_match( /making_sure => '0.0.2'/, result.stdout, "err: #{agent}")
  end

  step "IPS: when there are more than one option, choose latest."
  send_pkg agent,:pkg => 'mypkg@0.0.3'
  send_pkg agent,:pkg => 'mypkg@0.0.4'
  apply_manifest_on(agent, 'package {mypkg : making_sure=>latest}') do
    assert_match( /Finished catalog run in .*/, result.stdout, "err: #{agent}")
  end
  on agent, "puppet resource package mypkg" do
    assert_match( /making_sure => '0.0.4'/, result.stdout, "err: #{agent}")
  end

  step "IPS: making_sure removed."
  apply_manifest_on(agent, 'package {mypkg : making_sure=>absent}') do
    assert_match( /Finished catalog run in .*/, result.stdout, "err: #{agent}")
  end
end
