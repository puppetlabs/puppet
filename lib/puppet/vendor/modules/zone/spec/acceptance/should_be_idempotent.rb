test_name "Zone: should be idempotent"

confine :to, :platform => 'solaris'

tag 'audit:medium',
    'audit:refactor',  # Use block style `test_name`
    'audit:acceptance' # Could be done as integration tests, but would
                       # require drastically changing the system running the test

require 'puppet/acceptance/solaris_util'
extend Puppet::Acceptance::ZoneUtils

teardown do
  step "Zone: idempotency - cleanup"
  agents.each do |agent|
    clean agent
  end
end

config_inherit_string = ""
agents.each do |agent|
  #inherit /sbin on solaris10 until PUP-3722
  config_inherit_string = "inherit=>'/sbin'" if agent['platform'] =~ /solaris-10/

  step "Zone: idempotency - setup"
  setup agent
  #-----------------------------------
  step "Zone: idempotency - make it configured"
  apply_manifest_on(agent, "zone {tstzone : ensure=>configured, path=>'/tstzones/mnt', #{config_inherit_string} }") do
    assert_match( /ensure: created/, result.stdout, "err: #{agent}")
  end
  step "Zone: idempotency, should not create again."
  apply_manifest_on(agent, "zone {tstzone : ensure=>configured, path=>'/tstzones/mnt', #{config_inherit_string} }") do
    assert_no_match( /ensure: created/, result.stdout, "err: #{agent}")
  end
  step "Zone: idempotency - make it installed"
  step "progress would be logged to agent:/var/log/zones/zoneadm.<date>.<zonename>.install"
  step "install log would be at agent:/system/volatile/install.<id>/install_log"
  apply_manifest_on(agent, 'zone {tstzone : ensure=>installed, path=>"/tstzones/mnt" }') do
    assert_match( /changed/, result.stdout, "err: #{agent}")
  end
  step "Zone: idempotency, should not install again."
  apply_manifest_on(agent, 'zone {tstzone : ensure=>installed, path=>"/tstzones/mnt" }') do
    assert_no_match( /changed/, result.stdout, "err: #{agent}")
  end
  step "Zone: idempotency - make it running"
  apply_manifest_on(agent, 'zone {tstzone : ensure=>running, path=>"/tstzones/mnt" }') do
    assert_match( /changed/, result.stdout, "err: #{agent}")
  end
  step "Zone: idempotency, should not make it running again."
  apply_manifest_on(agent, 'zone {tstzone : ensure=>running, path=>"/tstzones/mnt" }') do
    assert_no_match( /changed/, result.stdout, "err: #{agent}")
  end
end
