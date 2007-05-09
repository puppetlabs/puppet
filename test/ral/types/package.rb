#!/usr/bin/env ruby

$:.unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'facter'

$platform = Facter["operatingsystem"].value

class TestPackages < Test::Unit::TestCase
    include PuppetTest::FileTesting
    def setup
        super
        #@list = Puppet.type(:package).getpkglist
        Puppet.type(:package).clear
        @type = Puppet::Type.type(:package)
    end

    # This is a bare-minimum test and *really* needs to do much more.
    def test_package_actions
        @type.provide :fake, :parent => PuppetTest::FakeProvider do
            apimethods :ensure
            def install
                self.ensure = @model.should(:ensure)
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

        unless default = Puppet.type(:package).defaultprovider
            $stderr.puts "no default provider for %s" %
                Facter["operatingsystem"].value
            return
        end


        if should
            assert_equal(should, default.name,
                "Incorrect default package format")
        end
    end
end

# $Id$
