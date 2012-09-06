test_name "Zone:IP ip-type and ip configuration"
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
  # Make it configured
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>shared, path=>"/tstzones/mnt" }') do
    assert_match( /ensure: created/, result.stdout, "err: #{agent}")
  end
  # idempotent: Should not create again
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>shared, path=>"/tstzones/mnt" }') do
    assert_no_match( /ensure: created/, result.stdout, "err: #{agent}")
  end

  # IP switch: verify that the change from shared to exclusive works.
  # --------------------------------------------------------------------
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>exclusive, path=>"/tstzones/mnt" }') do
    assert_match(/iptype changed 'shared' to 'exclusive'/, result.stdout, "err: #{agent}")
  end
  # IP switch: verify that we can change it back
  # --------------------------------------------------------------------
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>exclusive, path=>"/tstzones/mnt" }') do
    assert_no_match(/iptype changed 'shared' to 'exclusive'/, result.stdout, "err: #{agent}")
  end

  # we have to use shared for remaining test cases.
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>shared, path=>"/tstzones/mnt" }') do
    assert_match(/iptype changed 'exclusive' to 'shared'/, result.stdout, "err: #{agent}")
  end

  # IP assign: ensure that our ip assignment works.
  # --------------------------------------------------------------------
  apply_manifest_on(agent,'zone {tstzone : ensure=>configured, iptype=>shared, path=>"/tstzones/mnt", ip=>"eg0001" }', :acceptable_exit_codes => [1] ) do
    assert_match(/Error: ip must contain interface name and ip address separated by a ":"/, result.output, "err: #{agent}")
  end
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>shared, path=>"/tstzones/mnt", ip=>"eg0001:1.1.1.1" }') do
    assert_match(/defined 'ip' as .'eg0001:1.1.1.1'./ , result.stdout, "err: #{agent}")
  end
  # IP assign : arrays
  # --------------------------------------------------------------------
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>shared, path=>"/tstzones/mnt", ip=>["eg0001:1.1.1.1", "eg0002:1.1.1.2"] }') do
    assert_match( /ip changed 'eg0001:1.1.1.1' to .'eg0001:1.1.1.1', 'eg0002:1.1.1.2'./, result.stdout, "err: #{agent}")
  end
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>shared, path=>"/tstzones/mnt", ip=>["eg0001:1.1.1.1", "eg0002:1.1.1.3"] }') do
    assert_match(/ip changed 'eg0001:1.1.1.1,eg0002:1.1.1.2' to .'eg0001:1.1.1.1', 'eg0002:1.1.1.3'./, result.stdout, "err: #{agent}")
  end
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>shared, path=>"/tstzones/mnt", ip=>["eg0001:1.1.1.1", "eg0002:1.1.1.3"] }') do
    assert_no_match(/ip changed/, result.stdout, "err: #{agent}")
  end

  apply_manifest_on(agent, 'zone {tstzone : ensure=>absent}') do
    assert_match(/ensure: removed/, result.stdout, "err: #{agent}")
  end
end
