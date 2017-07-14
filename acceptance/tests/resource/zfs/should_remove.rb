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

  step "ZFS: create"
  on agent, 'zfs create tstpool/tstfs'
  step "ZFS: ensure can be removed."
  apply_manifest_on(agent, 'zfs { "tstpool/tstfs": ensure=>absent}') do
    assert_match( /ensure: removed/, result.stdout, "err: #{agent}")
  end
end
