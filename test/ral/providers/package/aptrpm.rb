#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../../lib/puppettest')

require 'mocha'

class AptrpmPackageProviderTest < PuppetTest::TestCase
  confine "Apt package provider missing" =>
    Puppet::Type.type(:package).provider(:aptrpm).suitable?

  def setup
    super
    @type = Puppet::Type.type(:package)
  end

  def test_install
    pkg = @type.new :name => 'faff',
      :provider => :aptrpm,
      :ensure => :present,
      :source => "/tmp/faff.rpm"

    pkg.provider.expects(
      :rpm

        ).with(

          '-q',
          'faff',
          '--nosignature',
          '--nodigest',
          '--qf',

          "%{NAME}-%{VERSION}-%{RELEASE} %{VERSION}-%{RELEASE}\n"
            ).raises(Puppet::ExecutionFailure, "couldn't find rpm").times(1)

    pkg.provider.expects(
      :aptget

        ).with(

          '-q',
          '-y',
          "install",

          'faff'
          ).returns(0)

    pkg.evaluate.each { |state| state.forward }
  end

  def test_uninstall
    pkg = @type.new :name => 'faff', :provider => :aptrpm, :ensure => :absent

    pkg.provider.expects(
      :rpm

        ).with(

          '-q',
          'faff',
          '--nosignature',
          '--nodigest',
          '--qf',

          "%{NAME}-%{VERSION}-%{RELEASE} %{VERSION}-%{RELEASE}\n"
          ).returns(
            "faff-1.2.3-1 1.2.3-1\n"
          ).times(1)
    pkg.provider.expects(
      :aptget

        ).with(

          '-y',
          '-q',
          'remove',

          'faff'
          ).returns(0)

    pkg.evaluate.each { |state| state.forward }
  end

  # LAK: I don't know where this test will ever return true..
  def disabled_test_latest
    pkg = @type.new :name => 'ssh', :provider => :aptrpm

    assert(pkg, "did not create pkg")
    status = pkg.provider.query
    assert(status, "ssh is not installed")
    assert(status[:ensure] != :absent, "ssh is not installed")

    latest = nil
    assert_nothing_raised("Could not call latest") do
      latest = pkg.provider.latest
    end
    assert(latest, "Could not get latest value from apt")
  end
end

