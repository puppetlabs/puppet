test_name "ZFS: should create"
confine :to, :platform => 'solaris'

require 'puppet/acceptance/solaris_util'
extend Puppet::Acceptance::ZFSUtils

teardown do
  step "ZFS: cleanup"
  agents.each do |agent|
    clean agent
  end
end


agents.each do |agent|
  step "ZFS: setup"
  setup agent
  step "ZFS: making_sure it is created"
  apply_manifest_on(agent, 'zfs {"tstpool/tstfs": making_sure=>present}') do
    assert_match( /making_sure: created/, result.stdout, "err: #{agent}")
  end
  step "verify"
  on(agent, 'zfs list') do
    assert_match( /tstpool.tstfs/, result.stdout, "err: #{agent}")
  end
end
