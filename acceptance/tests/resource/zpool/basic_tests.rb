test_name "ZPool: configuration"
confine :to, :platform => 'solaris'

tag 'audit:medium',
    'audit:refactor',  # Use block style `test_name`
    'audit:acceptance' # Could be done as integration tests, but would
                       # require drastically changing the system running the test

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
  step "ZPool: create zpool disk"
  apply_manifest_on(agent, "zpool{ tstpool: ensure=>present, disk=>'/ztstpool/dsk1' }") do
    assert_match( /ensure: created/, result.stdout, "err: #{agent}")
  end

  step "ZPool: zpool should be idempotent"
  apply_manifest_on(agent, "zpool{ tstpool: ensure=>present, disk=>'/ztstpool/dsk1' }") do
    assert_no_match( /ensure: created/, result.stdout, "err: #{agent}")
  end

  step "ZPool: remove zpool"
  apply_manifest_on(agent, "zpool{ tstpool: ensure=>absent }") do
    assert_match( /ensure: removed/ , result.stdout, "err: #{agent}")
  end

  step "ZPool: create zpool with a disk array"
  apply_manifest_on(agent, "zpool{ tstpool: ensure=>present, disk=>['/ztstpool/dsk1','/ztstpool/dsk2'] }") do
    assert_match( /ensure: created/ , result.stdout, "err: #{agent}")
  end

  step "ZPool: verify disk array was created"
  on agent, "zpool list -H" do
    assert_match( /tstpool/ , result.stdout, "err: #{agent}")
  end

  step "ZPool: verify puppet resource reports on the disk array"
  on(agent, puppet("resource zpool tstpool")) do
    assert_match(/ensure => 'present'/, result.stdout, "err: #{agent}")
    assert_match(/disk +=> .'.+dsk1 .+dsk2'./, result.stdout, "err: #{agent}")
  end

  step "ZPool: remove zpool in preparation for mirror tests"
  apply_manifest_on(agent, "zpool{ tstpool: ensure=>absent }") do
    assert_match( /ensure: removed/ , result.stdout, "err: #{agent}")
  end

  step "ZPool: create mirrored zpool with 3 virtual devices"
  apply_manifest_on(agent, "zpool{ tstpool: ensure=>present, mirror=>['/ztstpool/dsk1 /ztstpool/dsk2 /ztstpool/dsk3'] }") do
    assert_match( /ensure: created/ , result.stdout, "err: #{agent}")
  end

  step "ZPool: verify mirrors were created"
  on agent, "zpool status -v tstpool" do
    # 	NAME                STATE     READ WRITE CKSUM
    # tstpool             ONLINE       0     0     0
    #   mirror-0          ONLINE       0     0     0
    #     /ztstpool/dsk1  ONLINE       0     0     0
    #     /ztstpool/dsk2  ONLINE       0     0     0
    #     /ztstpool/dsk3  ONLINE       0     0     0
    assert_match( /tstpool.*\n\s+mirror.*\n\s*\/ztstpool\/dsk1.*\n\s*\/ztstpool\/dsk2.*\n\s*\/ztstpool\/dsk3/m, result.stdout, "err: #{agent}")
  end

  step "ZPool: verify puppet resource reports on the mirror"
  on(agent, puppet("resource zpool tstpool")) do
    assert_match(/ensure => 'present'/, result.stdout, "err: #{agent}")
    assert_match(/mirror => \['\/ztstpool\/dsk1 \/ztstpool\/dsk2 \/ztstpool\/dsk3'\]/, result.stdout, "err: #{agent}")
  end

  step "ZPool: remove zpool in preparation for multiple mirrors"
  apply_manifest_on(agent,"zpool{ tstpool: ensure=>absent }") do
    assert_match(/ensure: removed/, result.stdout, "err: #{agent}")
  end

  step "ZPool: create 2 mirrored zpools each with 2 virtual devices"
  apply_manifest_on(agent, "zpool{ tstpool: ensure=>present, mirror=>['/ztstpool/dsk1 /ztstpool/dsk2', '/ztstpool/dsk3 /ztstpool/dsk5'] }") do
    assert_match( /ensure: created/ , result.stdout, "err: #{agent}")
  end

  step "ZPool: verify both mirrors were created"
  on agent, "zpool status -v tstpool" do
    # 	NAME                STATE     READ WRITE CKSUM
    # tstpool             ONLINE       0     0     0
    #   mirror-0          ONLINE       0     0     0
    #     /ztstpool/dsk1  ONLINE       0     0     0
    #     /ztstpool/dsk2  ONLINE       0     0     0
    #   mirror-1          ONLINE       0     0     0
    #     /ztstpool/dsk3  ONLINE       0     0     0
    #     /ztstpool/dsk5  ONLINE       0     0     0
    assert_match( /tstpool.*\n\s+mirror.*\n\s*\/ztstpool\/dsk1.*\n\s*\/ztstpool\/dsk2.*\n\s+mirror.*\n\s*\/ztstpool\/dsk3.*\n\s*\/ztstpool\/dsk5/m, result.stdout, "err: #{agent}")
  end

  step "ZPool: verify puppet resource reports on both mirrors"
  on(agent, puppet("resource zpool tstpool")) do
    assert_match(/ensure => 'present'/, result.stdout, "err: #{agent}")
    assert_match(/mirror => \['\/ztstpool\/dsk1 \/ztstpool\/dsk2', '\/ztstpool\/dsk3 \/ztstpool\/dsk5'\]/, result.stdout, "err: #{agent}")
  end

  step "ZPool: remove zpool in preparation for raidz test"
  apply_manifest_on(agent,"zpool{ tstpool: ensure=>absent }") do
    assert_match(/ensure: removed/, result.stdout, "err: #{agent}")
  end

  step "ZPool: create raidz pool consisting of 3 virtual devices"
  apply_manifest_on(agent, "zpool{ tstpool: ensure=>present, raidz=>['/ztstpool/dsk1 /ztstpool/dsk2 /ztstpool/dsk3'] }") do
    assert_match( /ensure: created/ , result.stdout, "err: #{agent}")
  end

  step "ZPool: verify raidz pool was created"
  on agent, "zpool status -v tstpool" do
    # 	NAME                STATE     READ WRITE CKSUM
    # tstpool             ONLINE       0     0     0
    #   raidz1-0          ONLINE       0     0     0
    #     /ztstpool/dsk1  ONLINE       0     0     0
    #     /ztstpool/dsk2  ONLINE       0     0     0
    #     /ztstpool/dsk3  ONLINE       0     0     0
    assert_match( /tstpool.*\n\s+raidz.*\n\s*\/ztstpool\/dsk1.*\n\s*\/ztstpool\/dsk2.*\n\s*\/ztstpool\/dsk3/m, result.stdout, "err: #{agent}")
  end

  step "ZPool: verify puppet reports on the raidz pool"
  on(agent, puppet("resource zpool tstpool")) do
    assert_match(/ensure => 'present'/, result.stdout, "err: #{agent}")
    assert_match(/raidz  => \['\/ztstpool\/dsk1 \/ztstpool\/dsk2 \/ztstpool\/dsk3'\]/, result.stdout, "err: #{agent}")
  end

  step "ZPool: remove zpool in preparation for multiple raidz pools"
  apply_manifest_on(agent,"zpool{ tstpool: ensure=>absent }") do
    assert_match(/ensure: removed/, result.stdout, "err: #{agent}")
  end

  step "ZPool: create 2 mirrored zpools each with 2 virtual devices"
  apply_manifest_on(agent, "zpool{ tstpool: ensure=>present, raidz=>['/ztstpool/dsk1 /ztstpool/dsk2', '/ztstpool/dsk3 /ztstpool/dsk5'] }") do
    assert_match( /ensure: created/ , result.stdout, "err: #{agent}")
  end

  step "ZPool: verify both raidz were created"
  on agent, "zpool status -v tstpool" do
    # 	NAME                STATE     READ WRITE CKSUM
    # tstpool             ONLINE       0     0     0
    #   raidz1-0          ONLINE       0     0     0
    #     /ztstpool/dsk1  ONLINE       0     0     0
    #     /ztstpool/dsk2  ONLINE       0     0     0
    #   raidz1-1          ONLINE       0     0     0
    #     /ztstpool/dsk3  ONLINE       0     0     0
    #     /ztstpool/dsk5  ONLINE       0     0     0
    assert_match( /tstpool.*\n\s+raidz.*\n\s*\/ztstpool\/dsk1.*\n\s*\/ztstpool\/dsk2.*\n\s+raidz.*\n\s*\/ztstpool\/dsk3.*\n\s*\/ztstpool\/dsk5/m, result.stdout, "err: #{agent}")
  end

  step "ZPool: verify puppet resource reports on both raidz"
  on(agent, puppet("resource zpool tstpool")) do
    assert_match(/ensure => 'present'/, result.stdout, "err: #{agent}")
    assert_match(/raidz  => \['\/ztstpool\/dsk1 \/ztstpool\/dsk2', '\/ztstpool\/dsk3 \/ztstpool\/dsk5'\]/, result.stdout, "err: #{agent}")
  end
end
