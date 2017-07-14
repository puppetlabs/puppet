test_name "ZFS: configuration"
confine :to, :platform => 'solaris'

tag 'audit:medium',
    'audit:refactor',  # Use block style `test_name`
    'audit:acceptance' # Could be done as integration tests, but would
                       # require drastically changing the system running the test

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
  step "ZFS: create with a mount point"
  apply_manifest_on(agent, 'zfs {"tstpool/tstfs": ensure=>present,  mountpoint=>"/ztstpool/mnt"}') do
    assert_match( /ensure: created/, result.stdout, "err: #{agent}")
  end

  step "ZFS: idempotence - create"
  apply_manifest_on(agent, 'zfs {"tstpool/tstfs": ensure=>present}') do
    assert_no_match( /ensure: created/, result.stdout, "err: #{agent}")
  end

  step "ZFS: change mount point and verify"
  apply_manifest_on(agent, 'zfs {"tstpool/tstfs": ensure=>present,  mountpoint=>"/ztstpool/mnt2"}') do
    assert_match( /mountpoint changed '.ztstpool.mnt'.* to '.ztstpool.mnt2'/, result.stdout, "err: #{agent}")
  end

  step "ZFS: change mount point and verify idempotence"
  apply_manifest_on(agent, 'zfs {"tstpool/tstfs": ensure=>present,  mountpoint=>"/ztstpool/mnt2"}') do
    assert_no_match( /changed/, result.stdout, "err: #{agent}")
  end
end
