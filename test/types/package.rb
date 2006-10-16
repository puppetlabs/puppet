#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'puppet'
require 'facter'

$platform = Facter["operatingsystem"].value

unless Puppet.type(:package).defaultprovider
    puts "No default package type for %s; skipping package tests" % $platform
else

class TestPackages < Test::Unit::TestCase
    include PuppetTest::FileTesting
    def setup
        super
        #@list = Puppet.type(:package).getpkglist
        Puppet.type(:package).clear
    end

    # These are packages that we're sure will be installed
    def installedpkgs
        pkgs = nil
        case $platform
        when "SunOS"
            pkgs = %w{SMCossh}
        when "Debian": pkgs = %w{ssh openssl}
        when "Fedora": pkgs = %w{openssh}
        when "OpenBSD": pkgs = %w{vim}
        when "FreeBSD": pkgs = %w{sudo}
        when "Darwin": pkgs = %w{gettext}
        else
            Puppet.notice "No test package for %s" % $platform
            return []
        end

        return pkgs
    end

    def modpkg(pkg)
        case $platform
        when "Solaris":
            pkg[:adminfile] = "/usr/local/pkg/admin_file"
        end
    end

    def mkpkgs(list = nil, useensure = true)
        list ||= tstpkgs()
        list.each { |pkg, source|
            hash = {:name => pkg}
            if useensure
                hash[:ensure] = "installed"
            end
            if source
                source = source[0] if source.is_a? Array
                hash[:source] = source
            end
            # Override the default package type for our test packages.
            if Facter["operatingsystem"].value == "Darwin"
                hash[:provider] = "darwinport"
            end
            obj = Puppet.type(:package).create(hash)
            assert(pkg, "Could not create package")
            modpkg(obj)

            yield obj
        }
    end

    def tstpkgs
        retval = []
        case $platform
        when "Solaris":
            arch = Facter["hardwareisa"].value + Facter["operatingsystemrelease"].value
            case arch
            when "i3865.10":
                retval = {"SMCrdesk" => [
                    "/usr/local/pkg/rdesktop-1.3.1-sol10-intel-local",
                    "/usr/local/pkg/rdesktop-1.4.1-sol10-x86-local"
                ]}
            when "sparc5.8":
                retval = {"SMCarc" => "/usr/local/pkg/arc-5.21e-sol8-sparc-local"}
            when "i3865.8":
                retval = {"SMCarc" => "/usr/local/pkg/arc-5.21e-sol8-intel-local"}
            end
        when "OpenBSD":
            retval = {"aalib" => "ftp://ftp.usa.openbsd.org/pub/OpenBSD/3.8/packages/i386/aalib-1.2-no_x11.tgz"}
        when "Debian":
            retval = {"zec" => nil}
        #when "RedHat": type = :rpm
        when "Fedora":
            retval = {"wv" => nil}
        when "CentOS":
            retval = {"enhost" => [
                "/home/luke/rpm/RPMS/noarch/enhost-1.0.1-1.noarch.rpm",
                "/home/luke/rpm/RPMS/noarch/enhost-1.0.2-1.noarch.rpm"
            ]}
        when "Darwin":
            retval = {"aop" => nil}
        when "FreeBSD":
            retval = {"yahtzee" => nil}
        when "RedHat":
            retval = {"puppet" => "/home/luke/rpm/RPMS/i386/puppet-0.16.1-1.i386.rpm"}
        else
            Puppet.notice "No test packages for %s" % $platform
        end

        return retval
    end

    def mkpkgcomp(pkg)
        assert_nothing_raised {
            pkg = Puppet.type(:package).create(:name => pkg, :ensure => "present")
        }
        assert_nothing_raised {
            pkg.retrieve
        }

        comp = newcomp("package", pkg)

        return comp
    end

    def test_retrievepkg
        mkpkgs(installedpkgs()) { |obj|

            assert(obj, "could not create package")

            assert_nothing_raised {
                obj.retrieve
            }

            assert_instance_of(String, obj[:ensure],
                "Ensure did not return a version number")
            assert(obj[:ensure] =~ /[0-9.]/,
                "Ensure did not return a version number")
        }
    end

    def test_latestpkg
        mkpkgs { |pkg|
            next unless pkg.respond_to? :latest
            assert_nothing_raised {
                assert(pkg.latest,
                    "Package %s did not return value for 'latest'" % pkg.name)
            }
        }
    end

    # Make sure our package type supports listing.
    def test_listing
        pkgtype = Puppet::Type.type(:package)

        assert_nothing_raised("Could not list packages") do
            count = 0
            pkgtype.list.each do |pkg|
                assert_instance_of(Puppet::Type.type(:package), pkg)
                count += 1
            end

            assert(count > 1, "Did not get any packages")
        end
    end

    unless Puppet::SUIDManager.uid == 0
        $stderr.puts "Run as root to perform package installation tests"
    else
    def test_nosuchpkg
        obj = nil
        assert_nothing_raised {
            obj = Puppet.type(:package).create(
                :name => "thispackagedoesnotexist",
                :ensure => :installed
            )
        }

        assert(obj, "Failed to create fake package")

        assert_nothing_raised {
            obj.retrieve
        }

        assert_equal(:absent, obj.is(:ensure),
            "Somehow retrieved unknown pkg's version")

        state = obj.state(:ensure)
        assert(state, "Could not retrieve ensure state")

        # Add a fake state, for those that need it
        file = tempfile()
        File.open(file, "w") { |f| f.puts :yayness }
        obj[:source] = file
        assert_raise(Puppet::Error, Puppet::ExecutionFailure,
            "Successfully installed nonexistent package") {
            state.sync
        }
    end

    def test_installpkg
        mkpkgs { |pkg|
            # we first set install to 'true', and make sure something gets
            # installed
            assert_nothing_raised {
                pkg.retrieve
            }

            if hash = pkg.provider.query and hash[:ensure] != :absent
                Puppet.notice "Test package %s is already installed; please choose a different package for testing" % pkg
                next
            end

            comp = newcomp("package", pkg)

            assert_events([:package_installed], comp, "package")

            pkg.retrieve

            assert(pkg.insync?, "Package is not in sync")

            # then uninstall it
            assert_nothing_raised {
                pkg[:ensure] = "absent"
            }

            pkg.retrieve

            assert(! pkg.insync?, "Package is in sync")

            assert_events([:package_removed], comp, "package")

            # and now set install to 'latest' and verify it installs
            if pkg.respond_to?(:latest)
                assert_nothing_raised {
                    pkg[:ensure] = "latest"
                }

                assert_events([:package_installed], comp, "package")

                pkg.retrieve
                assert(pkg.insync?, "After install, package is not insync")

                assert_nothing_raised {
                    pkg[:ensure] = "absent"
                }

                pkg.retrieve

                assert(! pkg.insync?, "Package is insync")

                assert_events([:package_removed], comp, "package")
            end
        }
    end

    # Make sure that a default is used for 'ensure'
    def test_ensuredefault
        # Tell mkpkgs not to set 'ensure'.
        mkpkgs(nil, false) { |pkg|
            assert_nothing_raised {
                pkg.retrieve
            }

            assert(!pkg.insync?, "Package thinks it's in sync")

            assert_apply(pkg)
            pkg.retrieve
            assert(pkg.insync?, "Package does not think it's in sync")

            pkg[:ensure] = :absent
            assert_apply(pkg)
        }
    end

    def test_upgradepkg
        tstpkgs.each do |name, sources|
            unless sources and sources.is_a? Array
                $stderr.puts "Skipping pkg upgrade test for %s" % name
                next
            end
            first, second = sources

            unless FileTest.exists?(first) and FileTest.exists?(second)
                $stderr.puts "Could not find upgrade test pkgs; skipping"
                return
            end

            pkg = nil
            assert_nothing_raised {
                pkg = Puppet.type(:package).create(
                    :name => name,
                    :ensure => :latest,
                    :source => first
                )
            }

            assert(pkg, "Failed to create package %s" % name)

            modpkg(pkg)

            assert(pkg.provider.latest, "Could not retrieve latest value")

            assert_events([:package_installed], pkg)

            assert_nothing_raised {
                pkg.retrieve
            }
            assert(pkg.insync?, "Package is not in sync")
            pkg.clear
            assert_nothing_raised {
                pkg[:source] = second
            }
            assert_events([:package_changed], pkg)

            assert_nothing_raised {
                pkg.retrieve
            }
            assert(pkg.insync?, "Package is not in sync")
            assert_nothing_raised {
                pkg[:ensure] = :absent
            }
            assert_events([:package_removed], pkg)

            assert_nothing_raised {
                pkg.retrieve
            }
            assert(pkg.insync?, "Package is not in sync")
        end
    end

    # Stupid darwin, not supporting package uninstallation
    if Facter["operatingsystem"].value == "Darwin" and
        FileTest.exists? "/Users/luke/Documents/Puppet/pkgtesting.pkg"
        def test_darwinpkgs
            pkg = nil
            assert_nothing_raised {
                pkg = Puppet::Type.type(:package).create(
                    :name => "pkgtesting",
                    :source => "/Users/luke/Documents/Puppet/pkgtesting.pkg",
                    :ensure => :present,
                    :provider => :apple
                )
            }

            assert_nothing_raised {
                pkg.retrieve
            }

            if pkg.insync?
                Puppet.notice "Test package is already installed; please remove it"
                next
            end

            # The file installed, and the receipt
            @@tmpfiles << "/tmp/file"
            @@tmpfiles << "/Library/Receipts/pkgtesting.pkg"

            assert_events([:package_installed], pkg, "package")

            assert_nothing_raised {
                pkg.retrieve
            }

            assert(pkg.insync?, "Package is not insync")

            assert(FileTest.exists?("/tmp/pkgtesting/file"), "File did not get created")
        end
    end

    # Yay, gems.  They're special because any OS can test them.
    if Puppet::Type.type(:package).provider(:gem).suitable?
    def test_list_gems
        gems = nil
        assert_nothing_raised {
            gems = Puppet::Type.type(:package).provider(:gem).list
        }

        gems.each do |gem|
            assert_equal(:gem, gem[:provider],
                "Type was not set correctly")
        end
    end

    def test_install_gems
        gem = nil
        name = "wxrubylayouts"
        assert_nothing_raised {
            gem = Puppet::Type.newpackage(
                :name => name,
                :ensure => "0.0.2",
                :provider => :gem
            )
        }

        assert_nothing_raised {
            gem.retrieve
        }

        if gem.is(:ensure) != :absent
            $stderr.puts "Cannot test gem installation; %s is already installed" %
                name
            return
        end

        assert_events([:package_installed], gem)

        assert_nothing_raised {
            gem.retrieve
        }

        assert_equal("0.0.2", gem.is(:ensure),
            "Incorrect version was installed")

        latest = nil
        assert_nothing_raised {
            latest = gem.provider.latest
        }

        assert(latest != gem[:ensure], "Did not correctly find latest value")

        gem[:ensure] = :latest
        assert_events([:package_changed], gem)

        gem.retrieve

        assert("0.0.2" != gem.is(:ensure),
            "Package was not updated.")

        gem[:ensure] = :absent

        assert_events([:package_removed], gem)
    end

    else
    $stderr.puts "Install gems for gem tests"
    def test_failure_when_no_gems
        obj = nil
        assert_raise(ArgumentError) do
            Puppet::Type.newpackage(
                :name => "yayness",
                :provider => "gem",
                :ensure => "installed"
            )
        end
    end
    end
    end
    if Puppet.type(:package).provider(:rpm).suitable? and
        FileTest.exists?("/home/luke/rpm/RPMS/i386/puppet-server-0.16.1-1.i386.rpm")

    # We have a special test here, because we don't actually want to install the
    # package, just make sure it's getting the "latest" value.
    def test_rpmlatest
        pkg = nil
        assert_nothing_raised {
            pkg = Puppet::Type.type(:package).create(
                :provider => :rpm,
                :name => "puppet-server",
                :source => "/home/luke/rpm/RPMS/i386/puppet-server-0.16.1-1.i386.rpm"
            )
        }

        assert_equal("0.16.1-1", pkg.provider.latest, "RPM did not provide correct value for latest")
    end
    end

    def test_packagedefaults
        should = case Facter["operatingsystem"].value
        when "Debian": :apt
        when "Darwin": :apple
        when "RedHat": :rpm
        when "Fedora": :yum
        when "FreeBSD": :ports
        when "OpenBSD": :openbsd
        when "Solaris": :sun
        end

        default = Puppet.type(:package).defaultprovider
        assert(default, "No default package provider for %s" %
            Facter["operatingsystem"].value)


        if should
            assert_equal(should, default.name,
                "Incorrect default package format")
        end
    end
end
end

# $Id$
