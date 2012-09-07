test_name "Zone:Path configuration"
confine :to, :platform => 'solaris'

require 'puppet/acceptance/solaris_util'
extend Puppet::Acceptance::ZoneUtils

def moresetup(agent)
  on agent, "mkdir /tstzones/mnt2"
  on agent, "zfs create -o mountpoint=/tstzones/mnt2 tstpool/tstfs2"
end

def moreclean(agent)
  on agent, "zfs destroy -r tstpool/tstfs2 || :"
end


teardown do
  agents.each do |agent|
    moreclean agent
    clean agent
  end
end


agents.each do |agent|
  clean agent
  setup agent
  moresetup agent
  #-----------------------------------
  # Make sure that the zone is absent.
  apply_manifest_on(agent, 'zone {tstzone : ensure=>absent}') do
    assert_match( /Finished catalog run in .*/, result.stdout, "err: #{agent}")
  end

  # Should require path
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>shared }') do
    assert_match( /Error: Path is required/, result.output, "err: #{agent}")
  end

  # Should create zone if path is given.
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>shared, path=>"/tstzones/mnt" }') do
    assert_match( /ensure: created/, result.stdout, "err: #{agent}")
  end

  # idempotency: should not create again.
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>shared, path=>"/tstzones/mnt" }') do
    assert_no_match( /ensure: created/, result.stdout, "err: #{agent}")
  end

  # should change the path if it is switched before install
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>shared, path=>"/tstzones/mnt2" }') do
    assert_match(/path changed '.tstzones.mnt' to '.tstzones.mnt2'/, result.stdout, "err: #{agent}")
  end

  # idempotency: should not change the path again
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>shared, path=>"/tstzones/mnt2" }') do
    assert_no_match(/path changed '.tstzones.mnt' to '.tstzones.mnt2'/, result.stdout, "err: #{agent}")
  end

  # dont trust puppet.
  on agent,"/usr/sbin/zonecfg -z tstzone export" do
    assert_match(/set zonepath=.*mnt2/, result.stdout, "err: #{agent}")
  end

  # get back to normal path.
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>shared, path=>"/tstzones/mnt" }') do
    assert_match(/path changed '.tstzones.mnt2' to '.tstzones.mnt'/, result.stdout, "err: #{agent}")
  end

  on agent,"/usr/sbin/zonecfg -z tstzone export" do
    assert_match(/set zonepath=.tstzones.mnt/, result.stdout, "err: #{agent}")
  end

  # ensure we can install.
  apply_manifest_on(agent, 'zone {tstzone : ensure=>installed}') do
    assert_match(/ensure changed 'configured' to 'installed'/, result.stdout, "err: #{agent}")
  end

  # we cannot change paths once installed.
  apply_manifest_on(agent, 'zone {tstzone : ensure=>installed, path=>"/tstzones/mnt2"}') do
    assert_match(/Failed to apply configuration/, result.output, "err: #{agent}")
  end

  on agent,"/usr/sbin/zonecfg -z tstzone export" do
    assert_match(/set zonepath=.tstzones.mnt/, result.stdout, "err: #{agent}")
  end
  apply_manifest_on(agent, 'zone {tstzone : ensure=>absent}') do
    assert_match(/ensure: removed/, result.output, "err: #{agent}")
  end
end

