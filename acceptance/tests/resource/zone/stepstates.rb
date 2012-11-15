test_name "Zone:statemachine single states"
confine :to, :platform => 'solaris'

require 'puppet/acceptance/solaris_util'
extend Puppet::Acceptance::ZoneUtils

teardown do
  step "Zone: steps - cleanup"
  agents.each do |agent|
    clean agent
  end
end


agents.each do |agent|
  step "Zone: steps - setup"
  setup agent
  step "Zone: steps - create"
  apply_manifest_on(agent, "zone {tstzone : ensure=>configured, iptype=>shared, path=>'/tstzones/mnt' }" ) do
    assert_match( /ensure: created/, result.stdout, "err: #{agent}")
  end
  step "Zone: steps - verify (create)"
  on agent, "zoneadm -z tstzone verify" do
    assert_no_match( /could not verify/, result.stdout, "err: #{agent}")
  end

  step "Zone: steps - configured -> installed"
  step "progress would be logged to agent:/var/log/zones/zoneadm.<date>.<zonename>.install"
  step "install log would be at agent:/system/volatile/install.<id>/install_log"
  apply_manifest_on(agent,"zone {tstzone : ensure=>installed, iptype=>shared, path=>'/tstzones/mnt' }") do
    assert_match(/ensure changed 'configured' to 'installed'/, result.stdout, "err: #{agent}")
  end

  step "Zone: steps - installed -> running"
  apply_manifest_on(agent,"zone {tstzone : ensure=>running, iptype=>shared, path=>'/tstzones/mnt' }") do
    assert_match(/ensure changed 'installed' to 'running'/, result.stdout, "err: #{agent}")
  end

  step "Zone: steps - running -> installed"
  apply_manifest_on(agent,"zone {tstzone : ensure=>installed, iptype=>shared, path=>'/tstzones/mnt' }") do
    assert_match(/ensure changed 'running' to 'installed'/, result.stdout, "err: #{agent}")
  end

  step "Zone: steps - installed -> configured"
  apply_manifest_on(agent,"zone {tstzone : ensure=>configured, iptype=>shared, path=>'/tstzones/mnt' }") do
    assert_match(/ensure changed 'installed' to 'configured'/, result.stdout, "err: #{agent}")
  end
end
