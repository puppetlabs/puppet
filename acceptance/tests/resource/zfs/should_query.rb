test_name "ZFS: configuration"
confine :to, :platform => 'solaris'

tag 'audit:medium',
    'audit:refactor',  # Use block style `test_name`
    'audit:acceptance' # Could be done as integration tests, but would
                       # require drastically changing the system running the test

require 'puppet/acceptance/solaris_util'
extend Puppet::Acceptance::ZFSUtils

teardown do
  step "ZFS: cleanup"
  agents.each do |agent|
    clean agent
  end
end


agents.each do |agent|
  step "ZFS: setup"
  setup agent
  step "ZFS: basic - ensure it is created"
  apply_manifest_on(agent, 'zfs {"tstpool/tstfs": ensure=>present}') do
    assert_match( /ensure: created/, result.stdout, "err: #{agent}")
  end
  step "query one."
  on(agent, 'puppet resource zfs tstpool/tstfs') do
    assert_match( /ensure *=> *'present'/, result.stdout, "err: #{agent}")
  end
  step "query all."
  on(agent, 'puppet resource zfs') do
    assert_match( /tstpool.tstfs/, result.stdout, "err: #{agent}")
  end

end
