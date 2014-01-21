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
  step "ZFS: cleanup"
  clean agent
  step "ZFS: setup"
  setup agent
  step "ZFS: making_sure clean slate"
  apply_manifest_on(agent, 'zfs { "tstpool/tstfs": making_sure=>absent}') do
    assert_match( /Finished catalog run in .*/, result.stdout, "err: #{agent}")
  end
  step "ZFS: basic - making_sure it is created"
  apply_manifest_on(agent, 'zfs {"tstpool/tstfs": making_sure=>present}') do
    assert_match( /making_sure: created/, result.stdout, "err: #{agent}")
  end
  step "ZFS: idempotence - create"
  apply_manifest_on(agent, 'zfs {"tstpool/tstfs": making_sure=>present}') do
    assert_no_match( /making_sure: created/, result.stdout, "err: #{agent}")
  end

  step "ZFS: cleanup for next test"
  apply_manifest_on(agent, 'zfs {"tstpool/tstfs": making_sure=>absent}') do
    assert_match( /making_sure: removed/, result.stdout, "err: #{agent}")
  end

  step "ZFS: create with a mount point"
  apply_manifest_on(agent, 'zfs {"tstpool/tstfs": making_sure=>present,  mountpoint=>"/ztstpool/mnt"}') do
    assert_match( /making_sure: created/, result.stdout, "err: #{agent}")
  end

  step "ZFS: change mount point and verify"
  apply_manifest_on(agent, 'zfs {"tstpool/tstfs": making_sure=>present,  mountpoint=>"/ztstpool/mnt2"}') do
    assert_match( /mountpoint changed '.ztstpool.mnt' to '.ztstpool.mnt2'/, result.stdout, "err: #{agent}")
  end

  step "ZFS: making_sure can be removed."
  apply_manifest_on(agent, 'zfs { "tstpool/tstfs": making_sure=>absent}') do
    assert_match( /making_sure: removed/, result.stdout, "err: #{agent}")
  end

end
