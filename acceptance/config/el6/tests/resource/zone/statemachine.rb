test_name "Zone:Statemachine configuration"
confine :to, :platform => 'solaris'

require 'puppet/acceptance/solaris_util'
extend Puppet::Acceptance::ZoneUtils

teardown do
  step "Zone: statemachine - cleanup"
  agents.each do |agent|
    clean agent
  end
end

agents.each do |agent|
  step "Zone: statemachine - setup"
  setup agent

  step "Zone: statemachine - create zone and make it running"
  step "progress would be logged to agent:/var/log/zones/zoneadm.<date>.<zonename>.install"
  step "install log would be at agent:/system/volatile/install.<id>/install_log"
  apply_manifest_on(agent, "zone {tstzone : ensure=>running, iptype=>shared, path=>'/tstzones/mnt' }") do
    assert_match( /ensure: created/, result.stdout, "err: #{agent}")
  end

  step "Zone: statemachine - ensure zone is correct"
  on agent, "zoneadm -z tstzone verify" do
    assert_no_match( /could not verify/, result.stdout, "err: #{agent}")
  end

  step "Zone: statemachine - ensure zone is running"
  on agent, "zoneadm -z tstzone list -v" do
    assert_match( /running/, result.stdout, "err: #{agent}")
  end

  step "Zone: statemachine - stop and uninstall zone"
  apply_manifest_on(agent, "zone {tstzone : ensure=>configured, iptype=>shared, path=>'/tstzones/mnt' }") do
    assert_match( /ensure changed 'running' to 'configured'/ , result.stdout, "err: #{agent}")
  end

  on agent, "zoneadm -z tstzone list -v" do
    assert_match( /configured/, result.stdout, "err: #{agent}")
  end
end
