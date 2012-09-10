test_name "Zone:Statemachine configuration"
confine :to, :platform => 'solaris'

require 'puppet/acceptance/solaris_util'
extend Puppet::Acceptance::ZoneUtils

teardown do
  agents.each do |agent|
    clean agent
  end
end

def moresetup(agent)
  on agent, "chmod 700 /tstzones/mnt"
end

agents.each do |agent|
  clean agent
  setup agent
  moresetup agent

  apply_manifest_on(agent, "zone {smzone : ensure=>running, iptype=>shared, path=>'/tstzones/mnt' }") do
    assert_match( /ensure: created/, result.stdout, "err: #{agent}")
  end

  on agent, "zoneadm -z smzone verify" do
    assert_no_match( /could not verify/, result.stdout, "err: #{agent}")
  end

  on agent, "zoneadm -z smzone list -v" do
    assert_match( /running/, result.stdout, "err: #{agent}")
  end

  apply_manifest_on(agent, "zone {smzone : ensure=>configured, iptype=>shared, path=>'/tstzones/mnt' }") do
    assert_match( /ensure changed 'running' to 'configured'/ , result.stdout, "err: #{agent}")
  end

  on agent, "zoneadm -z smzone verify" do
    assert_no_match( /could not verify/, result.stdout, "err: #{agent}")
  end
  on agent, "zoneadm -z smzone list -v" do
    assert_match( /configured/, result.stdout, "err: #{agent}")
  end
end

