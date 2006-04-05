if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../.."
end

require 'puppettest'
require 'puppet'
require 'test/unit'
require 'facter'

$platform = Facter["operatingsystem"].value

unless Puppet.type(:package).default
    puts "No default package type for %s; skipping package tests" % $platform
else

class TestPackageSource < Test::Unit::TestCase
	include TestPuppet
    def test_filesource
        path = tempfile()
        system("touch %s" % path)
        assert_equal(
            path,
            Puppet::PackageSource.get("file://#{path}")
        )
    end
end

class TestPackages < Test::Unit::TestCase
	include FileTesting
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
        when "OpenBSD": pkgs = %{vim}
        when "FreeBSD": pkgs = %{sudo}
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

    def mkpkgs
        tstpkgs().each { |pkg, source|
            hash = {:name => pkg, :ensure => "latest"}
            if source
                source = source[0] if source.is_a? Array
                hash[:source] = source
            end
            obj = Puppet.type(:package).create(hash)
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
        installedpkgs().each { |pkg|
            obj = nil
            assert_nothing_raised {
                obj = Puppet.type(:package).create(
                    :name => pkg
                )
            }

            assert(obj, "could not create package")

            assert_nothing_raised {
                obj.retrieve
            }

            # Version is a parameter, not a state.
            assert(obj[:version], "Could not retrieve package version")
        }
    end

    def test_nosuchpkg
        obj = nil
        assert_nothing_raised {
            obj = Puppet.type(:package).create(
                :name => "thispackagedoesnotexist"
            )
        }

        assert_nothing_raised {
            obj.retrieve
        }

        assert_equal(:absent, obj.is(:ensure),
            "Somehow retrieved unknown pkg's version")
    end

    def test_specifypkgtype
        assert_nothing_raised {
            pkg = Puppet.type(:package).create(
                :name => "mypkg",
                :type => "yum"
            )
        }
    end

    def test_latestpkg
        mkpkgs { |pkg|
            next unless pkg.respond_to? :latest
            assert_nothing_raised {
                assert(pkg.latest, "Package did not return value for 'latest'")
            }
        }
    end

    unless Process.uid == 0
        $stderr.puts "Run as root to perform package installation tests"
    else
    def test_installpkg
        mkpkgs { |pkg|
            # we first set install to 'true', and make sure something gets
            # installed
            assert_nothing_raised {
                pkg.retrieve
            }

            if pkg.insync?
                Puppet.notice "Test package %s is already installed; please choose a different package for testing" % pkg
                next
            end

            comp = newcomp("package", pkg)

            assert_events([:package_created], comp, "package")

            # then uninstall it
            assert_nothing_raised {
                pkg[:ensure] = "absent"
            }

            pkg.retrieve

            assert(! pkg.insync?, "Package is in sync")

            assert_events([:package_removed], comp, "package")

            # and now set install to 'latest' and verify it installs
            # FIXME this isn't really a very good test -- we should install
            # a low version, and then upgrade using this.  But, eh.
            if pkg.respond_to?(:latest)
                assert_nothing_raised {
                    pkg[:ensure] = "latest"
                }

                assert_events([:package_created], comp, "package")

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

            modpkg(pkg)

            assert(pkg.latest, "Could not retrieve latest value")

            assert_events([:package_created], pkg)

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
    if Facter["operatingsystem"].value == "Darwin"
        def test_darwinpkgs
            pkg = nil
            assert_nothing_raised {
                pkg = Puppet::Type.type(:package).create(
                    :name => "pkgtesting",
                    :source => "/Users/luke/Documents/Puppet/pkgtesting.pkg",
                    :ensure => :present
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

            assert_events([:package_created], pkg, "package")

            assert_nothing_raised {
                pkg.retrieve
            }

            assert(pkg.insync?, "Package is not insync")

            assert(FileTest.exists?("/tmp/pkgtesting/file"), "File did not get created")
        end
    end
    end
end
end

# $Id$
