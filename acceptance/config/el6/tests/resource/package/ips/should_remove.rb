test_name "Package:IPS basic tests"
confine :to, :platform => 'solaris'

require 'puppet/acceptance/solaris_util'
extend Puppet::Acceptance::IPSUtils

teardown do
  step "cleanup"
  agents.each do |agent|
    clean agent
  end
end


agents.each do |agent|
  step "IPS: setup"
  setup agent
  setup_fakeroot agent
  send_pkg agent, :pkg => 'mypkg@0.0.1'
  set_publisher agent
  on agent, "pkg install mypkg"
  on agent, "pkg list -v mypkg" do
    assert_match( /mypkg@0.0.1/, result.stdout, "err: #{agent}")
  end

  step "IPS: ensure removed."
  apply_manifest_on(agent, 'package {mypkg : ensure=>absent}') do
    assert_match( /Finished catalog run in .*/, result.stdout, "err: #{agent}")
  end

  on(agent, "pkg list -v mypkg", :acceptable_exit_codes => [1]) do
    assert_no_match( /mypkg@0.0.1/, result.stdout, "err: #{agent}")
  end

end
