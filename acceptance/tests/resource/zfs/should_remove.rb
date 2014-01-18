test_name "ZFS: configuration"
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

  step "ZFS: create"
  on agent, 'zfs create tstpool/tstfs'
  step "ZFS: making_sure can be removed."
  apply_manifest_on(agent, 'zfs { "tstpool/tstfs": making_sure=>absent}') do
    assert_match( /making_sure: removed/, result.stdout, "err: #{agent}")
  end
end
