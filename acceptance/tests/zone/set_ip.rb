test_name "Zone:IP ip-type and ip configuration"
confine :to, :platform => 'solaris'
require 'puppet/acceptance/solaris_util'
extend Puppet::Acceptance::ZoneUtils

teardown do
  step "Zone: ip - cleanup"
  agents.each do |agent|
    clean agent
  end
end

agents.each do |agent|
  step "Zone: ip - cleanup"
  clean agent
  step "Zone: ip - setup"
  setup agent
  #-----------------------------------
  # Make sure that the zone is absent.
  step "Zone: ip - cleanslate"
  apply_manifest_on(agent, 'zone {tstzone : ensure=>absent}') do
    assert_match( /Finished catalog run in .*/, result.stdout, "err: #{agent}")
  end
  step "Zone: ip - make it configured"
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>shared, path=>"/tstzones/mnt" }') do
    assert_match( /ensure: created/, result.stdout, "err: #{agent}")
  end
  step "Zone: ip - idempotent, should not create again"
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>shared, path=>"/tstzones/mnt" }') do
    assert_no_match( /ensure: created/, result.stdout, "err: #{agent}")
  end

  step "Zone: ip - ip switch: verify that the change from shared to exclusive works."
  # --------------------------------------------------------------------
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>exclusive, path=>"/tstzones/mnt" }') do
    assert_match(/iptype changed 'shared' to 'exclusive'/, result.stdout, "err: #{agent}")
  end
  step "Zone: ip - ip switch: verify that we can change it back"
  # --------------------------------------------------------------------
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>exclusive, path=>"/tstzones/mnt" }') do
    assert_no_match(/iptype changed 'shared' to 'exclusive'/, result.stdout, "err: #{agent}")
  end

  step "Zone: ip - switch to shared for remaining cases"
  # we have to use shared for remaining test cases.
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>shared, path=>"/tstzones/mnt" }') do
    assert_match(/iptype changed 'exclusive' to 'shared'/, result.stdout, "err: #{agent}")
  end

  step "Zone: ip - assign: ensure that our ip assignment works."
  # --------------------------------------------------------------------
  apply_manifest_on(agent,'zone {tstzone : ensure=>configured, iptype=>shared, path=>"/tstzones/mnt", ip=>"eg0001" }', :acceptable_exit_codes => [1] ) do
    assert_match(/Error: ip must contain interface name and ip address separated by a ":"/, result.output, "err: #{agent}")
  end
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>shared, path=>"/tstzones/mnt", ip=>"eg0001:1.1.1.1" }') do
    assert_match(/defined 'ip' as .'eg0001:1.1.1.1'./ , result.stdout, "err: #{agent}")
  end
  step "Zone: ip - assign: arrays should be created"
  # --------------------------------------------------------------------
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>shared, path=>"/tstzones/mnt", ip=>["eg0001:1.1.1.1", "eg0002:1.1.1.2"] }') do
    assert_match( /ip changed 'eg0001:1.1.1.1' to .'eg0001:1.1.1.1', 'eg0002:1.1.1.2'./, result.stdout, "err: #{agent}")
  end
  step "Zone: ip - assign: arrays should be modified"
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>shared, path=>"/tstzones/mnt", ip=>["eg0001:1.1.1.1", "eg0002:1.1.1.3"] }') do
    assert_match(/ip changed 'eg0001:1.1.1.1,eg0002:1.1.1.2' to .'eg0001:1.1.1.1', 'eg0002:1.1.1.3'./, result.stdout, "err: #{agent}")
  end
  step "Zone: ip - idempotency: arrays"
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>shared, path=>"/tstzones/mnt", ip=>["eg0001:1.1.1.1", "eg0002:1.1.1.3"] }') do
    assert_no_match(/ip changed/, result.stdout, "err: #{agent}")
  end

  step "Zone: ip - ensure remove"
  apply_manifest_on(agent, 'zone {tstzone : ensure=>absent}') do
    assert_match(/ensure: removed/, result.stdout, "err: #{agent}")
  end
end
