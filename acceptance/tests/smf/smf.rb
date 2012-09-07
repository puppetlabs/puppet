test_name "SMF: configuration"
confine :to, :platform => 'solaris'

require 'puppet/acceptance/solaris_util'
extend Puppet::Acceptance::SMFUtils

teardown do
  agents.each do |agent|
    clean agent, :service => 'tstapp'
  end
end


agents.each do |agent|
  clean agent, :service => 'tstapp'
  manifest, method = setup agent, :service => 'tstapp'
  #-----------------------------------
  apply_manifest_on(agent, 'service {tstapp : ensure=>stopped}') do
    assert_match( /.*/, result.stdout, "err: #{agent}")
  end

  apply_manifest_on(agent, 'service {tstapp : ensure=>running, manifest=>"%s"}' % manifest) do
    assert_match( / ensure changed 'stopped' to 'running'/, result.stdout, "err: #{agent}")
  end
  on agent, "puppet resource service tstapp" do
    assert_match( /ensure => 'running'/, result.stdout, "err: #{agent}")
  end

  on agent, "svcs -l application/tstapp" do
    assert_match( /state\s+online/, result.stdout, "err: #{agent}")
  end
  apply_manifest_on(agent, 'service {tstapp : ensure=>stopped}') do
    assert_match( /.*/, result.stdout, "err: #{agent}")
  end
end
