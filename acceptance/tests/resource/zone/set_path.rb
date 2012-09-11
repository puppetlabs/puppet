test_name "Zone:Path configuration"
confine :to, :platform => 'solaris:pending'

# If you plan to enable it, it would be a good idea to have a multi-cpu system with
# atleast 2G ram. If it takes too long, open agent and try
# truss -t open -p <auto-install:pid>
# The auto install pid can be found by using ptree on the puppet apply pid
# (use grep)

require 'puppet/acceptance/solaris_util'
extend Puppet::Acceptance::ZoneUtils

def moresetup(agent)
  on agent, "mkdir /tstzones/mnt2"
  on agent, "zfs create -o mountpoint=/tstzones/mnt2 tstpool/tstfs2"
end

def moreclean(agent)
  lst = on(agent, "zfs list -H").stdout.lines.each do |l|
    case l
    when /tstpool\/tstfs2/
      on agent, "zfs destroy -r tstpool/tstfs2"
    end
  end

end


teardown do
  step "Zone: path - cleanup"
  agents.each do |agent|
    moreclean agent
    clean agent
  end
end


agents.each do |agent|
  step "Zone: path - cleanup"
  clean agent
  step "Zone: path - setup"
  setup agent, :size => '1536m'
  moresetup agent
  #-----------------------------------
  # Make sure that the zone is absent.
  step "Zone: path - cleanslate"
  apply_manifest_on(agent, 'zone {tstzone : ensure=>absent}') do
    assert_match( /Finished catalog run in .*/, result.stdout, "err: #{agent}")
  end

  step "Zone: path - required parameter (-)"
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>shared }') do
    assert_match( /Error: Path is required/, result.output, "err: #{agent}")
  end

  step "Zone: path - required parameter (+)"
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>shared, path=>"/tstzones/mnt" }') do
    assert_match( /ensure: created/, result.stdout, "err: #{agent}")
  end

  step "Zone: path - idempotency: should not create again."
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>shared, path=>"/tstzones/mnt" }') do
    assert_no_match( /ensure: created/, result.stdout, "err: #{agent}")
  end

  step "Zone: path - should change the path if it is switched before install"
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>shared, path=>"/tstzones/mnt2" }') do
    assert_match(/path changed '.tstzones.mnt' to '.tstzones.mnt2'/, result.stdout, "err: #{agent}")
  end

  step "Zone: path - idempotency, should not change the path again"
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>shared, path=>"/tstzones/mnt2" }') do
    assert_no_match(/path changed '.tstzones.mnt' to '.tstzones.mnt2'/, result.stdout, "err: #{agent}")
  end

  step "Zone: path - verify the path is correct"
  on agent,"/usr/sbin/zonecfg -z tstzone export" do
    assert_match(/set zonepath=.*mnt2/, result.stdout, "err: #{agent}")
  end

  step "Zone: path - revert to original path"
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>shared, path=>"/tstzones/mnt" }') do
    assert_match(/path changed '.tstzones.mnt2' to '.tstzones.mnt'/, result.stdout, "err: #{agent}")
  end

  step "Zone: path - verify that we have correct path"
  on agent,"/usr/sbin/zonecfg -z tstzone export" do
    assert_match(/set zonepath=.tstzones.mnt/, result.stdout, "err: #{agent}")
  end

  step "Zone: path - ensure we can install."
  apply_manifest_on(agent, 'zone {tstzone : ensure=>installed}') do
    assert_match(/ensure changed 'configured' to 'installed'/, result.stdout, "err: #{agent}")
  end

  step "Zone: path - we cannot change paths once installed."
  apply_manifest_on(agent, 'zone {tstzone : ensure=>installed, path=>"/tstzones/mnt2"}') do
    assert_match(/Failed to apply configuration/, result.output, "err: #{agent}")
  end

  step "Zone: path - check configuration"
  on agent,"/usr/sbin/zonecfg -z tstzone export" do
    assert_match(/set zonepath=.tstzones.mnt/, result.stdout, "err: #{agent}")
  end
  step "Zone: path - ensure removed"
  apply_manifest_on(agent, 'zone {tstzone : ensure=>absent}') do
    assert_match(/ensure: removed/, result.output, "err: #{agent}")
  end
end

