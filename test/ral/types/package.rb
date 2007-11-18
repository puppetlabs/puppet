#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../lib/puppettest'

require 'puppettest'
require 'facter'
require 'mocha'

$platform = Facter["operatingsystem"].value

class TestPackages < Test::Unit::TestCase
    include PuppetTest
    include PuppetTest::FileTesting
    def setup
        super
        Puppet.type(:package).clear
        @type = Puppet::Type.type(:package)
    end

    # This is a bare-minimum test and *really* needs to do much more.
    def test_package_actions
        @type.provide :fake, :parent => PuppetTest::FakeProvider do
            apimethods :ensure
            def install
                self.ensure = @resource.should(:ensure)
            end

            def uninstall
                self.ensure = :absent
            end

            def query
                case self.ensure
                when :absent, nil: nil
                else
                    {:ensure => self.ensure}
                end
            end
        end

        pkg = nil
        assert_nothing_raised do
            pkg = @type.create :name => "testing", :provider => :fake
        end
        assert(pkg, "did not create package")

        current_values = nil
        assert_nothing_raised do
            current_values = pkg.retrieve
        end

        assert_equal(:absent, current_values[pkg.property(:ensure)], 
                     "package not considered missing")
        assert_equal(:present, pkg.should(:ensure),
            "package did not default to installed")

        assert_events([:package_installed], pkg)

        pkg[:ensure] = :absent
        assert_events([:package_removed], pkg)
    end

    def test_packagedefaults
        should = case Facter["operatingsystem"].value
        when "Debian": :apt
        when "Darwin": :apple
        when "RedHat": :up2date
        when "Fedora": :yum
        when "FreeBSD": :ports
        when "OpenBSD": :openbsd
        when "Solaris": :sun
        end

        unless default = Puppet::Type.type(:package).defaultprovider
            $stderr.puts "no default provider for %s" %
                Facter["operatingsystem"].value
            return
        end


        if should
            assert_equal(should, default.name,
                "Incorrect default package format")
        end
    end

    # Make sure we can prefetch and retrieve packages
    def test_package_instances
        providers = []
        instances = nil
        assert_nothing_raised("Could not get package instances") do
            instances = @type.instances
        end
        instances.each do |resource|
            # Just do one of each type
            next if providers.include?(resource.provider.class)
            providers << resource.provider.class

            # We should have data on the resource
            assert(resource.exists?, "Listed resource thinks it's absent")

            # Now flush the resource and make sure it clears the property_hash
            assert_nothing_raised("Could not flush package") do
                resource.flush
            end

            assert_equal(:absent, resource.provider.get(:ensure), "Flushing did not empty property hash")

            # And query anew
            props = nil
            assert_nothing_raised("Could not retrieve package again") do
                props = resource.retrieve
            end
            provider_props = resource.provider.send(:instance_variable_get, "@property_hash")
            props.each do |prop, value|
                assert_equal(value, provider_props[prop.name], "Query did not return same result as the property_hash for %s" % prop.name)
            end
        end
    end

    # Make sure we can prefetch package information, rather than getting it one package at a time.
    def test_prefetch
        @type.providers_by_source.each do |provider|
            # The yum provider can't be used if you're not root
            next if provider.name == :yum && Process.euid != 0

            # First get a list of packages
            list = provider.instances

            packages = {}
            list.each do |package|
                packages[package.name] = @type.create(:name => package.name, :ensure => :installed)
                break if packages.length > 4
            end

            # Now prefetch using that list of packages
            assert_nothing_raised("Could not prefetch with %s" % provider.name) do
                provider.prefetch(packages)
            end

            # And make sure each package is marked as existing, without calling query
            packages.each do |name, package|
                assert(package.exists?, "Package of type %s not marked present" % provider.name)
                package.provider.expects(:query).never
            end
        end
    end

    # #716
    def test_purge_is_not_installed
        package = @type.create(:ensure => :installed, :name => "whatever")

        property = package.property(:ensure)
        assert(! property.insync?(:purged), "Package in state 'purged' was considered in sync")
    end
end

