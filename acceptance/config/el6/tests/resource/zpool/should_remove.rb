test_name "ZPool: configuration"
confine :to, :platform => 'solaris'

require 'puppet/acceptance/solaris_util'
extend Puppet::Acceptance::ZPoolUtils

teardown do
  step "ZPool: cleanup"
  agents.each do |agent|
    clean agent
  end
end


agents.each do |agent|
  step "ZPool: setup"
  setup agent
  #-----------------------------------
  step "ZPool: create"
  on(agent, "zpool create tstpool /ztstpool/dsk1")
  on(agent, "zpool list") do
    assert_match( /tstpool/ , result.stdout, "err: #{agent}")
  end

  step "ZPool: remove"
  apply_manifest_on(agent, "zpool{ tstpool: ensure=>absent }") do
    assert_match( /ensure: removed/ , result.stdout, "err: #{agent}")
  end
  on(agent, "zpool list") do
    assert_no_match( /tstpool/ , result.stdout, "err: #{agent}")
  end
end
