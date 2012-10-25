test_name "SMF: should query instances"
confine :to, :platform => 'solaris'

require 'puppet/acceptance/solaris_util'
extend Puppet::Acceptance::SMFUtils

teardown do
  step "SMF: cleanup"
  agents.each do |agent|
    clean agent, :service => 'tstapp'
  end
end


agents.each do |agent|
  manifest, method = setup agent, :service => 'tstapp'
  step "SMF: ensre it is created with a manifest"
  apply_manifest_on(agent, 'service {tstapp : ensure=>running, manifest=>"%s"}' % manifest) do
    assert_match( / ensure changed 'stopped' to 'running'/, result.stdout, "err: #{agent}")
  end
  step "SMF: query the resource"
  on agent, "puppet resource service tstapp" do
    assert_match( /ensure => 'running'/, result.stdout, "err: #{agent}")
  end
  step "SMF: query all the instances"
  on agent, "puppet resource service" do
    assert_match( /tstapp/, result.stdout, "err: #{agent}")
  end
end
