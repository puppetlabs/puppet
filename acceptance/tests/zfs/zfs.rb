test_name "ZFS: configuration"
confine :to, :platform => 'solaris'

require 'puppet/acceptance/solaris_util'
extend Puppet::Acceptance::ZFSUtils

teardown do
  agents.each do |agent|
    clean agent
  end
end


agents.each do |agent|
  clean agent
  setup agent
  #-----------------------------------
  apply_manifest_on(agent, 'zfs { "tstpool/tstfs": ensure=>absent}') do
    assert_match( /Finished catalog run in .*/, result.stdout, "err: #{agent}")
  end
  apply_manifest_on(agent, 'zfs {"tstpool/tstfs": ensure=>present}') do
    assert_match( /ensure: created/, result.stdout, "err: #{agent}")
  end
  apply_manifest_on(agent, 'zfs {"tstpool/tstfs": ensure=>present}') do
    assert_no_match( /ensure: created/, result.stdout, "err: #{agent}")
  end

  apply_manifest_on(agent, 'zfs {"tstpool/tstfs": ensure=>absent}') do
    assert_match( /ensure: removed/, result.stdout, "err: #{agent}")
  end

  apply_manifest_on(agent, 'zfs {"tstpool/tstfs": ensure=>present,  mountpoint=>"/ztstpool/mnt"}') do
    assert_match( /ensure: created/, result.stdout, "err: #{agent}")
  end

  apply_manifest_on(agent, 'zfs {"tstpool/tstfs": ensure=>present,  mountpoint=>"/ztstpool/mnt2"}') do
    assert_match( /mountpoint changed '.ztstpool.mnt' to '.ztstpool.mnt2'/, result.stdout, "err: #{agent}")
  end
end
