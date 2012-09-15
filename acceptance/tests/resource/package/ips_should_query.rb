test_name "Package:IPS query"
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
  step "IPS: basic - it should create"
  apply_manifest_on(agent, 'package {mypkg : ensure=>"present"}') do
    assert_match( /ensure: created/, result.stdout, "err: #{agent}")
  end

  on agent, "puppet resource package mypkg" do
    assert_match( /0.0.1/, result.stdout, "err: #{agent}")
  end

  on agent, "puppet resource package" do
    assert_match( /0.0.1/, result.stdout, "err: #{agent}")
  end
end
