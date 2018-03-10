test_name "test the yum package provider" do

  confine :to, {:platform => /(?:centos|el-|fedora)/}, agents
  confine :except, :platform => /centos-4|el-4/ # PUP-5227
  # Skipping tests if facter finds this is an ec2 host, PUP-7774
  agents.each do |agent|
    skip_test('Skipping EC2 Hosts') if fact_on(agent, 'ec2_metadata')
  end

  tag 'audit:medium',
      'audit:acceptance' # Could be done at the integration (or unit) layer though
                         # actual changing of resources could irreparably damage a
                         # host running this, or require special permissions.

  require 'puppet/acceptance/rpm_util'
  extend Puppet::Acceptance::RpmUtils

  epoch_rpm_options    = {:pkg => 'epoch', :version => '1.1', :epoch => '1'}
  no_epoch_rpm_options = {:pkg => 'guid', :version => '1.0'}

  teardown do
    step "cleanup"
    agents.each do |agent|
      clean_rpm agent, epoch_rpm_options
      clean_rpm agent, no_epoch_rpm_options
    end
  end

  def verify_state(hosts, pkg, state, match)
    hosts.each do |agent|
      cmd = rpm_provider(agent)
      # Note yum and dnf list packages as <name>.<arch>
      on agent, "#{cmd} list installed" do
        method(match).call(/^#{pkg}\./, stdout)
      end
    end
  end

  def verify_present(hosts, pkg)
    verify_state(hosts, pkg, '(?!purged|absent)[^\']+', :assert_match)
  end

  def verify_absent(hosts, pkg)
    verify_state(hosts, pkg, '(?:purged|absent)', :assert_no_match)
  end

  step "Managing a package which does not include an epoch in its version" do
    step 'Setup repo and package'
    agents.each do |agent|
      clean_rpm agent, no_epoch_rpm_options
      setup_rpm agent, no_epoch_rpm_options
      send_rpm agent, no_epoch_rpm_options
    end

    step 'Installing a known package succeeds' do
      verify_absent agents, 'guid'
      apply_manifest_on(agents, 'package {"guid": ensure => installed}') do |result|
        assert_match('Package[guid]/ensure: created', "#{result.host}: #{result.stdout}")
      end
    end

    step 'Removing a known package succeeds' do
      verify_present agents, 'guid'
      apply_manifest_on(agents, 'package {"guid": ensure => absent}') do |result|
        assert_match('Package[guid]/ensure: removed', "#{result.host}: #{result.stdout}")
      end
    end

    step 'Installing a specific version of a known package succeeds' do
      verify_absent agents, 'guid'
      apply_manifest_on(agents, 'package {"guid": ensure => "1.0"}') do |result|
        assert_match('Package[guid]/ensure: created', "#{result.host}: #{result.stdout}")
      end
    end

    step 'Removing a specific version of a known package succeeds' do
      verify_present agents, 'guid'
      apply_manifest_on(agents, 'package {"guid": ensure => absent}') do |result|
        assert_match('Package[guid]/ensure: removed', "#{result.host}: #{result.stdout}")
      end
    end

    step 'Installing a non-existent version of a known package fails' do
      verify_absent agents, 'guid'
      apply_manifest_on(agents, 'package {"guid": ensure => "1.1"}') do |result|
        assert_not_match(/Package\[guid\]\/ensure: created/, "#{result.host}: #{result.stdout}")
        assert_match("Package[guid]/ensure: change from 'purged' to '1.1' failed", "#{result.host}: #{result.stderr}")
      end
      verify_absent agents, 'guid'
    end

    step 'Installing a non-existent package fails' do
      verify_absent agents, 'not_a_package'
      apply_manifest_on(agents, 'package {"not_a_package": ensure => present}') do |result|
        assert_not_match(/Package\[not_a_package\]\/ensure: created/, "#{result.host}: #{result.stdout}")
        assert_match("Package[not_a_package]/ensure: change from 'purged' to 'present' failed", "#{result.host}: #{result.stderr}")
      end
      verify_absent agents, 'not_a_package'
    end

    step 'Removing a non-existent package succeeds' do
      verify_absent agents, 'not_a_package'
      apply_manifest_on(agents, 'package {"not_a_package": ensure => absent}') do |result|
        assert_not_match(/Package\[not_a_package\]\/ensure/, "#{result.host}: #{result.stdout}")
        assert_match('Applied catalog', "#{result.host}: #{result.stdout}")
      end
      verify_absent agents, 'not_a_package'
    end

    step 'Installing a known package using source succeeds' do
      verify_absent agents, 'guid'
      apply_manifest_on(agent, "package { 'guid': ensure => installed, install_options => '--nogpgcheck', source=>'/tmp/rpmrepo/RPMS/noarch/guid-1.0-1.noarch.rpm' }") do |result|
        assert_match('Package[guid]/ensure: created', "#{result.host}: #{result.stdout}")
      end
    end
  end

  ### Epoch tests ###
  agents.each do |agent|
    step "Managing a package which includes an epoch in its version" do
      step "Setup repo and package" do
        clean_rpm agent, no_epoch_rpm_options
        setup_rpm agent, epoch_rpm_options
        send_rpm agent, epoch_rpm_options
      end

      step 'Installing a known package with an epoch succeeds' do
        verify_absent [agent], 'epoch'
        apply_manifest_on(agent, 'package {"epoch": ensure => installed}') do |result|
          assert_match('Package[epoch]/ensure: created', "#{result.host}: #{result.stdout}")
        end
      end

      step 'Removing a known package with an epoch succeeds' do
        verify_present [agent], 'epoch'
        apply_manifest_on(agent, 'package {"epoch": ensure => absent}') do |result|
          assert_match('Package[epoch]/ensure: removed', "#{result.host}: #{result.stdout}")
        end
      end

      step "Installing a specific version of a known package with an epoch succeeds when epoch and arch are specified" do
        verify_absent [agent], 'epoch'
        apply_manifest_on(agent, "package {'epoch': ensure => '1:1.1-1.noarch'}") do |result|
          assert_match('Package[epoch]/ensure: created', "#{result.host}: #{result.stdout}")
        end

        apply_manifest_on(agent, "package {'epoch': ensure => '1:1.1-1.noarch'}") do |result|
          assert_no_match(/epoch/, result.stdout)
        end
      end

      if rpm_provider(agent) == 'dnf'
        # Yum requires the arch to be specified whenever epoch is specified. This step is only
        # expected to work in DNF.
        step "Installing a specific version of a known package with an epoch succeeds when epoch is specified and arch is not" do
          step "Remove the package" do
            apply_manifest_on(agent, 'package {"epoch": ensure => absent}')
            verify_absent [agent], 'epoch'
          end

          apply_manifest_on(agent, 'package {"epoch": ensure => "1:1.1-1"}') do |result|
            assert_match('Package[epoch]/ensure: created', "#{result.host}: #{result.stdout}")
          end

          apply_manifest_on(agent, 'package {"epoch": ensure => "1:1.1-1"}') do |result|
            assert_no_match(/epoch/, result.stdout)
          end

          apply_manifest_on(agent, "package {'epoch': ensure => '1:1.1-1.noarch'}") do |result|
            assert_no_match(/epoch/, result.stdout)
          end
        end
      end

      if rpm_provider(agent) == 'yum'
        step "Installing a specified version of a known package with an epoch succeeds without epoch or arch provided" do
          # Due to a bug in DNF, epoch is required. This step is only expected to work in Yum.
          # See https://bugzilla.redhat.com/show_bug.cgi?id=1286877
          step "Remove the package" do
            apply_manifest_on(agent, 'package {"epoch": ensure => absent}')
            verify_absent [agent], 'epoch'
          end

          apply_manifest_on(agent, 'package {"epoch": ensure => "1.1-1"}') do |result|
            assert_match('Package[epoch]/ensure: created', "#{result.host}: #{result.stdout}")
          end

          apply_manifest_on(agent, 'package {"epoch": ensure => "1.1-1"}') do |result|
            assert_no_match(/epoch/, result.stdout)
          end

          apply_manifest_on(agent, "package {'epoch': ensure => '1:1.1-1.noarch'}") do |result|
            assert_no_match(/epoch/, result.stdout)
          end
        end
      end
    end
  end
end
