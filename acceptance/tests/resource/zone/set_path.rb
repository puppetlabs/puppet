test_name "Zone:Path configuration"
confine :to, :platform => 'solaris'

tag 'audit:medium',
    'audit:refactor',  # Use block style `test_name`
    'audit:acceptance' # Could be done as integration tests, but would
                       # require drastically changing the system running the test

require 'puppet/acceptance/solaris_util'
extend Puppet::Acceptance::ZoneUtils

teardown do
  step "Zone: path - cleanup"
  agents.each do |agent|
    clean agent
  end
end


agents.each do |agent|
  step "Zone: path - setup"
  setup agent
  #-----------------------------------
  step "Zone: path - required parameter (-)"
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>shared }') do
    assert_match( /Error: Path is required/, result.output, "err: #{agent}")
  end

  step "Zone: path - required parameter (+)"
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>shared, path=>"/tstzones/mnt" }') do
    assert_match( /ensure: created/, result.stdout, "err: #{agent}")
  end

  step "Zone: path - should change the path if it is switched before install"
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>shared, path=>"/tstzones/mnt2" }') do
    assert_match(/path changed '.tstzones.mnt'.* to '.tstzones.mnt2'/, result.stdout, "err: #{agent}")
  end

  step "Zone: path - verify the path is correct"
  on agent,"/usr/sbin/zonecfg -z tstzone export" do
    assert_match(/set zonepath=.*mnt2/, result.stdout, "err: #{agent}")
  end

  step "Zone: path - revert to original path"
  apply_manifest_on(agent, 'zone {tstzone : ensure=>configured, iptype=>shared, path=>"/tstzones/mnt" }') do
    assert_match(/path changed '.tstzones.mnt2'.* to '.tstzones.mnt'/, result.stdout, "err: #{agent}")
  end

  step "Zone: path - verify that we have correct path"
  on agent,"/usr/sbin/zonecfg -z tstzone export" do
    assert_match(/set zonepath=.tstzones.mnt/, result.stdout, "err: #{agent}")
  end
end

