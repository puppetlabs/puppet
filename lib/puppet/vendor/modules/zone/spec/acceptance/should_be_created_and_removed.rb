test_name "Zone: should be created and removed"

confine :to, :platform => 'solaris'

tag 'audit:medium',
    'audit:refactor',  # Use block style `test_name`
    'audit:acceptance' # Could be done as integration tests, but would
                       # require drastically changing the system running the test

require 'puppet/acceptance/solaris_util'
extend Puppet::Acceptance::ZoneUtils

teardown do
  step "Zone: removal - cleanup"
  agents.each do |agent|
    clean agent
  end
end

config_inherit_string = ""
agents.each do |agent|
  #inherit /sbin on solaris10 until PUP-3722
  config_inherit_string = "inherit=>'/sbin'" if agent['platform'] =~ /solaris-10/
  
  step "Zone: setup"
  setup agent
  #-----------------------------------
  step "Zone: make it running"
  step "progress would be logged to agent:/var/log/zones/zoneadm.<date>.<zonename>.install"
  step "install log would be at agent:/system/volatile/install.<id>/install_log"

  apply_manifest_on(agent, "zone {tstzone : ensure=>running, path=>'/tstzones/mnt', #{config_inherit_string} }") do
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
