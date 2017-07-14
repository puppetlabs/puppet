test_name "Zone:IP ip-type and ip configuration"
confine :to, :platform => 'solaris'
require 'puppet/acceptance/solaris_util'
extend Puppet::Acceptance::ZoneUtils

tag 'audit:medium',
    'audit:refactor',  # Use block style `test_name`
    'audit:acceptance' # Could be done as integration tests, but would
                       # require drastically changing the system running the test

teardown do
  step "Zone: ip - cleanup"
  agents.each do |agent|
    clean agent
  end
end

agents.each do |agent|
  step "Zone: ip - setup"
  setup agent
  # See
  # https://hg.openindiana.org/upstream/illumos/illumos-gate/file/03d5725cda56/usr/src/lib/libinetutil/common/ifspec.c
  # for the funciton ifparse_ifspec. This is the only documentation that exists
  # as to what the zone interface can be.
  #-----------------------------------
  # Make sure that the zone is absent.
  step "Zone: ip - make it configured"
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>shared, path=>"/tstzones/mnt" }') do
    assert_match( /ensure: created/, result.stdout, "err: #{agent}")
  end
  step "Zone: ip - ip switch: verify that the change from shared to exclusive works."
  # --------------------------------------------------------------------
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>exclusive, path=>"/tstzones/mnt" }') do
    assert_match(/iptype changed 'shared'.* to 'exclusive'/, result.stdout, "err: #{agent}")
  end
  step "Zone: ip - ip switch: verify that we can change it back"
  # --------------------------------------------------------------------
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>exclusive, path=>"/tstzones/mnt" }') do
    assert_no_match(/iptype changed 'shared'.* to 'exclusive'/, result.stdout, "err: #{agent}")
  end

  step "Zone: ip - switch to shared for remaining cases"
  # we have to use shared for remaining test cases.
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>shared, path=>"/tstzones/mnt" }') do
    assert_match(/iptype changed 'exclusive'.* to 'shared'/, result.stdout, "err: #{agent}")
  end

  step "Zone: ip - assign: ensure that our ip assignment works."
  # --------------------------------------------------------------------
  apply_manifest_on(agent,'zone {tstzone : ensure=>configured, iptype=>shared, path=>"/tstzones/mnt", ip=>"ip.if.1" }', :acceptable_exit_codes => [1] ) do
    assert_match(/ip must contain interface name and ip address separated by a \W*?:/, result.output, "err: #{agent}")
  end
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>shared, path=>"/tstzones/mnt", ip=>"ip.if.1:1.1.1.1" }') do
    assert_match(/defined 'ip' as .'ip.if.1:1.1.1.1'./ , result.stdout, "err: #{agent}")
  end
  step "Zone: ip - assign: arrays should be created"
  # --------------------------------------------------------------------
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>shared, path=>"/tstzones/mnt", ip=>["ip.if.1:1.1.1.1", "ip.if.2:1.1.1.2"] }') do
    assert_match( /ip changed ip.if.1:1.1.1.1 to \['ip.if.1:1.1.1.1', 'ip.if.2:1.1.1.2'\]/, result.stdout, "err: #{agent}")
  end
  step "Zone: ip - assign: arrays should be modified"
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>shared, path=>"/tstzones/mnt", ip=>["ip.if.1:1.1.1.1", "ip.if.2:1.1.1.3"] }') do
    assert_match(/ip changed ip.if.1:1.1.1.1,ip.if.2:1.1.1.2 to \['ip.if.1:1.1.1.1', 'ip.if.2:1.1.1.3'\]/, result.stdout, "err: #{agent}")
  end
  step "Zone: ip - idempotency: arrays"
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>shared, path=>"/tstzones/mnt", ip=>["ip.if.1:1.1.1.1", "ip.if.2:1.1.1.3"] }') do
    assert_no_match(/ip changed/, result.stdout, "err: #{agent}")
  end
end
