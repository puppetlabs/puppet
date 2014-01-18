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
  step "ZPool: making_sure create"
  apply_manifest_on(agent, "zpool{ tstpool: making_sure=>present, disk=>'/ztstpool/dsk1' }") do
    assert_match( /making_sure: created/, result.stdout, "err: #{agent}")
  end

  step "ZPool: idempotency - create"
  apply_manifest_on(agent, "zpool{ tstpool: making_sure=>present, disk=>'/ztstpool/dsk1' }") do
    assert_no_match( /making_sure: created/, result.stdout, "err: #{agent}")
  end

  step "ZPool: remove"
  apply_manifest_on(agent, "zpool{ tstpool: making_sure=>absent }") do
    assert_match( /making_sure: removed/ , result.stdout, "err: #{agent}")
  end

  step "ZPool: disk array"
  apply_manifest_on(agent, "zpool{ tstpool: making_sure=>present, disk=>['/ztstpool/dsk1','/ztstpool/dsk2'] }") do
    assert_match( /making_sure: created/ , result.stdout, "err: #{agent}")
  end

  step "ZPool: disk array: verify"
  on agent, "zpool list -H" do
    assert_match( /tstpool/ , result.stdout, "err: #{agent}")
  end

  step "ZPool: disk array: verify with puppet"
  on agent, "puppet resource zpool tstpool" do
    assert_match(/making_sure => 'present'/, result.stdout, "err: #{agent}")
    assert_match(/disk +=> .'.+dsk1 .+dsk2'./, result.stdout, "err: #{agent}")
  end

  step "ZPool: remove again for mirror tests"
  apply_manifest_on(agent, "zpool{ tstpool: making_sure=>absent }") do
    assert_match( /making_sure: removed/ , result.stdout, "err: #{agent}")
  end

  step "ZPool: mirror: making_sure can create"
  apply_manifest_on(agent, "zpool{ tstpool: making_sure=>present, mirror=>['/ztstpool/dsk1','/ztstpool/dsk2', '/ztstpool/dsk3'] }") do
    assert_match( /making_sure: created/ , result.stdout, "err: #{agent}")
  end

  step "ZPool: mirror: making_sure can create: verify"
  on agent, "zpool status -v tstpool" do
    assert_match( /tstpool/ , result.stdout, "err: #{agent}")
    assert_match( /mirror/ , result.stdout, "err: #{agent}")
  end

  step "ZPool: mirror: making_sure can create: vefify (puppet)"
  on agent, "puppet resource zpool tstpool" do
    assert_match(/making_sure => 'present'/, result.stdout, "err: #{agent}")
    assert_match(/mirror => .'.+dsk1 .+dsk2 .+dsk3'./, result.stdout, "err: #{agent}")
  end
  step "ZPool: remove for raidz test)"
  apply_manifest_on(agent,"zpool{ tstpool: making_sure=>absent }") do
    assert_match(/making_sure: removed/, result.stdout, "err: #{agent}")
  end

  step "ZPool: raidz: making_sure can create"
  apply_manifest_on(agent, "zpool{ tstpool: making_sure=>present, raidz=>['/ztstpool/dsk1','/ztstpool/dsk2', '/ztstpool/dsk3'] }") do
    assert_match( /making_sure: created/ , result.stdout, "err: #{agent}")
  end

  step "ZPool: raidz: making_sure can create: verify"
  on agent, "zpool status -v tstpool" do
    assert_match( /tstpool/ , result.stdout, "err: #{agent}")
    assert_match( /raidz/ , result.stdout, "err: #{agent}")
  end

  step "ZPool: raidz: making_sure can create: verify (puppet)"
  on agent, "puppet resource zpool tstpool" do
    assert_match(/making_sure => 'present'/, result.stdout, "err: #{agent}")
    assert_match(/raidz +=> .'.+dsk1 .+dsk2 .+dsk3'./, result.stdout, "err: #{agent}")
  end
end
