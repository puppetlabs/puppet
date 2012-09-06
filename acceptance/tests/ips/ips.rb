test_name "Zone:IPS configuration"
confine :to, :platform => 'solaris'

require 'puppet/acceptance/solaris_util'
extend Puppet::Acceptance::IPSUtils

teardown do
  agents.each do |agent|
    clean agent
  end
end


agents.each do |agent|
  clean agent
  setup agent
  setup_fakeroot agent
  send_pkg agent, :pkg => 'mypkg@0.0.1'
  set_publisher agent
  apply_manifest_on(agent, 'package {mypkg : ensure=>absent}') do
    assert_match( /Finished catalog run in .*/, result.stdout, "err: #{agent}")
  end
  apply_manifest_on(agent, 'package {mypkg : ensure=>present}') do
    assert_match( /ensure: created/, result.stdout, "err: #{agent}")
  end
  on agent, "puppet resource package mypkg" do
    assert_match( /ensure => '0.0.1'/, result.stdout, "err: #{agent}")
  end
  # Do not upgrade until latest is mentioned
  send_pkg agent,:pkg => 'mypkg@0.0.2'
  apply_manifest_on(agent, 'package {mypkg : ensure=>present}') do
    assert_no_match( /ensure: created/, result.stdout, "err: #{agent}")
  end
  on agent, "puppet resource package mypkg" do
    assert_match( /ensure => '0.0.1'/, result.stdout, "err: #{agent}")
  end
  apply_manifest_on(agent, 'package {mypkg : ensure=>latest}') do
    assert_match( /Finished catalog run in .*/, result.stdout, "err: #{agent}")
  end
  on agent, "puppet resource package mypkg" do
    assert_match( /ensure => '0.0.2'/, result.stdout, "err: #{agent}")
  end

  # When there are more than one option, choose latest.
  send_pkg agent,:pkg => 'mypkg@0.0.3'
  send_pkg agent,:pkg => 'mypkg@0.0.4'
  apply_manifest_on(agent, 'package {mypkg : ensure=>latest}') do
    assert_match( /Finished catalog run in .*/, result.stdout, "err: #{agent}")
  end
  on agent, "puppet resource package mypkg" do
    assert_match( /ensure => '0.0.4'/, result.stdout, "err: #{agent}")
  end
end
