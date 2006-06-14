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
                hash[:ensure] = "latest"
            end
            if source
                source = source[0] if source.is_a? Array
                hash[:source] = source
            end
            if Facter["operatingsystem"].value == "Darwin"
                hash[:type] = "darwinport"
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

            # Version is a parameter, not a state.
            assert(obj[:version], "Could not retrieve package version")
        }
    end

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
        assert_raise(Puppet::PackageError,
            "Successfully installed nonexistent package") {
            state.sync
        }
    end

    def test_specifypkgtype
        pkg = nil
        assert_nothing_raised {
            pkg = Puppet.type(:package).create(
                :name => "mypkg",
                :type => "yum"
            )
        }
        assert(pkg, "Did not create package")
        assert_equal(:yum, pkg[:type])
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

        # Heh
        defaulttype = pkgtype.pkgtype(pkgtype.default)

        assert_nothing_raised("Could not list packages") do
            defaulttype.list
        end
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

            if pkg.insync? or pkg.is(:ensure) != :absent
                Puppet.notice "Test package %s is already installed; please choose a different package for testing" % pkg
                next
            end

            comp = newcomp("package", pkg)

            assert_events([:package_created], comp, "package")

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
    if Facter["operatingsystem"].value == "Darwin" and
        FileTest.exists? "/Users/luke/Documents/Puppet/pkgtesting.pkg"
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
