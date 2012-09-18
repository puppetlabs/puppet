test_name "Zone: should be created and removed"

confine :to, :platform => 'solaris'

require 'puppet/acceptance/solaris_util'
extend Puppet::Acceptance::ZoneUtils

teardown do
  step "Zone: removal - cleanup"
  agents.each do |agent|
    clean agent
  end
end


agents.each do |agent|
  step "Zone: setup"
  setup agent
  #-----------------------------------
  step "Zone: make it running"
  step "progress would be logged to agent:/var/log/zones/zoneadm.<date>.<zonename>.install"
  step "install log would be at agent:/system/volatile/install.<id>/install_log"

  apply_manifest_on(agent, 'zone {tstzone : ensure=>running, path=>"/tstzones/mnt" }') do
    assert_match( /created/, result.stdout, "err: #{agent}")
  end
  on(agent, "zoneadm list -cp") do
    assert_match( /tstzone/, result.stdout, "err: #{agent}")
  end
  on(agent, "zoneadm -z tstzone verify")
  step "Zone: ensure can remove"
  step "progress would be logged to agent:/var/log/zones/zoneadm.<date>.<zonename>.uninstall"
  apply_manifest_on(agent, 'zone {tstzone : ensure=>absent}') do
    assert_match( /ensure: removed/, result.stdout, "err: #{agent}")
  end
  on(agent, "zoneadm list -cp") do
    assert_no_match( /tstzone/, result.stdout, "err: #{agent}")
  end
end
