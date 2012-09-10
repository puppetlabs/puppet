test_name "Zone:statemachine single states"
confine :to, :platform => 'solaris'

require 'puppet/acceptance/solaris_util'
extend Puppet::Acceptance::ZoneUtils

teardown do
  agents.each do |agent|
    clean agent
  end
end


agents.each do |agent|
  clean agent
  setup agent
  #-----------------------------------
  # Make sure that the zone is absent.
  apply_manifest_on(agent, 'zone {tstzone : ensure=>absent}') do
    assert_match( /Finished catalog run in .*/, result.stdout, "err: #{agent}")
  end

  apply_manifest_on(agent, "zone {tstzone : ensure=>configured, iptype=>shared, path=>'/tstzones/mnt' }" ) do
    assert_match( /ensure: created/, result.stdout, "err: #{agent}")
  end
  on agent, "zoneadm -z tstzone verify" do
    assert_no_match( /could not verify/, result.stdout, "err: #{agent}")
  end

  apply_manifest_on(agent,"zone {tstzone : ensure=>installed, iptype=>shared, path=>'/tstzones/mnt' }") do
    assert_match(/ensure changed 'configured' to 'installed'/, result.stdout, "err: #{agent}")
  end

  apply_manifest_on(agent,"zone {tstzone : ensure=>running, iptype=>shared, path=>'/tstzones/mnt' }") do
    assert_match(/ensure changed 'installed' to 'running'/, result.stdout, "err: #{agent}")
  end

  apply_manifest_on(agent,"zone {tstzone : ensure=>installed, iptype=>shared, path=>'/tstzones/mnt' }") do
    assert_match(/ensure changed 'running' to 'installed'/, result.stdout, "err: #{agent}")
  end

  apply_manifest_on(agent,"zone {tstzone : ensure=>configured, iptype=>shared, path=>'/tstzones/mnt' }") do
    assert_match(/ensure changed 'installed' to 'configured'/, result.stdout, "err: #{agent}")
  end
  apply_manifest_on(agent, 'zone {tstzone : ensure=>absent}') do
    assert_match( /ensure: removed/, result.stdout, "err: #{agent}")
  end
end

