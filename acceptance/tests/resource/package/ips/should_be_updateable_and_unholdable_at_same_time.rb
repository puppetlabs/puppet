test_name "Package:IPS test for updatable holded package" do
  confine :to, :platform => 'solaris-11'

  tag 'audit:high'

  require 'puppet/acceptance/solaris_util'
  extend Puppet::Acceptance::IPSUtils

  agents.each do |agent|
    teardown do
      clean agent
    end

    step "IPS: setup" do
      setup agent
      setup_fakeroot agent
      send_pkg agent, :pkg => 'mypkg@0.0.1'
      set_publisher agent
    end

    step "IPS: it should create and hold in same manifest" do
      apply_manifest_on(agent, 'package {mypkg : ensure=>"0.0.1", mark=>hold}') do |result|
        assert_match( /ensure: created/, result.stdout, "err: #{agent}")
      end
    end

    step "IPS: it should update and unhold in same manifest" do
      send_pkg agent, :pkg => 'mypkg@0.0.2'
      apply_manifest_on(agent, 'package {mypkg : ensure=>"0.0.2", mark=>"none"}')
    end

    step "IPS: ensure it was upgraded" do
      on agent, "pkg list -v mypkg" do |result|
        assert_match( /mypkg@0.0.2/, result.stdout, "err: #{agent}")
      end
    end
  end
end
