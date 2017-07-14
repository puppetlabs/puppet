test_name "SMF: basic tests"
confine :to, :platform => 'solaris'

tag 'audit:medium',
    'audit:refactor',  # Use block style `test_run`
    'audit:acceptance' # Could be done at the integration (or unit) layer though
                       # actual changing of resources could irreparably damage a
                       # host running this, or require special permissions.

require 'puppet/acceptance/solaris_util'
extend Puppet::Acceptance::SMFUtils

teardown do
  step "SMF: cleanup"
  agents.each do |agent|
    clean agent, :service => 'tstapp'
  end
end

agents.each do |agent|
  clean agent, :service => 'tstapp'
  manifest, method = setup agent, :service => 'tstapp'

  step "SMF: ensure it is created with a manifest"
  apply_manifest_on(agent, 'service {tstapp : ensure=>running, manifest=>"%s"}' % manifest) do
    assert_match( /defined 'ensure' as 'running'/, result.stdout, "err: #{agent}")
  end

  step "SMF: verify with svcs that the service is online"
  on agent, "svcs -l application/tstapp" do
    assert_match( /state\s+online/, result.stdout, "err: #{agent}")
  end

  step "SMF: ensure it is idempotent - ie not created again"
  apply_manifest_on(agent, 'service {tstapp : ensure=>running, manifest=>"%s"}' % manifest, :catch_changes => true)

  step "SMF: ensure you can query the service with the ral"
  on(agent, puppet("resource service tstapp")) do
    assert_match( /ensure => 'running'/, result.stdout, "err: #{agent}")
  end

  step "SMF: ensure you can stop the service"
  apply_manifest_on(agent, 'service {tstapp : ensure=>stopped}') do
    assert_match( /changed 'running'.* to 'stopped'/, result.stdout, "err: #{agent}")
  end

  step "SMF: verify with svcs that the service is not online"
  on agent, "svcs -l application/tstapp", :acceptable_exit_codes => [0,1] do
    assert_no_match( /state\s+online/, result.stdout, "err: #{agent}")
  end
end
