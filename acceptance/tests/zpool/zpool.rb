test_name "ZPool: configuration"
confine :to, :platform => 'solaris'

require 'puppet/acceptance/solaris_util'
extend Puppet::Acceptance::ZPoolUtils

teardown do
  agents.each do |agent|
    clean agent
  end
end


agents.each do |agent|
  clean agent
  setup agent
  #-----------------------------------
  apply_manifest_on(agent, "zpool{ tstpool: ensure=>present, disk=>'/ztstpool/dsk1' }") do
    assert_match( /ensure: created/, result.stdout, "err: #{agent}")
  end

  apply_manifest_on(agent, "zpool{ tstpool: ensure=>present, disk=>'/ztstpool/dsk1' }") do
    assert_no_match( /ensure: created/, result.stdout, "err: #{agent}")
  end

  apply_manifest_on(agent, "zpool{ tstpool: ensure=>absent }") do
    assert_match( /ensure: removed/ , result.stdout, "err: #{agent}")
  end

  apply_manifest_on(agent, "zpool{ tstpool: ensure=>present, disk=>['/ztstpool/dsk1','/ztstpool/dsk2'] }") do
    assert_match( /ensure: created/ , result.stdout, "err: #{agent}")
  end

  on agent, "zpool list -H" do
    assert_match( /tstpool/ , result.stdout, "err: #{agent}")
  end

  on agent, "puppet resource zpool tstpool" do
    assert_match(/ensure => 'present'/, result.stdout, "err: #{agent}")
    assert_match(/disk +=> .'.+dsk1 .+dsk2'./, result.stdout, "err: #{agent}")
  end

  apply_manifest_on(agent, "zpool{ tstpool: ensure=>absent }") do
    assert_match( /ensure: removed/ , result.stdout, "err: #{agent}")
  end

  apply_manifest_on(agent, "zpool{ tstpool: ensure=>present, mirror=>['/ztstpool/dsk1','/ztstpool/dsk2', '/ztstpool/dsk3'] }") do
    assert_match( /ensure: created/ , result.stdout, "err: #{agent}")
  end

  on agent, "zpool status -v tstpool" do
    assert_match( /tstpool/ , result.stdout, "err: #{agent}")
    assert_match( /mirror/ , result.stdout, "err: #{agent}")
  end

  on agent, "puppet resource zpool tstpool" do
    assert_match(/ensure => 'present'/, result.stdout, "err: #{agent}")
    assert_match(/mirror => .'.+dsk1 .+dsk2 .+dsk3'./, result.stdout, "err: #{agent}")
  end
  apply_manifest_on(agent,"zpool{ tstpool: ensure=>absent }") do
    assert_match(/ensure: removed/, result.stdout, "err: #{agent}")
  end

  apply_manifest_on(agent, "zpool{ tstpool: ensure=>present, raidz=>['/ztstpool/dsk1','/ztstpool/dsk2', '/ztstpool/dsk3'] }") do
    assert_match( /ensure: created/ , result.stdout, "err: #{agent}")
  end

  on agent, "zpool status -v tstpool" do
    assert_match( /tstpool/ , result.stdout, "err: #{agent}")
    assert_match( /raidz/ , result.stdout, "err: #{agent}")
  end

  on agent, "puppet resource zpool tstpool" do
    assert_match(/ensure => 'present'/, result.stdout, "err: #{agent}")
    assert_match(/raidz +=> .'.+dsk1 .+dsk2 .+dsk3'./, result.stdout, "err: #{agent}")
  end
end
