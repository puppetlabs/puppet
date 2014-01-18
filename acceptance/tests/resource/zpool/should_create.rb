test_name "ZPool: configuration"
confine :to, :platform => 'solaris'

require 'puppet/acceptance/solaris_util'
extend Puppet::Acceptance::ZPoolUtils

teardown do
  step "ZPool: cleanup"
  agents.each do |agent|
    clean agent
  end
end


agents.each do |agent|
  step "ZPool: setup"
  setup agent
  #-----------------------------------
  step "ZPool: making_sure create"
  apply_manifest_on(agent, "zpool{ tstpool: making_sure=>present, disk=>'/ztstpool/dsk1' }") do
    assert_match( /making_sure: created/, result.stdout, "err: #{agent}")
  end
  on(agent, "zpool list") do
    assert_match( /tstpool/, result.stdout, "err: #{agent}")
  end
end
